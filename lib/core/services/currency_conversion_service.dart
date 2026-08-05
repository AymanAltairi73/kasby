import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Centralized service for KSP to USD currency conversion.
///
/// Exchange Rate (FIXED):
/// 1 USD = 1000 KSP
/// 1 KSP = 0.001 USD
///
/// This service provides consistent conversion logic across the entire application.
/// Never duplicate conversion formulas - always use this service.
class CurrencyConversionService extends GetxService {
  static CurrencyConversionService get to =>
      Get.find<CurrencyConversionService>();

  /// Fixed exchange rate: 1 USD = 1000 KSP
  static const double kspPerUsd = 1000.0;

  /// Fixed exchange rate: 1 KSP = 0.001 USD
  static const double usdPerKsp = 0.001;

  /// Convert KSP to USD
  static double kspToUsd(double ksp) {
    return ksp * usdPerKsp;
  }

  /// Convert USD to KSP
  static double usdToKsp(double usd) {
    return usd * kspPerUsd;
  }

  /// Format KSP amount with thousand separators
  static String formatKsp(double ksp) {
    return _formatNumber(ksp, locale: 'en_US');
  }

  /// Format USD amount with currency symbol and 2 decimal places
  static String formatUsd(double usd) {
    return '\$${_formatNumber(usd, decimalPlaces: 2, locale: 'en_US')}';
  }

  /// Format USD equivalent from KSP amount
  static String formatUsdFromKsp(double ksp) {
    final usd = kspToUsd(ksp);
    return formatUsd(usd);
  }

  /// Format KSP amount with USD equivalent displayed below
  /// Example: "125,000 KSP\n≈ $125.00 USD"
  static String formatKspWithUsd(double ksp) {
    final kspFormatted = formatKsp(ksp);
    final usdFormatted = formatUsdFromKsp(ksp);
    return '$kspFormatted KSP\n≈ $usdFormatted USD';
  }

  /// Get formatted USD equivalent text for display
  /// Example: "≈ $125.00 USD"
  static String getUsdEquivalentText(double ksp) {
    final usd = kspToUsd(ksp);
    return '≈ ${formatUsd(usd)} USD';
  }

  /// Format transaction amount with both KSP and USD
  /// Example: "50,000 KSP\n≈ $50.00 USD"
  static String formatTransactionAmount(double ksp) {
    return formatKspWithUsd(ksp);
  }

  /// Get exchange rate text for display
  /// Example: "1 USD = 1000 KSP"
  static String getExchangeRateText() {
    return '1 USD = ${formatKsp(kspPerUsd)} KSP';
  }

  /// Helper method to format numbers with thousand separators
  static String _formatNumber(
    double number, {
    int decimalPlaces = 0,
    String locale = 'en_US',
  }) {
    if (number == 0) return '0';

    final formatter = NumberFormat.decimalPattern(locale);
    if (decimalPlaces > 0) {
      formatter.minimumFractionDigits = decimalPlaces;
      formatter.maximumFractionDigits = decimalPlaces;
    }

    return formatter.format(number);
  }

  /// Format KSP amount for compact display (e.g., 1.2K, 1.5M)
  static String formatKspCompact(double ksp) {
    if (ksp < 1000) return ksp.toStringAsFixed(0);
    if (ksp < 1000000) return '${(ksp / 1000).toStringAsFixed(1)}K';
    if (ksp < 1000000000) return '${(ksp / 1000000).toStringAsFixed(1)}M';
    return '${(ksp / 1000000000).toStringAsFixed(1)}B';
  }

  /// Format USD amount for compact display (e.g., $1.2K, $1.5M)
  static String formatUsdCompact(double usd) {
    if (usd < 1000) return '\$${usd.toStringAsFixed(2)}';
    if (usd < 1000000) return '\$${(usd / 1000).toStringAsFixed(1)}K';
    if (usd < 1000000000) return '\$${(usd / 1000000).toStringAsFixed(1)}M';
    return '\$${(usd / 1000000000).toStringAsFixed(1)}B';
  }
}
