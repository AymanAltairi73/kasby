/// Centralized platform feature policies for regulatory and store compliance.
///
/// Ensures compliance with Apple App Store Review Guidelines (specifically
/// Guideline 5.3: Gaming, Gambling, and Lotteries).
class PlatformFeatures {
  PlatformFeatures._();

  /// Whether chance-based / randomized reward features (such as the Spin Wheel)
  /// are enabled.
  ///
  /// Permanently disabled across all platforms (iOS, Android, etc.) to ensure
  /// unified financial compliance and complete elimination of chance-based mechanics.
  static bool get isSpinWheelEnabled => false;
}
