/// Centralized KSP ↔ USD conversion utility.
/// 1 USD = 1000 KSP. Points in DB map 1:1 to KSP.
class KspConverter {
  static const double kspPerUsd = 1000.0;
  
  /// Convert USD to KSP amount
  static double usdToKsp(double usd) => usd * kspPerUsd;
  
  /// Convert KSP to USD equivalent
  static double kspToUsd(double ksp) => ksp / kspPerUsd;
  
  /// Convert raw points (from DB) to KSP (1:1 mapping)
  static int pointsToKsp(int points) => points;
  
  /// Convert KSP to raw points (from DB) (1:1 mapping)
  static int kspToPoints(int ksp) => ksp;
  
  /// Format KSP amount with comma separators (e.g., "12,500 KSP")
  static String formatKsp(int ksp) {
    final formatted = ksp.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted KSP';
  }
  
  /// Format KSP amount with USD equivalent (e.g., "12,500 KSP ≈ $12.50")
  static String formatKspWithUsd(int ksp) {
    final usd = kspToUsd(ksp.toDouble());
    final usdFormatted = usd.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${formatKsp(ksp)} ≈ \$$usdFormatted';
  }
}
