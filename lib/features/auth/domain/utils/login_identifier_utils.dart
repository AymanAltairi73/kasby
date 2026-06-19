/// Utilities for detecting and normalizing login identifiers (email vs phone).
class LoginIdentifierUtils {
  LoginIdentifierUtils._();

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phoneCharsPattern = RegExp(r'^[\d\s+\-().]+$');

  /// Returns true when [value] looks like an email address.
  static bool isEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && _emailPattern.hasMatch(trimmed);
  }

  /// Returns true when [value] looks like a phone number (not email).
  static bool isPhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || isEmail(trimmed)) return false;
    final digits = digitsOnly(trimmed);
    return digits.length >= 6 && _phoneCharsPattern.hasMatch(trimmed);
  }

  /// Strips non-digit characters except leading + handling.
  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  /// Normalizes phone to E.164 without '+' for Supabase GoTrue.
  static String normalizePhoneForAuth(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  /// Builds E.164 with '+' prefix for display/storage in profile metadata.
  static String toE164(String value) {
    final normalized = normalizePhoneForAuth(value);
    return '+$normalized';
  }
}
