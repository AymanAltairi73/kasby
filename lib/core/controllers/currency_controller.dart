import 'dart:async';
import 'dart:math' show Random;
import 'package:get/get.dart';
import 'package:kasby/core/models/currency_model.dart';
import 'package:kasby/core/models/wallet_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/ksp_balance_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyController extends GetxController {
  static CurrencyController get to => Get.find();

  /// Kasby points conversion: 1 USD = 1,000 KSP.
  static const double kspPerUsd = 1000;

  final RxString selectedCurrency = 'USD'.obs;
  final RxDouble totalBalance = 0.0.obs;
  final RxDouble profitBalance = 0.0.obs;
  final RxDouble investedBalance = 0.0.obs;
  final RxDouble pendingBalance = 0.0.obs;
  final RxBool isLoadingWallet = false.obs;
  final RxBool isWalletFrozen = false.obs;
  final RxnString walletFrozenReason = RxnString();

  /// Currencies fetched from DB (falls back to hardcoded data).
  final RxList<CurrencyModel> currencies = <CurrencyModel>[].obs;

  /// Hardcoded fallback data used only when DB is unreachable.
  static const Map<String, Map<String, dynamic>> _fallbackRates = {
    'USD': {'flag': '🇺🇸', 'rate': 1.0, 'nameKey': 'currency_usd'},
    'IQD': {'flag': '🇮🇶', 'rate': 1320.0, 'nameKey': 'currency_iqd'},
    'KWD': {'flag': '🇰🇼', 'rate': 0.3071, 'nameKey': 'currency_kwd'},
    'SAR': {'flag': '🇸🇦', 'rate': 3.75, 'nameKey': 'currency_sar'},
    'AED': {'flag': '🇦🇪', 'rate': 3.6725, 'nameKey': 'currency_aed'},
    'JOD': {'flag': '🇯🇴', 'rate': 0.7090, 'nameKey': 'currency_jod'},
    'EGP': {'flag': '🇪🇬', 'rate': 47.1, 'nameKey': 'currency_egp'},
    'TRY': {'flag': '🇹🇷', 'rate': 15.59, 'nameKey': 'currency_try'},
    'EUR': {'flag': '🇪🇺', 'rate': 0.8461, 'nameKey': 'currency_eur'},
    'CHF': {'flag': '🇨🇭', 'rate': 0.7754, 'nameKey': 'currency_chf'},
    'JPY': {'flag': '🇯🇵', 'rate': 155.9, 'nameKey': 'currency_jpy'},
  };

  final RxBool isBalanceHidden = false.obs;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'CurrencyController',
      method: 'onInit',
      feature: 'Wallet',
      status: 'INFO',
    );
    super.onInit();
    _loadBalancePrivacy();
    // Initial wallet/currency load is owned by HomeController.fetchAll().
  }

  /// Starts the wallet realtime listener after the initial data fetch settles.
  void startWalletListener({Duration delay = const Duration(seconds: 3)}) {
    Future.delayed(delay, _listenToWallet);
  }

  @override
  void onReady() {
    SafeGetx.debugTrace(
      className: 'CurrencyController',
      method: 'onReady',
      feature: 'Wallet',
      status: 'INFO',
      params: {'currency': selectedCurrency.value},
    );
    super.onReady();
  }

  Future<void> _loadBalancePrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    isBalanceHidden.value = prefs.getBool('is_balance_hidden') ?? false;
  }

  Future<void> toggleBalancePrivacy() async {
    isBalanceHidden.value = !isBalanceHidden.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_balance_hidden', isBalanceHidden.value);
  }

  /// Get currency data (from DB or fallback).
  Map<String, Map<String, dynamic>> get currencyData {
    if (currencies.isEmpty) {
      return _fallbackRates.map(
        (code, data) => MapEntry(code, {
          'flag': data['flag'],
          'rate': data['rate'],
          'name': (data['nameKey'] as String).tr,
        }),
      );
    }

    final Map<String, Map<String, dynamic>> data = {};
    for (final c in currencies) {
      data[c.code] = {'flag': c.flag, 'rate': c.rate, 'name': c.name};
    }
    return data;
  }

  /// Fetch currencies from the database.
  Future<void> fetchCurrencies() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await SupabaseService.client
          .from('currencies')
          .select()
          .eq('is_active', true)
          .order('code');

      currencies.value = (response as List)
          .map((json) => CurrencyModel.fromJson(json))
          .toList();
      SafeGetx.debugTrace(
        className: 'CurrencyController',
        method: 'fetchCurrencies',
        feature: 'Wallet',
        status: 'SUCCESS',
        params: {'count': currencies.length},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'CurrencyController',
        method: 'fetchCurrencies',
        feature: 'Wallet',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Fetch wallet balances from the database.
  Future<void> fetchWalletBalances() async {
    if (!SupabaseService.isLoggedIn) return;

    isLoadingWallet.value = true;
    final stopwatch = Stopwatch()..start();
    try {
      final response = await SupabaseService.client
          .from('wallets')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .eq('currency', 'USD')
          .maybeSingle();

      if (response != null) {
        final wallet = WalletModel.fromJson(response);
        totalBalance.value = wallet.availableBalance;
        profitBalance.value = wallet.profitBalance;
        investedBalance.value = wallet.investedBalance;
        pendingBalance.value = wallet.pendingBalance;
        isWalletFrozen.value = wallet.isFrozen;
        walletFrozenReason.value = wallet.frozenReason;
      }
      if (Get.isRegistered<KspBalanceService>() &&
          Get.isRegistered<HomeController>()) {
        await KspBalanceService.to.refresh();
        HomeController.to.syncKspFromService();
      }
      SafeGetx.debugTrace(
        className: 'CurrencyController',
        method: 'fetchWalletBalances',
        feature: 'Wallet',
        status: 'SUCCESS',
        params: {'hasWallet': response != null},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'CurrencyController',
        method: 'fetchWalletBalances',
        feature: 'Wallet',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingWallet.value = false;
    }
  }

  /// Stream subscription for real-time wallet updates.
  StreamSubscription? _walletSubscription;
  Timer? _walletReconnectTimer;
  Duration _walletReconnectDelay = const Duration(seconds: 2);

  bool _isRealtimeTimeout(Object error) {
    return error.toString().contains('RealtimeSubscribeStatus.timedOut');
  }

  Timer _scheduleWalletReconnect() {
    final delay = _walletReconnectDelay;
    _walletReconnectDelay = Duration(
      seconds: (_walletReconnectDelay.inSeconds * 2).clamp(2, 60),
    );
    final jitterMs = Random().nextInt(800);
    return Timer(delay + Duration(milliseconds: jitterMs), _listenToWallet);
  }

  void _listenToWallet() {
    if (!SupabaseService.isLoggedIn) return;

    _walletReconnectTimer?.cancel();
    _walletSubscription?.cancel();
    _walletSubscription = SupabaseService.client
        .from('wallets')
        .stream(primaryKey: ['id'])
        .eq('user_id', SupabaseService.userId!)
        .listen(
          (data) {
            _walletReconnectDelay = const Duration(seconds: 2);
            final usdRows = data
                .where((row) => (row['currency'] as String?) == 'USD')
                .toList();
            if (usdRows.isEmpty && data.isNotEmpty) {
              // Fallback when currency column missing on older rows
              usdRows.add(data.first);
            }
            if (usdRows.isNotEmpty) {
              final wallet = WalletModel.fromJson(usdRows.first);
              totalBalance.value = wallet.availableBalance;
              profitBalance.value = wallet.profitBalance;
              investedBalance.value = wallet.investedBalance;
              pendingBalance.value = wallet.pendingBalance;
              isWalletFrozen.value = wallet.isFrozen;
              walletFrozenReason.value = wallet.frozenReason;
              if (Get.isRegistered<HomeController>()) {
                HomeController.to.syncDashboardFreezeState(
                  isFrozen: wallet.isFrozen,
                  frozenReason: wallet.frozenReason,
                );
                HomeController.to.fetchDashboard();
                HomeController.to.triggerEarningsUpdate(source: 'realtime_wallet');
              }
              if (Get.isRegistered<KspBalanceService>() &&
                  Get.isRegistered<HomeController>()) {
                unawaited(
                  KspBalanceService.to.refresh().then((_) {
                    HomeController.to.syncKspFromService();
                  }),
                );
              }
              SafeGetx.debugTrace(
                className: 'CurrencyController',
                method: '_listenToWallet',
                feature: 'Wallet',
                status: 'INFO',
                message: 'Wallet updated via stream',
                params: {'isFrozen': wallet.isFrozen},
              );
            }
          },
          onError: (e, stack) {
            SafeGetx.debugTrace(
              className: 'CurrencyController',
              method: '_listenToWallet',
              feature: 'Wallet',
              status: _isRealtimeTimeout(e) ? 'WARN' : 'ERROR',
              message: _isRealtimeTimeout(e)
                  ? 'Wallet stream timed out; retry scheduled'
                  : null,
              error: e,
              stackTrace: stack,
            );
            _walletReconnectTimer?.cancel();
            _walletReconnectTimer = _scheduleWalletReconnect();
          },
        );
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'CurrencyController',
      method: 'onClose',
      feature: 'Wallet',
      status: 'INFO',
    );
    _walletReconnectTimer?.cancel();
    _walletSubscription?.cancel();
    super.onClose();
  }

  /// Resets all financial balances.
  void resetBalances() {
    SafeGetx.debugTrace(
      className: 'CurrencyController',
      method: 'resetBalances',
      feature: 'Wallet',
      status: 'INFO',
    );
    totalBalance.value = 0.0;
    profitBalance.value = 0.0;
    investedBalance.value = 0.0;
    pendingBalance.value = 0.0;
  }

  void changeCurrency(String currencyCode) {
    SafeGetx.debugTrace(
      className: 'CurrencyController',
      method: 'changeCurrency',
      feature: 'Wallet',
      status: 'INFO',
      params: {'from': selectedCurrency.value, 'to': currencyCode},
    );
    selectedCurrency.value = currencyCode;
  }

  String formatToUSD(double usdAmount) {
    String formatted = usdAmount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '\$$formatted';
  }

  double usdToKsp(double usdAmount) => usdAmount * kspPerUsd;

  String formatKspFromUsd(double usdAmount) =>
      formatKspAmount(usdToKsp(usdAmount));

  String formatKspAmount(double kspAmount) {
    final rounded = kspAmount.round();
    final formatted = rounded.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted KSP';
  }

  String formatAmount(double usdAmount) {
    final data = currencyData;
    final rate = data[selectedCurrency.value]?['rate'] as double? ?? 1.0;
    final converted = usdAmount * rate;

    String formatted = converted
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

    return '$formatted ${selectedCurrency.value}';
  }
}
