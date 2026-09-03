import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Unified KSP balance: Effective KSP = (Wallet USD × 1000) + Reward KSP.
///
/// Reward KSP is stored in [user_points.current_balance].
/// Wallet-backed KSP is derived from [wallets.available_balance] (USD).
class KspBalanceService extends GetxService {
  static KspBalanceService get to => Get.find<KspBalanceService>();

  static const double kspPerUsd = 1000;

  static const String _redeemKeyPref = 'kasby_fin_idem_ksp_redeem';
  static const String _redeemKeyAmountPref = 'kasby_fin_idem_ksp_redeem_amount';
  static const _uuid = Uuid();

  final RxInt effectiveKsp = 0.obs;
  final RxInt rewardKsp = 0.obs;
  final RxInt walletKsp = 0.obs;
  final RxDouble walletUsd = 0.0.obs;
  final RxBool isLoading = false.obs;

  /// Coalesces parallel refresh() calls into a single RPC.
  Future<int>? _inFlightRefresh;

  /// Backward-compatible alias used across the app.
  int get balance => effectiveKsp.value;

  Future<int> refresh() async {
    if (_inFlightRefresh != null) {
      return _inFlightRefresh!;
    }

    final future = _refreshNow();
    _inFlightRefresh = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightRefresh, future)) {
        _inFlightRefresh = null;
      }
    }
  }

  Future<int> _refreshNow() async {
    if (!SupabaseService.isLoggedIn) {
      _reset();
      return 0;
    }

    isLoading.value = true;
    try {
      final raw = await SupabaseService.client.rpc('fn_get_effective_ksp');
      final payload = raw is Map ? Map<String, dynamic>.from(raw) : null;

      if (payload?['success'] == true) {
        walletUsd.value = (payload!['wallet_usd'] as num?)?.toDouble() ?? 0;
        walletKsp.value = (payload['wallet_ksp'] as num?)?.toInt() ?? 0;
        rewardKsp.value = (payload['reward_ksp'] as num?)?.toInt() ?? 0;
        effectiveKsp.value = (payload['effective_ksp'] as num?)?.toInt() ?? 0;
      } else {
        await _refreshFallback();
      }

      SafeGetx.debugTrace(
        className: 'KspBalanceService',
        method: 'refresh',
        feature: 'Wallet',
        status: 'SUCCESS',
        params: {
          'effectiveKsp': effectiveKsp.value,
          'rewardKsp': rewardKsp.value,
          'walletKsp': walletKsp.value,
          'walletUsd': walletUsd.value,
        },
      );

      return effectiveKsp.value;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'KspBalanceService',
        method: 'refresh',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      await _refreshFallback();
      return effectiveKsp.value;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _refreshFallback() async {
    final usd = CurrencyController.to.totalBalance.value;
    walletUsd.value = usd;
    walletKsp.value = (usd * kspPerUsd).floor();
    effectiveKsp.value = walletKsp.value + rewardKsp.value;
  }

  void applyFromRpc(Map<String, dynamic>? payload) {
    if (payload == null) return;
    if (payload.containsKey('effective_ksp')) {
      effectiveKsp.value =
          (payload['effective_ksp'] as num?)?.toInt() ?? effectiveKsp.value;
    }
    if (payload.containsKey('reward_ksp')) {
      rewardKsp.value =
          (payload['reward_ksp'] as num?)?.toInt() ?? rewardKsp.value;
    }
    if (payload.containsKey('wallet_ksp')) {
      walletKsp.value =
          (payload['wallet_ksp'] as num?)?.toInt() ?? walletKsp.value;
    }
    if (payload.containsKey('wallet_usd')) {
      walletUsd.value =
          (payload['wallet_usd'] as num?)?.toDouble() ?? walletUsd.value;
    }
    if (payload.containsKey('new_balance') &&
        !payload.containsKey('effective_ksp')) {
      effectiveKsp.value =
          (payload['new_balance'] as num?)?.toInt() ?? effectiveKsp.value;
    }
  }

  Future<Map<String, dynamic>> buySpinsBundle(String bundleType) async {
    await refresh();
    final raw = await SupabaseService.client.rpc(
      'buy_spins_bundle',
      params: {'p_bundle_type': bundleType},
    );
    final response = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'success': false, 'error': 'Invalid response'};

    if (response['success'] == true) {
      applyFromRpc(response);
      await refresh();
      await CurrencyController.to.fetchWalletBalances();
    }
    return response;
  }

  /// Redeems [kspAmount] reward points into liquid USD wallet cash.
  /// Enforces minimum 1,000 KSP and multiples of 1,000.
  Future<Map<String, dynamic>> redeemKspToCash(
    int kspAmount, {
    String? idempotencyKey,
  }) async {
    SafeGetx.debugTrace(
      className: 'KspBalanceService',
      method: 'redeemKspToCash',
      feature: 'Wallet',
      status: 'INFO',
      params: {
        'kspAmount': kspAmount,
        'idempotencyKey': idempotencyKey,
        'rewardKsp': rewardKsp.value,
        'walletUsd': walletUsd.value,
      },
    );

    if (kspAmount < 1000 || kspAmount % 1000 != 0) {
      SafeGetx.debugTrace(
        className: 'KspBalanceService',
        method: 'redeemKspToCash',
        feature: 'Wallet',
        status: 'ERROR',
        params: {'reason': 'INVALID_KSP_AMOUNT_MUST_BE_MULTIPLE_OF_1000', 'kspAmount': kspAmount},
      );
      return {
        'success': false,
        'error': 'INVALID_KSP_AMOUNT_MUST_BE_MULTIPLE_OF_1000',
      };
    }

    // Resolve the idempotency key for this logical redemption operation.
    // A persisted (key, amount) pair that matches the requested amount is
    // reused across retries/timeouts/restarts so the DB can deduplicate.
    // A different requested amount (or no persisted operation) is a NEW
    // operation and must receive a NEW key. Cleared only on confirmed success.
    final key = await _resolveRedemptionKey(idempotencyKey, kspAmount);

    try {
      SafeGetx.debugTrace(
        className: 'KspBalanceService',
        method: 'redeemKspToCash',
        feature: 'Wallet',
        status: 'INFO',
        message: 'Calling RPC fn_redeem_ksp_to_wallet',
        params: {'p_ksp_amount': kspAmount, 'p_idempotency_key': key},
      );

      final raw = await SupabaseService.client.rpc(
        'fn_redeem_ksp_to_wallet',
        params: {
          'p_ksp_amount': kspAmount,
          'p_idempotency_key': key,
        },
      );

      SafeGetx.debugTrace(
        className: 'KspBalanceService',
        method: 'redeemKspToCash',
        feature: 'Wallet',
        status: 'INFO',
        message: 'RPC raw response received',
        params: {'rawType': raw.runtimeType.toString(), 'raw': raw.toString()},
      );

      final response = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{'success': false, 'error': 'Invalid response'};

      if (response['success'] == true) {
        SafeGetx.debugTrace(
          className: 'KspBalanceService',
          method: 'redeemKspToCash',
          feature: 'Wallet',
          status: 'SUCCESS',
          message: 'Redemption successful, applying mutations',
          params: response,
        );
        await _clearPersistedRedemptionKey();
        applyFromRpc(response);
        await afterFinancialMutation(response);
      } else {
        SafeGetx.debugTrace(
          className: 'KspBalanceService',
          method: 'redeemKspToCash',
          feature: 'Wallet',
          status: 'ERROR',
          message: 'RPC returned failure',
          params: response,
        );
      }
      return response;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'KspBalanceService',
        method: 'redeemKspToCash',
        feature: 'Wallet',
        status: 'ERROR',
        message: 'Exception during RPC call',
        error: e,
        stackTrace: stack,
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Resolves the idempotency key for a logical redemption operation.
  ///
  /// Lifecycle:
  ///   - No persisted operation  -> create + persist a NEW key.
  ///   - Persisted key with SAME amount -> reuse it (retry/timeout/restart).
  ///   - Persisted key with DIFFERENT amount -> NEW operation, NEW key.
  ///   - Cleared only on confirmed success (see [redeemKspToCash]).
  Future<String> _resolveRedemptionKey(
    String? callerKey,
    int kspAmount,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final persistedKey = prefs.getString(_redeemKeyPref);
    final persistedAmount = prefs.getInt(_redeemKeyAmountPref);

    if (persistedKey != null && persistedKey.isNotEmpty) {
      if (persistedAmount == kspAmount) {
        return persistedKey;
      }
    }

    final newKey = callerKey ?? _uuid.v4();
    await prefs.setString(_redeemKeyPref, newKey);
    await prefs.setInt(_redeemKeyAmountPref, kspAmount);
    return newKey;
  }

  /// Clears the persisted redemption operation only after confirmed success,
  /// allowing the next intentional redemption to receive a fresh key.
  Future<void> _clearPersistedRedemptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_redeemKeyPref);
    await prefs.remove(_redeemKeyAmountPref);
  }

  Future<void> afterFinancialMutation([
    Map<String, dynamic>? rpcPayload,
  ]) async {
    applyFromRpc(rpcPayload);
    await Future.wait([
      refresh(),
      if (Get.isRegistered<CurrencyController>()) CurrencyController.to.fetchWalletBalances(),
      if (Get.isRegistered<HomeController>()) HomeController.to.fetchRecentTransactions(),
      if (Get.isRegistered<HomeController>()) HomeController.to.fetchNotifications(),
      if (Get.isRegistered<HomeController>()) HomeController.to.fetchDashboard(),
      if (Get.isRegistered<HomeController>()) HomeController.to.fetchProfile(),
    ]);
  }

  void _reset() {
    effectiveKsp.value = 0;
    rewardKsp.value = 0;
    walletKsp.value = 0;
    walletUsd.value = 0;
  }

  static String mapRpcError(String? error) {
    if (error == null || error.isEmpty) return 'unknown_error'.tr;
    if (error == 'Insufficient points' || error == 'Insufficient KSP balance') {
      return 'insufficient_points_msg'.tr;
    }
    return error;
  }
}
