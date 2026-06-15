import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configurable OTP lengths per Supabase auth flow.
///
/// Override via `.env` (e.g. `AUTH_OTP_LENGTH_EMAIL_CHANGE=8`).
class AuthOtpConfig {
  AuthOtpConfig._();

  static const int defaultLength = 6;

  static int _fromEnv(String key, int fallback) {
    if (!dotenv.isInitialized) return fallback;
    final raw = dotenv.env[key];
    if (raw == null || raw.trim().isEmpty) return fallback;
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 4 || parsed > 12) return fallback;
    return parsed;
  }

  /// Length for profile / verify-email [purpose] strings.
  static int lengthForPurpose(String purpose) {
    switch (purpose) {
      case 'email_change':
        return _fromEnv('AUTH_OTP_LENGTH_EMAIL_CHANGE', 6);
      case 'password_reset':
      case 'recovery':
        return _fromEnv('AUTH_OTP_LENGTH_RECOVERY', defaultLength);
      case 'phone_change':
      case 'email_change_legacy':
        return _fromEnv('AUTH_OTP_LENGTH_FCM', defaultLength);
      default:
        return _fromEnv('AUTH_OTP_LENGTH_SIGNUP', defaultLength);
    }
  }

  /// Length for native Supabase [OtpType] flows.
  static int lengthForOtpType(OtpType type) {
    switch (type) {
      case OtpType.emailChange:
        return _fromEnv('AUTH_OTP_LENGTH_EMAIL_CHANGE', 6);
      case OtpType.recovery:
        return _fromEnv('AUTH_OTP_LENGTH_RECOVERY', defaultLength);
      case OtpType.signup:
        return _fromEnv('AUTH_OTP_LENGTH_SIGNUP', defaultLength);
      default:
        return _fromEnv('AUTH_OTP_LENGTH_DEFAULT', defaultLength);
    }
  }

  /// FCM / Edge Function OTP (phone, custom email).
  static int get fcmOtpLength => _fromEnv('AUTH_OTP_LENGTH_FCM', defaultLength);

  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');

  static bool isComplete(String code, int expectedLength) =>
      normalize(code).length == expectedLength;
}
