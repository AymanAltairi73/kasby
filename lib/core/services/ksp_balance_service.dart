import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Unified KSP balance: Effective KSP = (Wallet USD × 1000) + Reward KSP.
///
/// Reward KSP is stored in [user_points.current_balance].
/// Wallet-backed KSP is derived from [wallets.available_balance] (USD).
class KspBalanceService extends GetxService {
  static KspBalanceService get to => Get.find<KspBalanceService>();

  static const double kspPerUsd = 1000;

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
      effectiveKsp.value = (payload['effective_ksp'] as num?)?.toInt() ?? effectiveKsp.value;
    }
    if (payload.containsKey('reward_ksp')) {
      rewardKsp.value = (payload['reward_ksp'] as num?)?.toInt() ?? rewardKsp.value;
    }
    if (payload.containsKey('wallet_ksp')) {
      walletKsp.value = (payload['wallet_ksp'] as num?)?.toInt() ?? walletKsp.value;
    }
    if (payload.containsKey('wallet_usd')) {
      walletUsd.value = (payload['wallet_usd'] as num?)?.toDouble() ?? walletUsd.value;
    }
    if (payload.containsKey('new_balance') && !payload.containsKey('effective_ksp')) {
      effectiveKsp.value = (payload['new_balance'] as num?)?.toInt() ?? effectiveKsp.value;
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

  Future<void> afterFinancialMutation([Map<String, dynamic>? rpcPayload]) async {
    applyFromRpc(rpcPayload);
    await Future.wait([
      refresh(),
      CurrencyController.to.fetchWalletBalances(),
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
