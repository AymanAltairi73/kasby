import 'package:get/get.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/enterprise_operations_logger.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/domain/repositories/authentication_repository.dart';
import 'package:kasby/features/auth/domain/services/email_otp_service.dart';
import 'package:kasby/features/auth/domain/services/phone_otp_service.dart';
import 'package:kasby/features/auth/domain/utils/login_identifier_utils.dart';
import 'package:kasby/core/services/sensitive_operation_guard.dart';
import 'package:kasby/core/utils/input_validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

/// Centralized Supabase Auth security operations — Supabase Auth only.
class AuthSecurityService {
  AuthSecurityService._();

  static const _deletedAccountPrefix = 'DELETED_ACCOUNT:';

  static AuthenticationRepository get _repo => AuthenticationRepository.to;
  static EmailOtpService get _emailOtp => EmailOtpService.to;
  static PhoneOtpService get _phoneOtp => PhoneOtpService.to;

  static String get authRedirectUrl => AuthenticationRepository.authRedirectUrl;
  static const String defaultRedirect = AuthenticationRepository.defaultRedirect;

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

  static bool isEmailVerificationRequired(User? user) =>
      _repo.isEmailVerificationRequired(user);

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

  static Future<void> handleAuthCallback(Uri uri) async {
    final sw = AuthenticationLogger.logStart(
      'email_verification_deep_link',
      method: 'handleAuthCallback',
      authMethod: 'email_link',
      params: {
        'host': uri.host,
        'hasCode': uri.queryParameters.containsKey('code'),
      },
    );
    _log('handleAuthCallback', 'Processing auth callback', params: {
      'host': uri.host,
      'hasCode': uri.queryParameters.containsKey('code'),
    });

    if (uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_description')) {
      final description = uri.queryParameters['error_description'] ??
          uri.queryParameters['error'] ??
          'auth_link_invalid'.tr;
      final error = AuthException(description);
      AuthenticationLogger.logFailure(
        'email_verification_deep_link',
        error,
        stopwatch: sw,
        method: 'handleAuthCallback',
        authMethod: 'email_link',
      );
      throw error;
    }

    try {
      await SupabaseService.auth.getSessionFromUrl(uri);
      _log('handleAuthCallback', 'Session established from auth callback');
      AuthenticationLogger.logSuccess(
        'email_verification_deep_link',
        stopwatch: sw,
        method: 'handleAuthCallback',
        authMethod: 'email_link',
      );
    } on AuthException catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_verification_deep_link',
        e,
        stopwatch: sw,
        method: 'handleAuthCallback',
        authMethod: 'email_link',
        stackTrace: stack,
      );
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

  static Future<void> resendSignupVerification(String email) =>
      ensureSignupVerificationSent(email);

  static Future<void> resendOtp({
    required String email,
    required OtpType type,
  }) =>
      _repo.resendEmailOtp(email: email, type: type);

  static Future<void> verifyOtpCode({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    await _emailOtp.verify(email: email, token: token, type: type);
    await _syncUserAfterOtpVerification();
  }

  static Future<User?> fetchFreshUser() => _repo.fetchFreshUser();

  static Future<void> _syncUserAfterOtpVerification() async {
    await _repo.fetchFreshUser();
    await SupabaseService.hardRefreshSession();
  }

  static String extractAuthErrorMessage(Object error) {
    if (error is AuthException) {
      return normalizeAuthErrorMessage(error.message);
    }
    return normalizeAuthErrorMessage(error.toString());
  }

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

  static String translateOtpError(Object error) {
    final message = extractAuthErrorMessage(error);
    final lower = message.toLowerCase();
    if (lower.contains('link') &&
        (lower.contains('invalid') || lower.contains('expired'))) {
      return lower.contains('expired') ? 'otp_expired'.tr : 'invalid_otp'.tr;
    }
    if (lower.contains('expired') ||
        lower.contains('has expired') ||
        lower.contains('otp_expired')) {
      return 'otp_expired'.tr;
    }
    if (lower.contains('otp_disabled') ||
        lower.contains('otp is disabled')) {
      return 'otp_channel_error'.tr;
    }
    if (lower.contains('sms send') ||
        lower.contains('sms_send_failed') ||
        lower.contains('twilio') ||
        lower.contains('unable to send sms')) {
      return 'otp_send_failed_sms'.tr;
    }
    if (lower.contains('unable to verify channel') ||
        lower.contains('channel') && lower.contains('unavailable')) {
      return 'otp_channel_error'.tr;
    }
    if (lower.contains('email already in use') ||
        lower.contains('a user with this email address')) {
      return 'email_already_in_use'.tr;
    }
    if (lower.contains('phone already in use') ||
        lower.contains('a user with this phone number')) {
      return 'phone_already_in_use'.tr;
    }
    if (lower.contains('invalid') ||
        lower.contains('otp') ||
        lower.contains('token') ||
        lower.contains('verification code') ||
        lower.contains('does not match')) {
      return 'invalid_otp'.tr;
    }
    if (lower.contains('rate limit') ||
        lower.contains('too many') ||
        lower.contains('over_') && lower.contains('_limit')) {
      return 'too_many_attempts'.tr;
    }
    if (isPhoneAccountNotFoundError(message)) {
      return 'auth_error_phone_not_registered'.tr;
    }
    return message;
  }

  static bool isPhoneAccountNotFoundError(Object error) {
    final message = extractAuthErrorMessage(error).toLowerCase();
    return message.contains('signups not allowed') && message.contains('otp');
  }

  static String translateAuthError(Object error) {
    final message = extractAuthErrorMessage(error);
    if (message.startsWith(_deletedAccountPrefix)) {
      final type = message.substring(_deletedAccountPrefix.length);
      return deletedAccountMessage(type);
    }
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
    if (lower.contains('same_password') ||
        lower.contains('different from the old password')) {
      return 'auth_error_same_password'.tr;
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
        lower.contains('535 5.7.8');
  }

  static String normalizeOtpDispatchError(String message) {
    final lower = message.toLowerCase();
    if (isEmailDeliveryFailure(message)) {
      return 'auth_error_email_delivery'.tr;
    }
    if (lower.contains('rate_limit') || lower.contains('rate limit')) {
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

  static Future<void> resendPasswordRecovery(String email) =>
      sendPasswordResetEmail(email);

  static Future<bool> refreshAndCheckEmailVerified() =>
      _repo.refreshAndCheckEmailVerified();

  static Future<void> sendPasswordResetEmail(String email) async {
    final sanitized = email.trim().toLowerCase();
    await guardAgainstDeletedAccount(
      email: sanitized,
      operation: 'password_reset_email',
    );
    try {
      await _repo.sendPasswordResetEmail(sanitized);
    } catch (e) {
      throw AuthException(normalizeOtpDispatchError(extractAuthErrorMessage(e)));
    }
  }

  static Future<void> sendPasswordResetOtpViaResend(String email) =>
      sendPasswordResetEmail(email);

  static Future<void> provisionSignupAndSendOtp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    await _repo.sendSignupEmailOtp(email.trim().toLowerCase());
  }

  static Future<void> reauthenticateWithPassword(String password) =>
      _repo.reauthenticateWithPassword(password);

  static Future<void> requestEmailChange(String newEmail) =>
      _repo.initiateEmailChange(newEmail);

  static Future<void> updatePassword(String newPassword) =>
      _repo.updatePassword(newPassword);

  static Future<void> refreshUserProfileState() =>
      _repo.refreshUserProfileState();

  static Future<bool> isPhoneAvailable(String phone) async {
    final sanitized = PhoneOtpService.to.toE164(phone.trim());
    if (!InputValidators.isValidE164Phone(sanitized)) return false;

    final sw = AuthenticationLogger.logStart(
      'phone_availability_check',
      method: 'isPhoneAvailable',
      authMethod: 'phone_otp',
      phone: sanitized,
    );
    try {
      final response = await SupabaseService.client.rpc(
        'fn_check_phone_available',
        params: {'p_phone': sanitized},
      );
      if (response is! Map) {
        throw AuthException('unexpected_error'.tr);
      }
      if (response['reason'] == 'deleted') {
        final deletionType = response['deletion_type']?.toString() ?? 'admin';
        throw deletedAccountException(deletionType);
      }
      final available = response['available'] == true;
      AuthenticationLogger.logSuccess(
        'phone_availability_check',
        stopwatch: sw,
        method: 'isPhoneAvailable',
        authMethod: 'phone_otp',
        phone: sanitized,
        params: {'available': available},
      );
      return available;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'phone_availability_check',
        e,
        stopwatch: sw,
        method: 'isPhoneAvailable',
        authMethod: 'phone_otp',
        phone: sanitized,
        stackTrace: stack,
      );
      if (e is AuthException) rethrow;
      throw AuthException('unexpected_error'.tr);
    }
  }

  static String deletedAccountTitle(String deletionType) {
    if (deletionType == 'admin') {
      return 'account_deleted_by_admin_title'.tr;
    }
    return 'account_self_deleted_title'.tr;
  }

  static String deletedAccountMessage(String deletionType) {
    if (deletionType == 'admin') {
      return 'account_deleted_by_admin_message'.tr;
    }
    return 'account_self_deleted_message'.tr;
  }

  static AuthException deletedAccountException(String deletionType) {
    return AuthException('$_deletedAccountPrefix$deletionType');
  }

  static Future<String?> resolveDeletedAccountType({
    String? email,
    String? phone,
  }) async {
    try {
      final response = await SupabaseService.client.rpc(
        'fn_check_deleted_account',
        params: {
          'p_email': email?.trim().toLowerCase(),
          'p_phone': phone?.trim(),
        },
      );
      if (response is Map && response['deleted'] == true) {
        return response['deletion_type']?.toString() ?? 'admin';
      }
    } catch (e, stack) {
      _log(
        'resolveDeletedAccountType',
        'Deleted account lookup failed',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
    return null;
  }

  static Future<void> guardAgainstDeletedAccount({
    String? email,
    String? phone,
    required String operation,
  }) async {
    final deletionType = await resolveDeletedAccountType(
      email: email,
      phone: phone,
    );
    if (deletionType == null) return;

    EnterpriseOperationsLogger.log(
      domain: 'authentication',
      operation: 'deleted_account_attempt',
      phase: 'BLOCKED',
      status: 'WARN',
      params: {
        'authOperation': operation,
        'deletionType': deletionType,
        'channel': email != null ? 'email' : 'phone',
      },
    );

    throw deletedAccountException(deletionType);
  }

  static Future<bool> accountExistsByEmail(String email) async {
    final sanitized = email.trim().toLowerCase();
    if (!InputValidators.isValidEmail(sanitized)) return false;

    final sw = AuthenticationLogger.logStart(
      'account_existence_check',
      method: 'accountExistsByEmail',
      authMethod: 'email',
      email: sanitized,
      params: {'channel': 'email'},
    );
    try {
      final response = await SupabaseService.client.rpc(
        'recover_account_by_email',
        params: {'p_email': sanitized},
      );
      if (response is Map && response['deleted'] == true) {
        final deletionType = response['deletion_type']?.toString() ?? 'admin';
        AuthenticationLogger.logSuccess(
          'account_existence_check',
          stopwatch: sw,
          method: 'accountExistsByEmail',
          authMethod: 'email',
          email: sanitized,
          params: {'exists': false, 'deleted': true, 'deletionType': deletionType},
        );
        throw deletedAccountException(deletionType);
      }
      final exists = response is Map && response['success'] == true;
      AuthenticationLogger.logSuccess(
        'account_existence_check',
        stopwatch: sw,
        method: 'accountExistsByEmail',
        authMethod: 'email',
        email: sanitized,
        params: {'exists': exists},
      );
      return exists;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'account_existence_check',
        e,
        stopwatch: sw,
        method: 'accountExistsByEmail',
        authMethod: 'email',
        email: sanitized,
        stackTrace: stack,
      );
      _log(
        'accountExistsByEmail',
        'Account lookup failed',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  static Future<bool> accountExistsByPhone(String phone) async {
    final sanitized = PhoneOtpService.to.toE164(phone.trim());
    if (!InputValidators.isValidE164Phone(sanitized)) return false;

    final sw = AuthenticationLogger.logStart(
      'account_existence_check',
      method: 'accountExistsByPhone',
      authMethod: 'phone_otp',
      phone: sanitized,
      params: {'channel': 'phone'},
    );
    try {
      final response = await SupabaseService.client.rpc(
        'recover_account_by_phone',
        params: {'p_phone': sanitized},
      );
      if (response is Map && response['deleted'] == true) {
        final deletionType = response['deletion_type']?.toString() ?? 'admin';
        AuthenticationLogger.logSuccess(
          'account_existence_check',
          stopwatch: sw,
          method: 'accountExistsByPhone',
          authMethod: 'phone_otp',
          phone: sanitized,
          params: {'exists': false, 'deleted': true, 'deletionType': deletionType},
        );
        throw deletedAccountException(deletionType);
      }
      final exists = response is Map && response['success'] == true;
      AuthenticationLogger.logSuccess(
        'account_existence_check',
        stopwatch: sw,
        method: 'accountExistsByPhone',
        authMethod: 'phone_otp',
        phone: sanitized,
        params: {'exists': exists},
      );
      return exists;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'account_existence_check',
        e,
        stopwatch: sw,
        method: 'accountExistsByPhone',
        authMethod: 'phone_otp',
        phone: sanitized,
        stackTrace: stack,
      );
      _log(
        'accountExistsByPhone',
        'Account lookup failed',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  static Future<bool> isEmailAvailable(String email) async {
    final sanitized = email.trim().toLowerCase();
    if (!InputValidators.isValidEmail(sanitized)) return false;

    final sw = AuthenticationLogger.logStart(
      'email_availability_check',
      method: 'isEmailAvailable',
      authMethod: 'email',
      email: sanitized,
    );
    try {
      final response = await SupabaseService.client.rpc(
        'fn_check_email_available',
        params: {'p_email': sanitized},
      );
      if (response is! Map) {
        throw AuthException('unexpected_error'.tr);
      }
      if (response['reason'] == 'deleted') {
        final deletionType = response['deletion_type']?.toString() ?? 'admin';
        throw deletedAccountException(deletionType);
      }
      final available = response['available'] == true;
      AuthenticationLogger.logSuccess(
        'email_availability_check',
        stopwatch: sw,
        method: 'isEmailAvailable',
        authMethod: 'email',
        email: sanitized,
        params: {'available': available},
      );
      return available;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_availability_check',
        e,
        stopwatch: sw,
        method: 'isEmailAvailable',
        authMethod: 'email',
        email: sanitized,
        stackTrace: stack,
      );
      if (e is AuthException) rethrow;
      throw AuthException('unexpected_error'.tr);
    }
  }

  static Future<bool> ensureUserProfile() => _repo.ensureUserProfile();

  static Future<bool> isPendingEmailChangeComplete(String targetEmail) =>
      _repo.isPendingEmailChangeComplete(targetEmail);

  static bool canPollVerificationStatus({required String purpose}) {
    return SupabaseService.auth.currentSession?.refreshToken != null &&
        SupabaseService.auth.currentSession!.refreshToken!.isNotEmpty;
  }

  static Future<void> ensureSignupVerificationSent(String email) async {
    try {
      await _repo.sendSignupEmailOtp(email.trim().toLowerCase());
    } catch (e, stack) {
      _log(
        'ensureSignupVerificationSent',
        'Signup OTP dispatch failed',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      throw AuthException(normalizeOtpDispatchError(extractAuthErrorMessage(e)));
    }
  }

  static Future<void> confirmSignupEmailOtp({
    required String email,
    required String code,
  }) async {
    try {
      await _repo.verifySignupEmailOtp(email: email, code: code);
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
  }

  static Future<void> signInAfterSignup({
    required String email,
    required String password,
  }) =>
      _repo.signInAfterSignup(email: email, password: password);

  static Future<void> ensurePhoneVerificationSent({
    required String phone,
    String purpose = 'verification',
  }) async {
    try {
      await _repo.sendPhoneVerificationOtp(phone);
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
  }

  static Future<void> sendProfileChangeOtp({
    required String target,
    required String targetType,
    required String purpose,
  }) async {
    try {
      if (targetType == 'email') {
        await _repo.initiateEmailChange(target.trim().toLowerCase());
      } else {
        await _repo.initiatePhoneChange(target.trim());
      }
    } catch (e) {
      throw AuthException(
        targetType == 'email'
            ? normalizeOtpDispatchError(extractAuthErrorMessage(e))
            : translateOtpError(e),
      );
    }
  }

  static Future<AuthResponse> signUpWithEmailVerification({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) =>
      _repo.register(email: email, password: password, metadata: data);

  static Future<bool> completeRegistrationSession({
    required String email,
    required String password,
  }) async {
    if (SupabaseService.auth.currentSession != null) return true;
    try {
      await signInAfterSignup(email: email, password: password);
      return SupabaseService.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  static int get phoneOtpLength => _repo.phoneOtpLength;

  static String? getUserPhone() => _repo.getUserPhone();

  static bool isPhoneVerificationRequired(User? user) =>
      _repo.isPhoneVerificationRequired(user);

  static bool isIdentityVerificationRequired(User? user) {
    if (user == null) return false;
    if (isEmailVerificationRequired(user)) return true;
    if (isPhoneVerificationRequired(user)) return true;
    return false;
  }

  static Future<void> sendPhoneOtp({
    required String phone,
    bool shouldCreateUser = false,
    Map<String, dynamic>? data,
    String purpose = 'signup',
  }) async {
    if (shouldCreateUser || purpose == 'signup') {
      await guardAgainstDeletedAccount(
        phone: phone,
        operation: 'phone_otp_signup',
      );
    }
    try {
      if (purpose == 'phone_change') {
        await _repo.initiatePhoneChange(phone);
      } else {
        await _phoneOtp.sendOtp(
          phone: phone,
          shouldCreateUser: shouldCreateUser,
          data: data,
        );
      }
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
  }

  static Future<void> resendPhoneOtp({
    required String phone,
    OtpType type = OtpType.sms,
    String purpose = 'verification',
  }) async {
    try {
      await _repo.resendPhoneOtp(phone: phone, type: type);
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
  }

  static Future<AuthResponse> verifyPhoneOtpCode({
    required String phone,
    required String token,
    OtpType type = OtpType.sms,
    String purpose = 'verification',
    String? newValue,
  }) async {
    try {
      if (type == OtpType.phoneChange) {
        await _repo.confirmPhoneChange(newPhone: phone, code: token);
      } else {
        await _repo.verifyPhoneOtp(phone: phone, code: token, type: type);
      }
    } catch (e) {
      throw AuthException(translateOtpError(e));
    }
    await _syncUserAfterOtpVerification();
    return AuthResponse(
      session: SupabaseService.auth.currentSession,
      user: SupabaseService.auth.currentUser,
    );
  }

  static Future<void> requestPhoneChange(String newPhone) =>
      _repo.initiatePhoneChange(newPhone);

  static Future<void> confirmPhoneChange({
    required String phone,
    required String token,
  }) async {
    await _repo.confirmPhoneChange(newPhone: phone, code: token);
  }

  static Future<void> requestStepUpOtp() async {
    final phone = getUserPhone();
    if (phone == null || phone.isEmpty) {
      throw AuthException('phone_verification_required'.tr);
    }
    await _repo.sendStepUpOtp(phone);
    if (Get.isRegistered<SensitiveOperationGuardService>()) {
      Get.find<SensitiveOperationGuardService>().nativeStepUpOtp = true;
    }
  }

  static Future<void> verifyStepUpOtp({
    required String token,
    String? phone,
  }) async {
    final targetPhone = phone ?? getUserPhone();
    if (targetPhone == null || targetPhone.isEmpty) {
      throw AuthException('phone_verification_required'.tr);
    }
    await _repo.verifyStepUpOtp(phone: targetPhone, code: token);
    if (Get.isRegistered<SensitiveOperationGuardService>()) {
      Get.find<SensitiveOperationGuardService>().nativeStepUpOtp = false;
    }
  }

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

  static String normalizePhone(String phone) {
    var normalized = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  static Future<String?> lookupEmailByPhone(String phone) =>
      _repo.lookupEmailByPhone(phone);

  static Future<void> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    if (LoginIdentifierUtils.isEmail(trimmed)) {
      await guardAgainstDeletedAccount(
        email: trimmed.toLowerCase(),
        operation: 'login',
      );
    } else {
      await guardAgainstDeletedAccount(
        phone: PhoneOtpService.to.toE164(trimmed),
        operation: 'login',
      );
    }
    await _repo.signIn(identifier: identifier, password: password);
  }
}
