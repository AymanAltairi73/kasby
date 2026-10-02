import 'package:get/get.dart';

/// Centralized platform feature policies for regulatory and store compliance.
///
/// Ensures compliance with Apple App Store Review Guidelines (specifically
/// Guideline 5.3: Gaming, Gambling, and Lotteries).
class PlatformFeatures {
  PlatformFeatures._();

  /// Whether chance-based / randomized reward features (such as the Spin Wheel)
  /// are enabled on the current platform.
  ///
  /// On iOS, this is strictly `false` to comply with Apple App Store Review
  /// Guidelines regarding chance-based reward mechanisms.
  /// On other platforms (e.g. Android), it remains enabled where supported.
  static bool get isSpinWheelEnabled => !GetPlatform.isIOS;
}
