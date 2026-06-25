/// Temporary development-only auth toggles.
///
/// TODO(Production):
/// Re-enable Email Verification screen after authentication flow is finalized.
/// Set [skipEmailVerificationAfterSignup] to `false` before production release.
class DevAuthConfig {
  DevAuthConfig._();

  /// When `true`, successful registration navigates directly to Home instead of
  /// the Email Verification screen. Supabase verification emails are still sent.
  static const bool skipEmailVerificationAfterSignup = false;
}
