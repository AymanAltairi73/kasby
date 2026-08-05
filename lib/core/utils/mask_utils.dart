/// Masks sensitive identifiers for OTP and verification UI.
class MaskUtils {
  MaskUtils._();

  /// Masks email: `a***@gmail.com`
  static String maskEmail(String email) {
    final trimmed = email.trim();
    final at = trimmed.indexOf('@');
    if (at <= 0) return trimmed;
    final local = trimmed.substring(0, at);
    final domain = trimmed.substring(at);
    if (local.length <= 1) return '*$domain';
    return '${local[0]}${'*' * (local.length - 1).clamp(1, 3)}$domain';
  }

  /// Masks phone: `+967 ******959`
  static String maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.length < 4) return phone;
    final visible = digits.substring(digits.length - 3);
    final prefix = digits.startsWith('+') ? '+' : '';
    final countryPart = digits.length > 6
        ? digits.substring(0, digits.startsWith('+') ? 4 : 3)
        : prefix;
    return '$countryPart ${'*' * 6}$visible';
  }

  static String maskIdentifier({
    required String value,
    required bool isPhone,
  }) => isPhone ? maskPhone(value) : maskEmail(value);
}
