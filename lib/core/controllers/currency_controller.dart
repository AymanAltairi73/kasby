import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/currency_model.dart';
import 'package:kasby/core/models/wallet_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyController extends GetxController {
  static CurrencyController get to => Get.find();

  final RxString selectedCurrency = 'USD'.obs;
  final RxDouble totalBalance = 0.0.obs;
  final RxDouble profitBalance = 0.0.obs;
  final RxDouble investedBalance = 0.0.obs;
  final RxDouble pendingBalance = 0.0.obs;
  final RxBool isLoadingWallet = false.obs;

  /// Currencies fetched from DB (falls back to hardcoded data).
  final RxList<CurrencyModel> currencies = <CurrencyModel>[].obs;

  /// Hardcoded fallback data used only when DB is unreachable.
  final Map<String, Map<String, dynamic>> _fallbackCurrencyData = {
    'USD': {'flag': '🇺🇸', 'rate': 1.0, 'name': 'الدولار الأمريكي'},
    'IQD': {'flag': '🇮🇶', 'rate': 1320.0, 'name': 'الدينار العراقي'},
    'KWD': {'flag': '🇰🇼', 'rate': 0.3071, 'name': 'الدينار الكويتي'},
    'SAR': {'flag': '🇸🇦', 'rate': 3.75, 'name': 'الريال السعودي'},
    'AED': {'flag': '🇦🇪', 'rate': 3.6725, 'name': 'الدرهم الإماراتي'},
    'JOD': {'flag': '🇯🇴', 'rate': 0.7090, 'name': 'الدينار الأردني'},
    'EGP': {'flag': '🇪🇬', 'rate': 47.1, 'name': 'الجنيه المصري'},
    'TRY': {'flag': '🇹🇷', 'rate': 15.59, 'name': 'الليرة التركية'},
    'EUR': {'flag': '🇪🇺', 'rate': 0.8461, 'name': 'اليورو'},
    'CHF': {'flag': '🇨🇭', 'rate': 0.7754, 'name': 'الفرنك السويسري'},
    'JPY': {'flag': '🇯🇵', 'rate': 155.9, 'name': 'الين الياباني'},
  };

  final RxBool isBalanceHidden = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadBalancePrivacy();
    fetchCurrencies();
    fetchWalletBalances();
    _listenToWallet();
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
    if (currencies.isEmpty) return _fallbackCurrencyData;

    final Map<String, Map<String, dynamic>> data = {};
    for (final c in currencies) {
      data[c.code] = {'flag': c.flag, 'rate': c.rate, 'name': c.name};
    }
    return data;
  }

  /// Fetch currencies from the database.
  Future<void> fetchCurrencies() async {
    try {
      final response = await SupabaseService.client
          .from('currencies')
          .select()
          .eq('is_active', true)
          .order('code');

      currencies.value = (response as List)
          .map((json) => CurrencyModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching currencies: $e');
    }
  }

  /// Fetch wallet balances from the database.
  Future<void> fetchWalletBalances() async {
    if (!SupabaseService.isLoggedIn) return;

    isLoadingWallet.value = true;
    try {
      final response = await SupabaseService.client
          .from('wallets')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();

      if (response != null) {
        final wallet = WalletModel.fromJson(response);
        totalBalance.value = wallet.availableBalance;
        profitBalance.value = wallet.profitBalance;
        investedBalance.value = wallet.investedBalance;
        pendingBalance.value = wallet.pendingBalance;
      }
    } catch (e) {
      debugPrint('Error fetching wallet: $e');
    } finally {
      isLoadingWallet.value = false;
    }
  }

  /// Stream subscription for real-time wallet updates.
  StreamSubscription? _walletSubscription;
  
  void _listenToWallet() {
    if (!SupabaseService.isLoggedIn) return;
    
    _walletSubscription?.cancel();
    _walletSubscription = SupabaseService.client
      .from('wallets')
      .stream(primaryKey: ['id'])
      .eq('user_id', SupabaseService.userId!)
      .listen((data) {
        if (data.isNotEmpty) {
          final wallet = WalletModel.fromJson(data.first);
          totalBalance.value = wallet.availableBalance;
          profitBalance.value = wallet.profitBalance;
          investedBalance.value = wallet.investedBalance;
          pendingBalance.value = wallet.pendingBalance;
          debugPrint('Wallet updated via stream: ${wallet.availableBalance}');
        }
      }, onError: (e) {
        debugPrint('Wallet stream error: $e');
        Future.delayed(const Duration(seconds: 5), () => _listenToWallet());
      });
  }

  @override
  void onClose() {
    _walletSubscription?.cancel();
    super.onClose();
  }

  /// Resets all financial balances.
  void resetBalances() {
    totalBalance.value = 0.0;
    profitBalance.value = 0.0;
    investedBalance.value = 0.0;
    pendingBalance.value = 0.0;
  }

  void changeCurrency(String currencyCode) {
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
