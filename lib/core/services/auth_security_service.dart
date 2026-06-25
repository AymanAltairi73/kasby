import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

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

  static OTPService get _otp => OTPService.to;

  static String _otpErrorMessage(Object error) {
    if (error is OTPDispatchException || error is OTPVerificationException) {
      return error.toString();
    }
    return extractAuthErrorMessage(error);
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

  /// Resend signup verification OTP via Twilio Verify platform.
  static Future<void> resendSignupVerification(String email) async {
    await ensureSignupVerificationSent(email);
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
    if (isPhoneAccountNotFoundError(message)) {
      return 'auth_error_phone_not_registered'.tr;
    }
    return message;
  }

  /// True when phone login OTP was sent with [shouldCreateUser: false] but no
  /// auth user exists for that phone yet.
  static bool isPhoneAccountNotFoundError(Object error) {
    final message = extractAuthErrorMessage(error).toLowerCase();
    return message.contains('signups not allowed') && message.contains('otp');
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

  static bool isEmailDeliveryFailureError(Object error) {
    return isEmailDeliveryFailure(extractAuthErrorMessage(error));
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
        lower.contains('535 5.7.8') ||
        lower.contains('resend_api_key') ||
        lower.contains('resend delivery failed');
  }

  /// Maps edge-function OTP dispatch failures to a user-facing delivery message.
  static String normalizeOtpDispatchError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('resend_api_key') ||
        lower.contains('resend delivery failed') ||
        isEmailDeliveryFailure(message)) {
      return 'auth_error_email_delivery'.tr;
    }
    if (lower.contains('user not found')) {
      return 'auth_error_email_delivery'.tr;
    }
    if (lower.contains('rate_limit')) {
      return 'rate_limit_exceeded_friend'.tr;
    }
    return message;
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

  /// Resend password recovery OTP via Resend (unified with phone reset path).
  static Future<void> resendPasswordRecovery(String email) async {
    await sendPasswordResetOtpViaResend(email);
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

  /// Send password reset OTP via Resend (not Supabase SMTP magic link).
  static Future<void> sendPasswordResetEmail(String email) async {
    await sendPasswordResetOtpViaResend(email);
  }

  /// Dispatches a password-reset OTP through Twilio Verify platform.
  static Future<void> sendPasswordResetOtpViaResend(String email) async {
    final sanitized = email.trim().toLowerCase();
    _log('sendPasswordResetOtpViaResend', 'Sending password reset OTP');
    try {
      await _otp.sendEmailOtp(email: sanitized, purpose: 'password_reset');
    } catch (e) {
      throw AuthException(normalizeOtpDispatchError(_otpErrorMessage(e)));
    }
    _log('sendPasswordResetOtpViaResend', 'Password reset OTP dispatched');
  }

  /// Creates auth user when signup SMTP fails, then sends signup OTP.
  static Future<void> provisionSignupAndSendOtp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    final sanitized = email.trim().toLowerCase();
    _log('provisionSignupAndSendOtp', 'Provisioning user and sending signup OTP');
    try {
      await _otp.sendEmailOtp(
        email: sanitized,
        purpose: 'signup',
        provision: {
          'provision_password': password,
          if (metadata != null) 'provision_metadata': metadata,
        },
      );
    } catch (e) {
      throw AuthException(normalizeOtpDispatchError(_otpErrorMessage(e)));
    }
    _log('provisionSignupAndSendOtp', 'Signup OTP dispatched after provision');
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

  /// Ensures signup verification OTP is dispatched via Twilio Verify platform.
  static Future<void> ensureSignupVerificationSent(String email) async {
    final sanitized = email.trim().toLowerCase();
    _log('ensureSignupVerificationSent', 'Sending signup verification OTP');
    try {
      await _otp.sendEmailOtp(email: sanitized, purpose: 'signup');
      _log('ensureSignupVerificationSent', 'Signup OTP sent');
    } catch (e, stack) {
      _log(
        'ensureSignupVerificationSent',
        'Signup OTP dispatch failed',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      throw AuthException(normalizeOtpDispatchError(_otpErrorMessage(e)));
    }
  }

  /// Verify signup OTP and mark email confirmed server-side.
  static Future<void> confirmSignupEmailOtp({
    required String email,
    required String code,
  }) async {
    final sanitized = email.trim().toLowerCase();
    final normalized = AuthOtpConfig.normalize(code);
    if (normalized.length != AuthOtpConfig.unifiedOtpLength) {
      throw AuthException(
        'otp_length_mismatch'.trParams({
          'count': '${AuthOtpConfig.unifiedOtpLength}',
        }),
      );
    }

    _log('confirmSignupEmailOtp', 'Confirming signup OTP');
    try {
      await _otp.verifyEmailOtp(
        email: sanitized,
        code: normalized,
        purpose: 'signup',
      );
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
    await _syncUserAfterOtpVerification();
    _log('confirmSignupEmailOtp', 'Signup email confirmed');
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

  /// Sends phone verification OTP via Twilio Verify (SMS).
  static Future<void> ensurePhoneVerificationSent({
    required String phone,
    String purpose = 'verification',
  }) async {
    final e164 = _phoneForOtpLookup(_normalizePhone(phone));
    _log('ensurePhoneVerificationSent', 'Sending phone verification OTP', params: {
      'phone': e164,
      'purpose': purpose,
    });
    try {
      await _otp.sendPhoneOtp(phone: e164, purpose: purpose);
      _log('ensurePhoneVerificationSent', 'Phone OTP sent via Twilio Verify');
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
  }

  /// Sends OTP for profile email/phone change via Twilio Verify platform.
  static Future<void> sendProfileChangeOtp({
    required String target,
    required String targetType,
    required String purpose,
  }) async {
    final normalizedTarget = targetType == 'email'
        ? target.trim().toLowerCase()
        : _phoneForOtpLookup(normalizePhone(target.trim()));

    _log('sendProfileChangeOtp', 'Sending profile change OTP', params: {
      'targetType': targetType,
      'purpose': purpose,
    });

    try {
      if (targetType == 'email') {
        await _otp.sendEmailOtp(email: normalizedTarget, purpose: purpose);
      } else {
        await _otp.sendPhoneOtp(phone: normalizedTarget, purpose: purpose);
      }
      _log('sendProfileChangeOtp', 'Profile change OTP sent');
    } catch (e) {
      throw AuthException(
        targetType == 'email'
            ? normalizeOtpDispatchError(_otpErrorMessage(e))
            : translateOtpError(e),
      );
    }
  }

  // ─── PHONE AUTH (Twilio Verify) ───────────────────────
  static Future<AuthResponse> signUpWithEmailVerification({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    final sanitized = email.trim().toLowerCase();
    _log('signUpWithEmailVerification', 'Registering user');

    try {
      if (AuthOtpConfig.tempSkipEmailVerification) {
        return await SupabaseService.auth.signUp(
          email: sanitized,
          password: password,
          data: data,
        );
      }
      return await SupabaseService.auth.signUp(
        email: sanitized,
        password: password,
        data: data,
        emailRedirectTo: authRedirectUrl,
      );
    } on AuthException catch (e) {
      if (AuthOtpConfig.tempSkipEmailVerification &&
          isEmailDeliveryFailureError(e)) {
        _log(
          'signUpWithEmailVerification',
          'Signup email failed — attempting direct sign-in',
          status: 'WARN',
        );
        return await SupabaseService.auth.signInWithPassword(
          email: sanitized,
          password: password.trim(),
        );
      }
      rethrow;
    }
  }

  /// Creates a session after signup when email verification is temporarily skipped.
  static Future<bool> completeRegistrationSession({
    required String email,
    required String password,
  }) async {
    final sanitized = email.trim().toLowerCase();
    if (SupabaseService.auth.currentSession != null) return true;

    try {
      await signInAfterSignup(email: sanitized, password: password);
      return SupabaseService.auth.currentSession != null;
    } on AuthException catch (e, stack) {
      _log(
        'completeRegistrationSession',
        'Sign-in after signup failed',
        status: 'ERROR',
        error: e.message,
        stackTrace: stack,
      );
      return false;
    }
  }

  // ─── PHONE AUTH (Supabase + Twilio) ───────────────────────

  /// Configured SMS OTP length (Supabase dashboard: 6 digits).
  static int get phoneOtpLength =>
      AuthOtpConfig.lengthForOtpType(OtpType.sms);

  /// Returns E.164 phone from auth user or profile metadata.
  static String? getUserPhone() {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final authPhone = user.phone?.trim();
    if (authPhone != null && authPhone.isNotEmpty) return authPhone;
    final metaPhone = user.userMetadata?['phone']?.toString().trim();
    if (metaPhone != null && metaPhone.isNotEmpty) return metaPhone;
    return null;
  }

  /// Whether the user must confirm their phone before accessing the app.
  static bool isPhoneVerificationRequired(User? user) {
    if (user == null) return false;
    final phone = user.phone?.trim();
    if (phone == null || phone.isEmpty) return false;
    return user.phoneConfirmedAt == null;
  }

  /// Whether email or phone verification is pending.
  static bool isIdentityVerificationRequired(User? user) {
    if (user == null) return false;
    if (isEmailVerificationRequired(user)) return true;
    if (isPhoneVerificationRequired(user)) return true;
    return false;
  }

  /// Send phone OTP via Twilio Verify (SMS).
  static Future<void> sendPhoneOtp({
    required String phone,
    bool shouldCreateUser = false,
    Map<String, dynamic>? data,
    String purpose = 'signup',
  }) async {
    final e164 = _phoneForOtpLookup(_normalizePhone(phone));
    _log('sendPhoneOtp', 'Sending Twilio phone OTP', params: {
      'phone': e164,
      'purpose': purpose,
    });
    try {
      await _otp.sendPhoneOtp(
        phone: e164,
        purpose: purpose,
        provision: shouldCreateUser && data != null
            ? {'provision_metadata': data}
            : null,
      );
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
    _log('sendPhoneOtp', 'OTP sent via Twilio Verify');
  }

  /// Resend phone OTP via Twilio Verify.
  static Future<void> resendPhoneOtp({
    required String phone,
    OtpType type = OtpType.sms,
    String purpose = 'verification',
  }) async {
    final e164 = _phoneForOtpLookup(_normalizePhone(phone));
    final resolvedPurpose = type == OtpType.phoneChange ? 'phone_change' : purpose;
    _log('resendPhoneOtp', 'Resending phone OTP', params: {
      'type': type.name,
      'purpose': resolvedPurpose,
    });
    try {
      await _otp.sendPhoneOtp(phone: e164, purpose: resolvedPurpose);
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
    _log('resendPhoneOtp', 'Phone OTP resent');
  }

  static String _purposeFromOtpType(OtpType type, String fallback) {
    switch (type) {
      case OtpType.phoneChange:
        return 'phone_change';
      case OtpType.recovery:
        return 'password_reset';
      case OtpType.signup:
        return 'signup';
      default:
        return fallback;
    }
  }

  /// Verify phone OTP via Twilio Verify and refresh session state.
  static Future<AuthResponse> verifyPhoneOtpCode({
    required String phone,
    required String token,
    OtpType type = OtpType.sms,
    String purpose = 'verification',
    String? newValue,
  }) async {
    final e164 = _phoneForOtpLookup(_normalizePhone(phone));
    final normalizedToken = AuthOtpConfig.normalize(token);
    if (normalizedToken.length != AuthOtpConfig.unifiedOtpLength) {
      throw AuthException(
        'otp_length_mismatch'.trParams({
          'count': '${AuthOtpConfig.unifiedOtpLength}',
        }),
      );
    }

    final resolvedPurpose = _purposeFromOtpType(type, purpose);
    _log('verifyPhoneOtpCode', 'Verifying phone OTP', params: {
      'type': type.name,
      'purpose': resolvedPurpose,
    });

    try {
      await _otp.verifyPhoneOtp(
        phone: e164,
        code: normalizedToken,
        purpose: resolvedPurpose,
        newValue: newValue,
      );
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }

    await _syncUserAfterOtpVerification();
    _log('verifyPhoneOtpCode', 'Phone OTP verified');
    return AuthResponse(
      session: SupabaseService.auth.currentSession,
      user: SupabaseService.auth.currentUser,
    );
  }

  /// Request phone number change — sends OTP to new number via Twilio.
  static Future<void> requestPhoneChange(String newPhone) async {
    final e164 = _phoneForOtpLookup(_normalizePhone(newPhone));
    _log('requestPhoneChange', 'Requesting phone change OTP');
    try {
      await _otp.sendPhoneOtp(phone: e164, purpose: 'phone_change');
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
    _log('requestPhoneChange', 'Phone change OTP sent');
  }

  /// Verify pending phone change OTP.
  static Future<void> confirmPhoneChange({
    required String phone,
    required String token,
  }) async {
    await verifyPhoneOtpCode(
      phone: phone,
      token: token,
      type: OtpType.phoneChange,
      purpose: 'phone_change',
      newValue: _phoneForOtpLookup(_normalizePhone(phone)),
    );
    await refreshUserProfileState();
    _log('confirmPhoneChange', 'Phone updated successfully');
  }

  /// Sends step-up OTP to the signed-in user's phone via Twilio Verify.
  static Future<void> requestStepUpOtp() async {
    final phone = getUserPhone();
    if (phone == null || phone.isEmpty) {
      throw AuthException('phone_verification_required'.tr);
    }
    _log('requestStepUpOtp', 'Requesting step-up OTP');
    try {
      await _otp.sendPhoneOtp(
        phone: _phoneForOtpLookup(phone),
        purpose: 'sensitive_action',
      );
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
    _log('requestStepUpOtp', 'Step-up OTP sent');
  }

  /// Verify step-up OTP after [requestStepUpOtp].
  static Future<void> verifyStepUpOtp({
    required String token,
    String? phone,
  }) async {
    final targetPhone = phone ?? getUserPhone();
    if (targetPhone == null || targetPhone.isEmpty) {
      throw AuthException('phone_verification_required'.tr);
    }
    await verifyPhoneOtpCode(
      phone: targetPhone,
      token: token,
      purpose: 'sensitive_action',
    );
    _log('verifyStepUpOtp', 'Step-up verification complete');
  }

  /// Reauthenticate with password (email) or phone OTP path.
  static Future<void> reauthenticateForSensitiveAction(String password) async {
    final user = SupabaseService.currentUser;
    if (user == null) throw AuthException('cannot_verify_identity'.tr);

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      await reauthenticateWithPassword(password);
      return;
    }

    final phone = getUserPhone();
    if (phone != null && phone.isNotEmpty) {
      await requestStepUpOtp();
      return;
    }

    throw AuthException('cannot_verify_identity'.tr);
  }

  /// Normalizes to the format GoTrue stores in auth.users (E.164 without '+').
  static String normalizePhone(String phone) {
    var normalized = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  static String _normalizePhone(String phone) => normalizePhone(phone);

  static String _phoneForOtpLookup(String phone) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) return trimmed;
    return '+$trimmed';
  }

  /// Looks up the email associated with a phone number for password login.
  static Future<String?> lookupEmailByPhone(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return null;

    _log('lookupEmailByPhone', 'Resolving login email by phone');
    final response = await SupabaseService.client.rpc(
      'lookup_login_by_phone',
      params: {'p_phone': normalized},
    );

    if (response is! Map) return null;
    if (response['found'] != true) return null;
    final email = response['email']?.toString().trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  /// Signs in with email or phone + password, resolving phone to email when needed.
  static Future<void> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final trimmedPassword = password.trim();

    if (trimmed.contains('@')) {
      _log('signInWithIdentifier', 'Signing in with email');
      await SupabaseService.auth.signInWithPassword(
        email: trimmed.toLowerCase(),
        password: trimmedPassword,
      );
      return;
    }

    final normalizedPhone = normalizePhone(trimmed);
    _log('signInWithIdentifier', 'Signing in with phone', params: {
      'phone': normalizedPhone,
    });

    try {
      await SupabaseService.auth.signInWithPassword(
        phone: normalizedPhone,
        password: trimmedPassword,
      );
      return;
    } on AuthException catch (e) {
      final message = extractAuthErrorMessage(e).toLowerCase();
      final retriable = message.contains('invalid login credentials') ||
          message.contains('invalid credentials') ||
          message.contains('user not found');
      if (!retriable) rethrow;
    }

    final email = await lookupEmailByPhone(normalizedPhone);
    if (email == null) {
      throw AuthException('auth_error_invalid_credentials'.tr);
    }

    _log('signInWithIdentifier', 'Retrying sign-in with resolved email');
    await SupabaseService.auth.signInWithPassword(
      email: email,
      password: trimmedPassword,
    );
  }
}
