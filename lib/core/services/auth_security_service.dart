import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized Supabase Auth security operations (verification, reset, reauth).
class AuthSecurityService {
  AuthSecurityService._();

  static const String defaultRedirect = 'io.supabase.kasby://login-callback';

  static String get authRedirectUrl {
    final fromEnv = dotenv.env['SUPABASE_AUTH_REDIRECT'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return fromEnv.trim();
    }
    return defaultRedirect;
  }

  static void _log(
    String method,
    String message, {
    String status = 'INFO',
    Map<String, Object?>? params,
    Object? error,
    StackTrace? stackTrace,
  }) {
    SafeGetx.debugTrace(
      className: 'AuthSecurityService',
      method: method,
      feature: 'Authentication',
      status: status,
      message: message,
      params: params,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Whether the user must verify their email before accessing the app.
  static bool isEmailVerificationRequired(User? user) {
    if (user == null) return false;
    final email = user.email;
    if (email == null || email.isEmpty) return false;
    return user.emailConfirmedAt == null;
  }

  /// Detect Supabase auth callback deep links (signup, recovery, email change).
  static bool isAuthCallbackUri(Uri uri) {
    if (uri.queryParameters.containsKey('code')) return true;
    if (uri.queryParameters.containsKey('error')) return true;
    if (uri.queryParameters.containsKey('error_description')) return true;
    if (uri.fragment.contains('access_token')) return true;
    if (uri.fragment.contains('error_description')) return true;

    final redirect = Uri.parse(authRedirectUrl);
    if (uri.scheme == redirect.scheme && uri.host == redirect.host) {
      return true;
    }
    if (uri.path.contains('/auth/callback')) return true;
    return false;
  }

  /// Exchange an auth deep link for a session.
  static Future<void> handleAuthCallback(Uri uri) async {
    _log('handleAuthCallback', 'Processing auth callback', params: {
      'host': uri.host,
      'hasCode': uri.queryParameters.containsKey('code'),
    });

    if (uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_description')) {
      final description = uri.queryParameters['error_description'] ??
          uri.queryParameters['error'] ??
          'auth_link_invalid'.tr;
      _log(
        'handleAuthCallback',
        'Auth callback returned error',
        status: 'ERROR',
        params: {'description': description},
      );
      throw AuthException(description);
    }

    try {
      await SupabaseService.auth.getSessionFromUrl(uri);
      _log('handleAuthCallback', 'Session established from auth callback');
    } on AuthException catch (e, stack) {
      _log(
        'handleAuthCallback',
        'Failed to establish session from callback',
        status: 'ERROR',
        error: e.message,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Resend signup confirmation email.
  static Future<void> resendSignupVerification(String email) async {
    await resendOtp(email: email, type: OtpType.signup);
  }

  /// Resend or send OTP for a given auth flow type.
  static Future<void> resendOtp({
    required String email,
    required OtpType type,
  }) async {
    final sanitized = email.trim().toLowerCase();
    _log('resendOtp', 'Resending OTP', params: {'type': type.name});
    await SupabaseService.auth.resend(type: type, email: sanitized);
    _log('resendOtp', 'OTP resent', params: {'type': type.name});
  }

  /// Verify a Supabase email OTP (length validated against [AuthOtpConfig]).
  static Future<void> verifyOtpCode({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    final sanitized = email.trim().toLowerCase();
    final normalized = AuthOtpConfig.normalize(token);
    final expectedLength = AuthOtpConfig.lengthForOtpType(type);
    if (normalized.length != expectedLength) {
      throw AuthException(
        'otp_length_mismatch'.trParams({'count': '$expectedLength'}),
      );
    }
    _log(
      'verifyOtpCode',
      'Verifying OTP',
      params: {'type': type.name, 'length': expectedLength},
    );
    await SupabaseService.auth.verifyOTP(
      type: type,
      token: normalized,
      email: sanitized,
    );
    await _syncUserAfterOtpVerification();
    _log('verifyOtpCode', 'OTP verified', params: {'type': type.name});
  }

  /// Fetches the latest user record from Supabase Auth (not cached JWT claims).
  static Future<User?> fetchFreshUser() async {
    try {
      final response = await SupabaseService.auth.getUser();
      return response.user;
    } catch (e, stack) {
      _log(
        'fetchFreshUser',
        'getUser failed — falling back to refreshSession',
        status: 'WARN',
        error: e,
        stackTrace: stack,
      );
      try {
        await SupabaseService.auth.refreshSession();
      } catch (_) {}
      return SupabaseService.auth.currentUser;
    }
  }

  static Future<void> _syncUserAfterOtpVerification() async {
    await fetchFreshUser();
    await SupabaseService.hardRefreshSession();
  }

  /// Extracts a human-readable message from Supabase [AuthException] payloads.
  static String extractAuthErrorMessage(Object error) {
    if (error is AuthException) {
      return normalizeAuthErrorMessage(error.message);
    }
    return normalizeAuthErrorMessage(error.toString());
  }

  /// Parses GoTrue JSON error bodies (`{"code":"...","message":"..."}`).
  static String normalizeAuthErrorMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final message = decoded['message'] ?? decoded['msg'] ?? decoded['error'];
          if (message != null && message.toString().trim().isNotEmpty) {
            return message.toString();
          }
        }
      } catch (_) {}
    }
    return trimmed;
  }

  /// Maps Supabase OTP verification errors to user-facing OTP messages.
  static String translateOtpError(Object error) {
    final message = extractAuthErrorMessage(error);
    final lower = message.toLowerCase();
    // GoTrue may return "Email link is invalid or has expired" for OTP failures.
    if (lower.contains('link') &&
        (lower.contains('invalid') || lower.contains('expired'))) {
      return lower.contains('expired') ? 'otp_expired'.tr : 'invalid_otp'.tr;
    }
    if (lower.contains('expired') ||
        lower.contains('has expired') ||
        lower.contains('otp_expired')) {
      return 'otp_expired'.tr;
    }
    if (lower.contains('invalid') ||
        lower.contains('otp') ||
        lower.contains('token') ||
        lower.contains('verification code') ||
        lower.contains('does not match')) {
      return 'invalid_otp'.tr;
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'auth_error_rate_limit'.tr;
    }
    return message;
  }

  /// Maps general Supabase auth errors (login, signup, links).
  static String translateAuthError(Object error) {
    final message = extractAuthErrorMessage(error);
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'auth_error_invalid_credentials'.tr;
    }
    if (lower.contains('email not confirmed')) {
      return 'auth_error_email_not_confirmed'.tr;
    }
    if (lower.contains('user already registered')) {
      return 'auth_error_user_exists'.tr;
    }
    if (lower.contains('password should be')) {
      return 'auth_error_weak_password'.tr;
    }
    if (lower.contains('rate limit')) {
      return 'auth_error_rate_limit'.tr;
    }
    if (lower.contains('invalid email') || lower.contains('email address')) {
      return 'auth_error_invalid_credentials'.tr;
    }
    if (lower.contains('user not found')) {
      return 'auth_error_invalid_credentials'.tr;
    }
    if (lower.contains('signups not allowed')) {
      return 'auth_error_signups_not_allowed'.tr;
    }
    if (lower.contains('database error saving new user')) {
      return 'auth_error_duplicate_contact'.tr;
    }
    if (isEmailDeliveryFailure(message)) {
      return 'auth_error_email_delivery'.tr;
    }
    if (_isOtpRelatedAuthError(message)) {
      return translateOtpError(message);
    }
    if (lower.contains('link') ||
        lower.contains('callback') ||
        lower.contains('access_denied') ||
        lower.contains('flow_state')) {
      return 'auth_link_invalid'.tr;
    }
    return message;
  }

  static bool isEmailDeliveryFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('error sending') ||
        lower.contains('sending recovery email') ||
        lower.contains('sending email change') ||
        lower.contains('sending confirmation email') ||
        lower.contains('email delivery') ||
        lower.contains('unexpected_failure') ||
        lower.contains('badcredentials') ||
        lower.contains('username and password not accepted') ||
        lower.contains('535 5.7.8');
  }

  static bool _isOtpRelatedAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('link') &&
        (lower.contains('invalid') || lower.contains('expired')) &&
        !lower.contains('callback') &&
        !lower.contains('flow_state')) {
      return true;
    }
    return lower.contains('otp') ||
        lower.contains('token has expired') ||
        lower.contains('invalid token') ||
        lower.contains('verification code');
  }

  /// Resend password recovery OTP / email.
  static Future<void> resendPasswordRecovery(String email) async {
    await resendOtp(email: email, type: OtpType.recovery);
  }

  /// Refresh session when possible; returns verification status.
  static Future<bool> refreshAndCheckEmailVerified() async {
    _log('refreshAndCheckEmailVerified', 'Checking verification status');
    await fetchFreshUser();
    await SupabaseService.hardRefreshSession();
    final user = await fetchFreshUser();
    if (user == null) return false;

    final verified = !isEmailVerificationRequired(user);
    _log(
      'refreshAndCheckEmailVerified',
      'Verification status checked',
      params: {
        'verified': verified,
        'emailConfirmedAt': user.emailConfirmedAt,
      },
    );
    return verified;
  }

  /// Send native Supabase password reset email.
  static Future<void> sendPasswordResetEmail(String email) async {
    final sanitized = email.trim().toLowerCase();
    _log('sendPasswordResetEmail', 'Sending password reset email');
    await SupabaseService.auth.resetPasswordForEmail(
      sanitized,
      redirectTo: authRedirectUrl,
    );
    _log('sendPasswordResetEmail', 'Password reset email sent');
  }

  /// Reauthenticate with current password (required before sensitive updates).
  static Future<void> reauthenticateWithPassword(String password) async {
    final email = SupabaseService.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw AuthException('cannot_verify_identity'.tr);
    }
    _log('reauthenticateWithPassword', 'Reauthenticating user');
    await SupabaseService.auth.signInWithPassword(
      email: email,
      password: password.trim(),
    );
    _log('reauthenticateWithPassword', 'Reauthentication successful');
  }

  /// Request email change via Supabase Auth (confirmation email sent).
  static Future<void> requestEmailChange(String newEmail) async {
    final sanitized = newEmail.trim().toLowerCase();
    _log('requestEmailChange', 'Requesting email change');
    await SupabaseService.auth.updateUser(UserAttributes(email: sanitized));
    _log('requestEmailChange', 'Email change confirmation sent');
  }

  /// Update password and refresh session.
  static Future<void> updatePassword(String newPassword) async {
    _log('updatePassword', 'Updating password');
    await SupabaseService.auth.updateUser(
      UserAttributes(password: newPassword.trim()),
    );
    await SupabaseService.hardRefreshSession();
    _log('updatePassword', 'Password updated and session refreshed');
  }

  /// Refresh session and reload all user-facing profile state.
  static Future<void> refreshUserProfileState() async {
    _log('refreshUserProfileState', 'Refreshing session and profile data');
    await fetchFreshUser();
    await SupabaseService.hardRefreshSession();
    if (Get.isRegistered<HomeController>()) {
      await HomeController.to.fetchProfile();
      await HomeController.to.fetchAll();
      HomeController.to.reconnectStreams();
    }
    if (Get.isRegistered<CurrencyController>()) {
      await CurrencyController.to.fetchWalletBalances();
    }
    _log('refreshUserProfileState', 'Profile state refreshed');
  }

  /// Returns true when a pending email change has been confirmed.
  static Future<bool> isPendingEmailChangeComplete(String targetEmail) async {
    await fetchFreshUser();
    await SupabaseService.hardRefreshSession();
    final user = await fetchFreshUser();
    if (user == null) return false;

    final normalizedTarget = targetEmail.trim().toLowerCase();
    final currentEmail = user.email?.trim().toLowerCase();

    if (currentEmail == normalizedTarget) {
      return user.emailConfirmedAt != null;
    }

    return false;
  }

  /// Whether status polling can refresh the session (logged-in flows).
  static bool canPollVerificationStatus({required String purpose}) {
    if (purpose == 'email_change') {
      return SupabaseService.auth.currentSession?.refreshToken != null;
    }
    return SupabaseService.auth.currentSession?.refreshToken != null &&
        SupabaseService.auth.currentSession!.refreshToken!.isNotEmpty;
  }

  /// Ensures signup confirmation OTP/email is dispatched after registration.
  ///
  /// Primary path: native GoTrue resend (matches Supabase "Confirm sign up").
  /// Falls back to [send-otp] edge function when SMTP delivery fails.
  static Future<void> ensureSignupVerificationSent(String email) async {
    final sanitized = email.trim().toLowerCase();
    _log('ensureSignupVerificationSent', 'Sending signup verification');

    try {
      await resendOtp(email: sanitized, type: OtpType.signup);
      _log(
        'ensureSignupVerificationSent',
        'Signup OTP sent via Supabase Auth',
      );
      return;
    } catch (e, stack) {
      _log(
        'ensureSignupVerificationSent',
        'Supabase auth resend failed, trying Resend edge function',
        status: 'WARN',
        error: e,
        stackTrace: stack,
      );
    }

    await _sendSignupOtpViaResend(sanitized);
    _log(
      'ensureSignupVerificationSent',
      'Signup OTP sent via Resend edge function',
    );
  }

  /// Verify signup OTP delivered by [send-otp] and mark email confirmed server-side.
  static Future<void> confirmSignupEmailOtp({
    required String email,
    required String code,
  }) async {
    final sanitized = email.trim().toLowerCase();
    final normalized = AuthOtpConfig.normalize(code);
    final expectedLength = AuthOtpConfig.lengthForOtpType(OtpType.signup);
    if (normalized.length != expectedLength) {
      throw AuthException(
        'otp_length_mismatch'.trParams({'count': '$expectedLength'}),
      );
    }

    try {
      await verifyOtpCode(
        email: sanitized,
        token: normalized,
        type: OtpType.signup,
      );
      _log('confirmSignupEmailOtp', 'Signup email confirmed via Supabase Auth');
      return;
    } catch (e, stack) {
      _log(
        'confirmSignupEmailOtp',
        'Native signup OTP failed, trying edge function',
        status: 'WARN',
        error: e,
        stackTrace: stack,
      );
    }

    _log('confirmSignupEmailOtp', 'Confirming signup OTP via edge function');
    final response = await _invokeEdgeFunction(
      'confirm-signup-email',
      body: {
        'email': sanitized,
        'otp_code': normalized,
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['success'] != true) {
      final message =
          data is Map ? (data['error'] ?? 'invalid_otp'.tr) : 'invalid_otp'.tr;
      throw AuthException(translateOtpError(message));
    }

    await _syncUserAfterOtpVerification();
    _log('confirmSignupEmailOtp', 'Signup email confirmed via edge function');
  }

  /// Sign in immediately after signup email confirmation (no session yet).
  static Future<void> signInAfterSignup({
    required String email,
    required String password,
  }) async {
    final sanitized = email.trim().toLowerCase();
    _log('signInAfterSignup', 'Creating session after signup verification');
    await SupabaseService.auth.signInWithPassword(
      email: sanitized,
      password: password.trim(),
    );
    await SupabaseService.hardRefreshSession();
    _log('signInAfterSignup', 'Session created');
  }

  static Future<void> _sendSignupOtpViaResend(String email) async {
    final response = await _invokeEdgeFunction(
      'send-otp',
      body: {
        'target': email,
        'target_type': 'email',
        'purpose': 'signup',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['success'] != true) {
      final message = data is Map
          ? (data['error']?.toString() ?? 'auth_error_email_delivery'.tr)
          : 'auth_error_email_delivery'.tr;
      throw AuthException(message);
    }
  }

  static Future<http.Response> _invokeEdgeFunction(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    if (!dotenv.isInitialized) {
      throw AuthException('auth_error_email_delivery'.tr);
    }

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl == null ||
        supabaseUrl.isEmpty ||
        anonKey == null ||
        anonKey.isEmpty) {
      throw AuthException('auth_error_email_delivery'.tr);
    }

    final url = Uri.parse('$supabaseUrl/functions/v1/$functionName');
    return http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'apikey': anonKey,
      },
      body: jsonEncode(body),
    );
  }

  /// Native Supabase sign-up with email confirmation redirect configured.
  static Future<AuthResponse> signUpWithEmailVerification({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) {
    final sanitized = email.trim().toLowerCase();
    _log('signUpWithEmailVerification', 'Registering user');
    return SupabaseService.auth.signUp(
      email: sanitized,
      password: password,
      data: data,
      emailRedirectTo: authRedirectUrl,
    );
  }
}
