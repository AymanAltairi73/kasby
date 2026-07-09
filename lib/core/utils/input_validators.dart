import 'package:get/get.dart';

/// Shared enterprise-grade input validation helpers for auth and financial flows.
class InputValidators {
  InputValidators._();

  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 80;
  static const int otpLength = 6;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');

  static final RegExp _referralCodeRegex = RegExp(r'^[A-Z0-9]{4,12}$');

  static bool isValidEmail(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return _emailRegex.hasMatch(value.trim().toLowerCase());
  }

  static bool isValidE164Phone(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return _e164Regex.hasMatch(value.trim());
  }

  static bool isValidPassword(String? value) {
    if (value == null || value.isEmpty) return false;
    final len = value.length;
    return len >= minPasswordLength && len <= maxPasswordLength;
  }

  static bool passwordsMatch(String? password, String? confirm) {
    if (password == null || confirm == null) return false;
    return password == confirm;
  }

  static bool isValidFullName(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.length < minNameLength || trimmed.length > maxNameLength) {
      return false;
    }
    return RegExp(r"^[\p{L}\p{M}\s'.-]+$", unicode: true).hasMatch(trimmed);
  }

  static bool isValidOtp(String? value, {int length = otpLength}) {
    if (value == null) return false;
    final trimmed = value.trim();
    return RegExp('^\\d{$length}\$').hasMatch(trimmed);
  }

  static bool isValidReferralCode(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    return _referralCodeRegex.hasMatch(value.trim().toUpperCase());
  }

  static bool isPositiveAmount(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final parsed = double.tryParse(value.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0;
  }

  static String? emailFieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'fill_all_data'.tr;
    if (!isValidEmail(value)) return 'invalid_email'.tr;
    return null;
  }

  static String? passwordFieldValidator(String? value) {
    if (value == null || value.isEmpty) return 'fill_all_data'.tr;
    if (!isValidPassword(value)) return 'weak_password'.tr;
    return null;
  }

  static String? confirmPasswordValidator(String? value, String password) {
    if (value == null || value.isEmpty) return 'fill_all_data'.tr;
    if (!passwordsMatch(password, value)) return 'passwords_dont_match'.tr;
    return null;
  }

  static String? otpFieldValidator(String? value, {int length = otpLength}) {
    if (value == null || value.trim().isEmpty) return 'fill_all_data'.tr;
    if (!isValidOtp(value, length: length)) return 'invalid_otp'.tr;
    return null;
  }

  static String? fullNameFieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'fill_all_data'.tr;
    if (!isValidFullName(value)) return 'invalid_full_name'.tr;
    return null;
  }

  static String? positiveAmountValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'fill_all_data'.tr;
    if (!isPositiveAmount(value)) return 'invalid_amount'.tr;
    return null;
  }
}
