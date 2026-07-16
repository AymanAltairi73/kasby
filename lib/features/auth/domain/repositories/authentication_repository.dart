import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/security_notification_service.dart';
import 'package:kasby/core/services/security_activity_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/domain/services/email_otp_service.dart';
import 'package:kasby/features/auth/domain/services/phone_otp_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Domain repository — all authentication operations via Supabase Auth only.
class AuthenticationRepository extends GetxService {
  static AuthenticationRepository get to => Get.find();

  EmailOtpService get _emailOtp => EmailOtpService.to;
  PhoneOtpService get _phoneOtp => PhoneOtpService.to;

  static const String defaultRedirect = 'io.supabase.kasby://login-callback';

  static String get authRedirectUrl {
    final fromEnv = dotenv.env['SUPABASE_AUTH_REDIRECT'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return fromEnv.trim();
    }
    return defaultRedirect;
  }

  GoTrueClient get _auth => SupabaseService.auth;

  // ─── REGISTRATION ───────────────────────────────────────

  Future<AuthResponse> register({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    final sanitized = email.trim().toLowerCase();
    final sw = AuthenticationLogger.logStart(
      'registration',
      method: 'register',
      authMethod: 'email_password',
      email: sanitized,
    );
    try {
      final response = await _auth.signUp(
        email: sanitized,
        password: password,
        data: metadata,
        emailRedirectTo: authRedirectUrl,
      );
      AuthenticationLogger.logSuccess(
        'registration',
        stopwatch: sw,
        method: 'register',
        authMethod: 'email_password',
        email: sanitized,
        params: {'hasSession': response.session != null},
      );
      return response;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'registration',
        e,
        stopwatch: sw,
        method: 'register',
        authMethod: 'email_password',
        email: sanitized,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ─── LOGIN / LOGOUT ───────────────────────────────────────

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final trimmedPassword = password.trim();
    final sw = AuthenticationLogger.logStart(
      'login',
      method: 'signIn',
      authMethod: trimmed.contains('@') ? 'email_password' : 'phone_password',
      email: trimmed.contains('@') ? trimmed.toLowerCase() : null,
      phone: trimmed.contains('@') ? null : trimmed,
    );
    try {
      if (trimmed.contains('@')) {
        await _auth.signInWithPassword(
          email: trimmed.toLowerCase(),
          password: trimmedPassword,
        );
      } else {
        final phoneE164 = _phoneOtp.toE164(trimmed);
        try {
          await _auth.signInWithPassword(
            phone: phoneE164,
            password: trimmedPassword,
          );
        } on AuthException catch (e) {
          final message = e.message.toLowerCase();
          final retriable = message.contains('invalid login credentials') ||
              message.contains('invalid credentials') ||
              message.contains('user not found') ||
              message.contains('phone not confirmed');
          if (!retriable) rethrow;

          final email = await lookupEmailByPhone(trimmed);
          if (email == null) rethrow;
          await _auth.signInWithPassword(
            email: email,
            password: trimmedPassword,
          );
        }
      }
      AuthenticationLogger.logSuccess(
        'login',
        stopwatch: sw,
        method: 'signIn',
        authMethod: trimmed.contains('@') ? 'email_password' : 'phone_password',
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'login',
        e,
        stopwatch: sw,
        method: 'signIn',
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    final sw = AuthenticationLogger.logStart('logout', method: 'signOut');
    try {
      await _auth.signOut();
      AuthenticationLogger.logSuccess('logout', stopwatch: sw, method: 'signOut');
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'logout',
        e,
        stopwatch: sw,
        method: 'signOut',
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<String?> lookupEmailByPhone(String phone) async {
    var normalized = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) normalized = normalized.substring(1);

    final response = await SupabaseService.client.rpc(
      'lookup_login_by_phone',
      params: {'p_phone': normalized},
    );
    if (response is! Map) return null;
    if (response['found'] != true) return null;
    return response['email']?.toString().trim().toLowerCase();
  }

  // ─── EMAIL VERIFICATION ─────────────────────────────────

  Future<void> sendSignupEmailOtp(String email) =>
      _emailOtp.sendSignupVerification(email);

  Future<void> verifySignupEmailOtp({
    required String email,
    required String code,
  }) async {
    await _emailOtp.verify(
      email: email,
      token: code,
      type: OtpType.signup,
    );
    await _syncAfterOtp();
    await ensureUserProfile();
    if (Get.isRegistered<SecurityNotificationService>()) {
      await SecurityNotificationService.to.notifyEmailVerified();
    }
    if (Get.isRegistered<SecurityActivityService>()) {
      await SecurityActivityService.to.logEvent(SecurityEventType.emailVerified);
    }
  }

  Future<bool> isPhoneAvailable(String phone) async {
    final sanitized = _phoneOtp.toE164(phone.trim());
    final response = await SupabaseService.client.rpc(
      'fn_check_phone_available',
      params: {'p_phone': sanitized},
    );
    if (response is! Map) {
      throw AuthException('unexpected_error'.tr);
    }
    return response['available'] == true;
  }

  Future<bool> isEmailAvailable(String email) async {
    final sanitized = email.trim().toLowerCase();
    final response = await SupabaseService.client.rpc(
      'fn_check_email_available',
      params: {'p_email': sanitized},
    );
    if (response is! Map) {
      throw AuthException('unexpected_error'.tr);
    }
    return response['available'] == true;
  }

  Future<bool> ensureUserProfile() async {
    if (!SupabaseService.isLoggedIn) return false;
    final sw = AuthenticationLogger.logStart(
      'profile_provision',
      method: 'ensureUserProfile',
    );
    try {
      final response = await SupabaseService.client.rpc('fn_ensure_user_profile');
      final success = response is Map && response['success'] == true;
      AuthenticationLogger.logSuccess(
        'profile_provision',
        stopwatch: sw,
        method: 'ensureUserProfile',
        params: {
          'success': success,
          if (response is Map) 'created': response['created'],
        },
      );
      return success;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'profile_provision',
        e,
        stopwatch: sw,
        method: 'ensureUserProfile',
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<void> signInAfterSignup({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
    await SupabaseService.hardRefreshSession();
  }

  // ─── PHONE VERIFICATION ───────────────────────────────────

  Future<void> sendPhoneVerificationOtp(String phone) =>
      _phoneOtp.sendPhoneVerification(phone);

  Future<void> verifyPhoneOtp({
    required String phone,
    required String code,
    OtpType type = OtpType.sms,
  }) async {
    await _phoneOtp.verify(phone: phone, token: code, type: type);
    await _syncAfterOtp();
    if (type == OtpType.sms || type == OtpType.signup) {
      await SecurityNotificationService.to.notifyPhoneVerified();
      await SecurityActivityService.to.logEvent(SecurityEventType.phoneVerified);
    }
  }

  Future<void> resendPhoneOtp({
    required String phone,
    OtpType type = OtpType.sms,
  }) =>
      _phoneOtp.resend(phone: phone, type: type);

  // ─── PASSWORD RESET ───────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) =>
      _emailOtp.sendPasswordReset(email);

  Future<void> sendPasswordResetPhone(String phone) =>
      _phoneOtp.sendOtp(phone: phone, shouldCreateUser: false);

  Future<void> verifyPasswordResetEmailOtp({
    required String email,
    required String code,
  }) async {
    await _emailOtp.verify(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
  }

  Future<void> verifyPasswordResetPhoneOtp({
    required String phone,
    required String code,
  }) async {
    await _phoneOtp.verify(
      phone: phone,
      token: code,
      type: OtpType.recovery,
    );
  }

  Future<void> completePasswordReset(String newPassword) async {
    await _emailOtp.updatePasswordAfterRecovery(newPassword);
    await SecurityNotificationService.to.notifyPasswordReset();
    await SecurityActivityService.to.logEvent(SecurityEventType.passwordReset);
  }

  Future<void> updatePassword(String newPassword) async {
    final sw = AuthenticationLogger.logStart(
      'password_change',
      method: 'updatePassword',
      authMethod: 'password',
    );
    try {
      await _auth.updateUser(UserAttributes(password: newPassword.trim()));
      await SupabaseService.hardRefreshSession();
      AuthenticationLogger.logSuccess(
        'password_change',
        stopwatch: sw,
        method: 'updatePassword',
      );
      await SecurityNotificationService.to.notifyPasswordChanged();
      await SecurityActivityService.to.logEvent(SecurityEventType.passwordChange);
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_change',
        e,
        stopwatch: sw,
        method: 'updatePassword',
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ─── EMAIL / PHONE CHANGE ─────────────────────────────────

  Future<void> initiateEmailChange(String newEmail) =>
      _emailOtp.sendEmailChange(newEmail);

  Future<void> confirmEmailChange({
    required String newEmail,
    required String code,
  }) async {
    // Supabase email change requires double confirmation - verifyOTP must be called twice
    // First call accepts the token but throws AuthException (no session in response)
    // Second call completes the email change
    // See: https://github.com/supabase/supabase-flutter/issues/981
    try {
      await _emailOtp.verify(
        email: newEmail,
        token: code,
        type: OtpType.emailChange,
      );
    } on AuthException catch (e) {
      // Expected: first verification returns no session, throws exception
      // Continue with second verification
      if (e.message != 'An error occurred on token verification.') {
        rethrow;
      }
    }
    // Second verification completes the email change
    await _emailOtp.verify(
      email: newEmail,
      token: code,
      type: OtpType.emailChange,
    );
    await refreshUserProfileState();
    await SecurityNotificationService.to.notifyEmailChanged();
    await SecurityActivityService.to.logEvent(SecurityEventType.emailChange);
  }

  Future<void> initiatePhoneChange(String newPhone) =>
      _phoneOtp.sendPhoneChange(newPhone);

  Future<void> confirmPhoneChange({
    required String newPhone,
    required String code,
  }) async {
    await _phoneOtp.verify(
      phone: newPhone,
      token: code,
      type: OtpType.phoneChange,
    );
    await refreshUserProfileState();
    await SecurityNotificationService.to.notifyPhoneChanged();
    await SecurityActivityService.to.logEvent(SecurityEventType.phoneChange);
  }

  // ─── STEP-UP (account security, not financial) ────────────

  Future<void> sendStepUpOtp(String phone) =>
      _phoneOtp.sendStepUpOtp(phone);

  Future<void> verifyStepUpOtp({
    required String phone,
    required String code,
  }) =>
      _phoneOtp.verifyStepUpOtp(phone: phone, token: code);

  // ─── REAUTH ───────────────────────────────────────────────

  Future<void> reauthenticateWithPassword(String password) async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw AuthException('cannot_verify_identity'.tr);
    }
    final sw = AuthenticationLogger.logStart(
      'password_verification',
      method: 'reauthenticateWithPassword',
      authMethod: 'email_password',
      email: email,
    );
    try {
      await _auth.signInWithPassword(
        email: email,
        password: password.trim(),
      );
      AuthenticationLogger.logSuccess(
        'password_verification',
        stopwatch: sw,
        method: 'reauthenticateWithPassword',
        authMethod: 'email_password',
        email: email,
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_verification',
        e,
        stopwatch: sw,
        method: 'reauthenticateWithPassword',
        authMethod: 'email_password',
        email: email,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ─── SESSION ──────────────────────────────────────────────

  Future<User?> fetchFreshUser() async {
    final sw = AuthenticationLogger.logStart(
      'session_refresh',
      method: 'fetchFreshUser',
    );
    try {
      final response = await _auth.getUser();
      AuthenticationLogger.logSuccess(
        'session_refresh',
        stopwatch: sw,
        method: 'fetchFreshUser',
      );
      return response.user;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'session_refresh',
        e,
        stopwatch: sw,
        method: 'fetchFreshUser',
        stackTrace: stack,
      );
      try {
        await _auth.refreshSession();
      } catch (_) {}
      return _auth.currentUser;
    }
  }

  Future<void> refreshSession() async {
    final sw = AuthenticationLogger.logStart(
      'session_refresh',
      method: 'refreshSession',
    );
    try {
      await _auth.refreshSession();
      AuthenticationLogger.logSuccess(
        'session_refresh',
        stopwatch: sw,
        method: 'refreshSession',
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'session_refresh',
        e,
        stopwatch: sw,
        method: 'refreshSession',
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> refreshUserProfileState() async {
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
  }

  Future<void> _syncAfterOtp() async {
    await fetchFreshUser();
    await SupabaseService.hardRefreshSession();
  }

  // ─── VERIFICATION STATUS ──────────────────────────────────

  bool isEmailVerificationRequired(User? user) {
    if (user == null) return false;
    final email = user.email;
    if (email == null || email.isEmpty) return false;
    return user.emailConfirmedAt == null;
  }

  bool isPhoneVerificationRequired(User? user) {
    if (user == null) return false;
    final phone = user.phone?.trim();
    if (phone == null || phone.isEmpty) return false;
    return user.phoneConfirmedAt == null;
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    await fetchFreshUser();
    await SupabaseService.hardRefreshSession();
    final user = await fetchFreshUser();
    if (user == null) return false;
    return !isEmailVerificationRequired(user);
  }

  Future<bool> isPendingEmailChangeComplete(String targetEmail) async {
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

  String? getUserPhone() {
    final user = _auth.currentUser;
    if (user == null) return null;
    final authPhone = user.phone?.trim();
    if (authPhone != null && authPhone.isNotEmpty) return authPhone;
    final metaPhone = user.userMetadata?['phone']?.toString().trim();
    if (metaPhone != null && metaPhone.isNotEmpty) return metaPhone;
    return null;
  }

  Future<void> resendEmailOtp({
    required String email,
    required OtpType type,
  }) =>
      _emailOtp.resend(email: email, type: type);

  int get phoneOtpLength => AuthOtpConfig.lengthForOtpType(OtpType.sms);
}
