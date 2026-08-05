/// Utility functions for number formatting in Kasby User App.
class KasbyNumberFormatter {
  KasbyNumberFormatter._();

  /// Formats profit percentage displays:
  /// - Shows at most 1 decimal place.
  /// - If the decimal part is 0, display without decimals.
  /// - Examples:
  ///   12.0   -> "12%"
  ///   12.36  -> "12.4%"
  ///   12.65  -> "12.7%"
  ///   15.8   -> "15.8%"
  static String formatProfitPercentage(
    double value, {
    bool includeSign = false,
  }) {
    final roundedStr = value.toStringAsFixed(1);
    final String formatted;
    if (roundedStr.endsWith('.0')) {
      formatted = '${value.toStringAsFixed(0)}%';
    } else {
      formatted = '$roundedStr%';
    }
    if (includeSign && value > 0) {
      return '+$formatted';
    }
    return formatted;
  }
}
