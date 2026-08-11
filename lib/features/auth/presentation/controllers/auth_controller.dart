import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/utils/country_data.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/auth/domain/models/country_model.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/domain/utils/login_identifier_utils.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/deep_link_service.dart';
import 'package:kasby/core/services/enterprise_operations_logger.dart';
import 'package:kasby/core/services/tour_service.dart';
import 'package:kasby/core/services/sensitive_operation_guard.dart';
import 'package:kasby/core/services/crash_reporting/crash_breadcrumb.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/services/security_activity_service.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/routes/app_routes.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthController extends GetxController {
  static AuthController get to => Get.find();
  final _storage = const FlutterSecureStorage();
  final String _logTag = '[AUTH]';

  void _log(
    String message, {
    bool isError = false,
    dynamic error,
    StackTrace? stack,
  }) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 8);
    final prefix = isError ? '❌ ERROR' : 'ℹ️ INFO';
    debugPrint('$timestamp $_logTag $prefix: $message');
    if (error != null) debugPrint('$timestamp $_logTag 🔴 Details: $error');
    if (stack != null) debugPrint('$timestamp $_logTag 📂 StackTrace: $stack');

    // Sync critical errors to system_logs
    if (isError) {
      SupabaseService.logActivity(
        action: 'AUTH_ERROR',
        details: '$message: ${error ?? ""}',
        severity: 'critical',
      );
      if (error != null) {
        unawaited(
          CrashReportingService.recordAuthError(
            error,
            stack: stack,
            expectedFailure: error is AuthException,
          ),
        );
      }
    }
  }

  /// Current user's role from profile (Primary) or metadata (Fallback).
  String get userRole {
    if (Get.isRegistered<HomeController>()) {
      final roleFromProfile = HomeController.to.profile.value?.role;
      if (roleFromProfile != null) return roleFromProfile;
    }
    return SupabaseService.currentUser?.appMetadata['role'] as String? ??
        'user';
  }

  bool get isLoggedIn => authStatus.value == AuthStatus.authenticated;

  /// True while user is resetting password (not a normal authenticated session).
  bool get _isPasswordRecoveryFlow {
    final route = Get.currentRoute;
    if (route == Routes.forgotPassword || route == Routes.changePassword) {
      return true;
    }
    if (route == Routes.otp) {
      final args = Get.arguments;
      return args is Map && args['isRecovery'] == true;
    }
    return false;
  }

  // Observable state
  final Rx<Country> selectedCountry = CountryData.defaultCountry.obs;
  final RxBool rememberMe = false.obs;
  final RxBool termsAccepted = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isVerified = false.obs;
  final Rx<AuthStatus> authStatus = AuthStatus.initial.obs;
  final RxnString profileImagePath = RxnString();
  final RxnBool referralCodeValid =
      RxnBool(); // null = initial, true = valid, false = invalid
  final RxBool isCheckingReferral = false.obs;
  final RxnString pendingVerificationEmail = RxnString();
  final RxnString pendingVerificationPhone = RxnString();

  StreamSubscription<AuthState>? _authSubscription;

  // Text Controllers
  final loginIdentifierController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final referralCodeController = TextEditingController();

  /// E.164 phone captured from the registration international phone field.
  final RxString registerPhoneE164 = ''.obs;
  final RxString registerCountryCode = 'YE'.obs;

  // Keys
  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();

  @override
  void onInit() {
    _log('Initializing AuthController');
    super.onInit();
    _loadSavedCredentials();
    _loadPendingReferralCode();
    _checkInitialSession();
    _listenToAuthChanges();
    _linkVerificationStatus();
    _setupReferralListener();
  }

  void _setupReferralListener() {
    referralCodeController.addListener(() {
      final rawText = referralCodeController.text;
      final code = ReferralService.normalizeCode(rawText);

      _log(
        'Referral code input changed: raw=${rawText.length} chars, normalized=$code (${code.length} chars)',
      );

      if (code.isEmpty) {
        referralCodeValid.value = null;
        _referralDebounceTimer?.cancel();
        return;
      }

      _debounceReferralCheck(code);
    });
  }

  Timer? _referralDebounceTimer;

  void _debounceReferralCheck(String code) {
    _referralDebounceTimer?.cancel();
    _referralDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      checkReferralCode(code);
    });
  }

  Future<void> checkReferralCode(String code) async {
    // Code is already normalized when passed from listener
    if (code.isEmpty) {
      referralCodeValid.value = null;
      return;
    }

    if (!ReferralService.isValidFormat(code)) {
      _log('Referral code format invalid: $code');
      referralCodeValid.value = false;
      return;
    }

    try {
      isCheckingReferral.value = true;
      _log('Checking referral code: $code');

      final lookup = await ReferralService.validateReferralCode(code);
      referralCodeValid.value = lookup != null;
      _log(
        'Referral code $code validity: ${referralCodeValid.value}, referrerId: ${lookup?.referrerId}',
      );
    } catch (e) {
      _log('Error checking referral code', isError: true, error: e);
      referralCodeValid.value = false;
    } finally {
      isCheckingReferral.value = false;
    }
  }

  void _linkVerificationStatus() {
    if (Get.isRegistered<HomeController>()) {
      syncVerificationFromProfile(HomeController.to.profile.value);
      ever(HomeController.to.profile, (profile) {
        syncVerificationFromProfile(profile);
      });
    } else {
      _log(
        'HomeController not registered yet, skipping verification link',
        isError: true,
      );
    }
  }

  /// Keeps [isVerified] aligned with the live profile KYC state.
  void syncVerificationFromProfile(ProfileModel? profile) {
    final verified = profile?.kycStatus == 'verified';
    if (isVerified.value != verified) {
      isVerified.value = verified;
      _log('isVerified updated: ${isVerified.value}');
    }
  }

  /// Check current session status on startup
  Future<void> _checkInitialSession() async {
    try {
      final session = SupabaseService.auth.currentSession;
      if (session != null) {
        _log('Initial session found for user: ${session.user.id}');
        if (!AuthOtpConfig.tempSkipEmailVerification &&
            _requiresEmailVerification(session.user)) {
          pendingVerificationEmail.value = session.user.email;
          authStatus.value = AuthStatus.unauthenticated;
        } else if (_requiresPhoneVerification(session.user)) {
          pendingVerificationPhone.value = AuthSecurityService.getUserPhone();
          authStatus.value = AuthStatus.unauthenticated;
        } else {
          authStatus.value = AuthStatus.authenticated;
          if (Get.isRegistered<HomeController>()) {
            HomeController.to.fetchAll();
          }
          await TourService.disableAutoToursForExistingUser();
        }
      } else {
        _log('No initial session found');
        authStatus.value = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _log('Error checking initial session', isError: true, error: e);
      authStatus.value = AuthStatus.unauthenticated;
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _referralDebounceTimer?.cancel();
    loginIdentifierController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nameController.dispose();
    emailController.dispose();
    referralCodeController.dispose();

    super.onClose();
  }

  /// Listen to Supabase auth state changes for session management.
  void _listenToAuthChanges() {
    _authSubscription = SupabaseService.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      _log('Auth State Changed: ${event.name}');

      switch (event) {
        case AuthChangeEvent.signedIn:
          _log('User signed in: ${session?.user.id}');
          debugPrint(
            '[PROFIT_FCM] AUTH SIGNED IN -> user_id: ${session?.user.id} | token_present: ${Get.isRegistered<FCMService>() && FCMService.to.fcmToken.value.isNotEmpty}',
          );
          if (!AuthOtpConfig.tempSkipEmailVerification &&
              session != null &&
              _requiresEmailVerification(session.user)) {
            pendingVerificationEmail.value = session.user.email;
            authStatus.value = AuthStatus.unauthenticated;
            if (Get.currentRoute != Routes.verifyEmail) {
              Get.offAllNamed(
                Routes.verifyEmail,
                arguments: {'email': session.user.email ?? ''},
              );
            }
            break;
          }
          if (session != null && _requiresPhoneVerification(session.user)) {
            final phone = AuthSecurityService.getUserPhone();
            pendingVerificationPhone.value = phone;
            authStatus.value = AuthStatus.unauthenticated;
            if (Get.currentRoute != Routes.otp && phone != null) {
              unawaited(
                _goToPhoneVerification(phone, purpose: 'phone_confirm'),
              );
            }
            break;
          }

          authStatus.value = AuthStatus.authenticated;
          pendingVerificationEmail.value = null;
          pendingVerificationPhone.value = null;

          if (Get.isRegistered<FCMService>()) {
            unawaited(FCMService.to.syncCurrentToken());
          }

          unawaited(CrashReportingService.log(CrashBreadcrumb.loginCompleted));
          if (Get.isRegistered<HomeController>()) {
            HomeController.to.fetchAll();
            HomeController.to.reconnectStreams();
          }
          if (Get.isRegistered<CurrencyController>()) {
            CurrencyController.to.fetchWalletBalances();
          }

          unawaited(CrashReportingService.syncUserContextFromProfile());
          if (!TourService.isNewUserTourSetupInProgress) {
            final route = Get.currentRoute;
            final isSignupFlow =
                route == Routes.register ||
                route == Routes.verifyEmail ||
                route == Routes.otp;
            if (!isSignupFlow) {
              unawaited(TourService.disableAutoToursForExistingUser());
            }
          }

          if (!TourService.isNewUserTourSetupInProgress) {
            final route = Get.currentRoute;
            final isSignupFlow =
                route == Routes.register ||
                route == Routes.verifyEmail ||
                route == Routes.otp;
            if (!isSignupFlow) {
              _navigateAfterAuthentication();
            }
          }
          break;

        case AuthChangeEvent.signedOut:
          _log('User signed out');
          if (Get.isRegistered<FCMService>()) {
            unawaited(FCMService.to.clearTokenOnLogout());
          }
          unawaited(CrashReportingService.log(CrashBreadcrumb.logout));
          unawaited(CrashReportingService.clearUser());
          authStatus.value = AuthStatus.unauthenticated;
          SensitiveOperationGuard.clearStepUp();

          // Clear data
          if (Get.isRegistered<HomeController>()) {
            HomeController.to.clearData();
          }
          if (Get.isRegistered<CurrencyController>()) {
            CurrencyController.to.resetBalances();
          }

          // Centralized navigation — skip if already on login (logout() triggers signOut)
          if (Get.currentRoute != Routes.login) {
            Get.offAllNamed(Routes.login);
          }
          break;

        case AuthChangeEvent.tokenRefreshed:
          _log('Token refreshed');
          if (!_isPasswordRecoveryFlow && Get.isRegistered<HomeController>()) {
            HomeController.to.reconnectStreams();
          }
          break;

        case AuthChangeEvent.passwordRecovery:
          _log('Password recovery mode');
          if (Get.currentRoute != Routes.changePassword) {
            Get.toNamed(
              Routes.changePassword,
              arguments: {'isRecovery': true, 'otpVerified': true},
            );
          }
          break;

        case AuthChangeEvent.userUpdated:
          _log('User updated');
          if (!_isPasswordRecoveryFlow) {
            AuthSecurityService.refreshUserProfileState();
          }
          break;

        case AuthChangeEvent.mfaChallengeVerified:
          _log('MFA Challenge Verified');
          break;

        default:
          _log('Unhandled auth event: ${event.name}');
      }
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedLoginId = await _storage.read(key: 'saved_login_id');
      await _storage.delete(key: 'saved_password');

      if (savedLoginId != null) {
        loginIdentifierController.text = savedLoginId;
        rememberMe.value = true;
      }
    } catch (e, stack) {
      _log('Error loading credentials', isError: true, error: e, stack: stack);
    }
  }

  Future<void> _loadPendingReferralCode() async {
    final code = await DeepLinkService.getPendingReferralCode();
    if (code != null && code.isNotEmpty) {
      final normalized = ReferralService.normalizeCode(code);
      referralCodeController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      await checkReferralCode(normalized);
    }
  }

  bool _requiresEmailVerification(User user) {
    return AuthSecurityService.isEmailVerificationRequired(user);
  }

  bool _requiresPhoneVerification(User user) {
    return AuthSecurityService.isPhoneVerificationRequired(user);
  }

  Future<void> _goToPhoneVerification(
    String phone, {
    String purpose = 'login',
    bool isRecovery = false,
  }) async {
    pendingVerificationPhone.value = phone;

    try {
      await AuthSecurityService.ensurePhoneVerificationSent(
        phone: phone,
        purpose: purpose == 'phone_confirm' ? 'verification' : purpose,
      );
    } on AuthException catch (e, stack) {
      _log(
        'Failed to send phone verification OTP',
        isError: true,
        error: e.message,
        stack: stack,
      );
      AppSnack.error('error'.tr, translateOtpError(e));
      return;
    }

    AppSnack.success('success'.tr, 'otp_sent_success'.tr);
    Get.toNamed(
      Routes.otp,
      arguments: {
        'identifier': phone,
        'isPhone': true,
        'isFreeOtp': true,
        'purpose': purpose,
        'isRecovery': isRecovery,
        'otpLength': AuthOtpConfig.unifiedOtpLength,
      },
    );
  }

  void _navigateAfterAuthentication() {
    const skipRoutes = {
      Routes.home,
      Routes.profileUpdate,
      Routes.editProfile,
      Routes.personalProfile,
      Routes.changePassword,
      Routes.verifyEmail,
      Routes.securityCenter,
    };
    if (!skipRoutes.contains(Get.currentRoute)) {
      Get.offAllNamed(Routes.home);
    }
  }

  Future<void> resendVerificationEmail(
    String email, {
    String purpose = 'signup',
  }) async {
    final sw = AuthenticationLogger.logStart(
      'email_verification_resend',
      method: 'resendVerificationEmail',
      authMethod: 'email_otp',
      email: email,
      params: {'purpose': purpose},
    );
    try {
      _log('Resending verification ($purpose)');
      if (purpose == 'signup') {
        await AuthSecurityService.ensureSignupVerificationSent(email);
      } else if (purpose == 'email_change') {
        await AuthSecurityService.sendProfileChangeOtp(
          target: email,
          targetType: 'email',
          purpose: 'email_change',
        );
      }
      AuthenticationLogger.logSuccess(
        'email_verification_resend',
        stopwatch: sw,
        method: 'resendVerificationEmail',
        authMethod: 'email_otp',
        email: email,
        params: {'purpose': purpose},
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_verification_resend',
        e,
        stopwatch: sw,
        method: 'resendVerificationEmail',
        authMethod: 'email_otp',
        email: email,
        stackTrace: stack,
        params: {'purpose': purpose},
      );
      rethrow;
    }
  }

  Future<bool> checkEmailVerificationStatus({
    String purpose = 'signup',
    String? targetEmail,
  }) async {
    final sw = AuthenticationLogger.logStart(
      'email_verification_check',
      method: 'checkEmailVerificationStatus',
      authMethod: 'email_otp',
      email: targetEmail ?? pendingVerificationEmail.value,
      params: {'purpose': purpose},
    );
    try {
      _log('Checking email verification status ($purpose)');
      if (purpose == 'email_change') {
        final target = targetEmail ?? pendingVerificationEmail.value ?? '';
        if (target.isEmpty) return false;
        final complete = await AuthSecurityService.isPendingEmailChangeComplete(
          target,
        );
        if (complete) {
          await AuthSecurityService.refreshUserProfileState();
        }
        AuthenticationLogger.logSuccess(
          'email_verification_check',
          stopwatch: sw,
          method: 'checkEmailVerificationStatus',
          authMethod: 'email_otp',
          email: target,
          params: {'purpose': purpose, 'verified': complete},
        );
        return complete;
      }
      final verified = await AuthSecurityService.refreshAndCheckEmailVerified();
      if (verified) {
        authStatus.value = AuthStatus.authenticated;
        pendingVerificationEmail.value = null;
        await AuthSecurityService.refreshUserProfileState();
      }
      AuthenticationLogger.logSuccess(
        'email_verification_check',
        stopwatch: sw,
        method: 'checkEmailVerificationStatus',
        authMethod: 'email_otp',
        email: targetEmail ?? pendingVerificationEmail.value,
        params: {'purpose': purpose, 'verified': verified},
      );
      return verified;
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_verification_check',
        e,
        stopwatch: sw,
        method: 'checkEmailVerificationStatus',
        authMethod: 'email_otp',
        email: targetEmail ?? pendingVerificationEmail.value,
        stackTrace: stack,
        params: {'purpose': purpose},
      );
      rethrow;
    }
  }

  /// Called after Supabase auth deep link establishes a session.
  Future<void> handleEmailVerificationDeepLink() async {
    final sw = AuthenticationLogger.logStart(
      'email_verification_deep_link',
      method: 'handleEmailVerificationDeepLink',
      authMethod: 'email_link',
    );
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        AuthenticationLogger.logFailure(
          'email_verification_deep_link',
          AuthException('auth_link_invalid'.tr),
          stopwatch: sw,
          method: 'handleEmailVerificationDeepLink',
          authMethod: 'email_link',
        );
        return;
      }

      final verified = await AuthSecurityService.refreshAndCheckEmailVerified();
      if (!verified) {
        _goToVerifyEmail(user.email ?? '');
        AuthenticationLogger.logSuccess(
          'email_verification_deep_link',
          stopwatch: sw,
          method: 'handleEmailVerificationDeepLink',
          authMethod: 'email_link',
          email: user.email,
          params: {'verified': false},
        );
        return;
      }

      authStatus.value = AuthStatus.authenticated;
      pendingVerificationEmail.value = null;
      await AuthSecurityService.refreshUserProfileState();
      unawaited(
        SecurityActivityService.to.logEvent(SecurityEventType.emailVerified),
      );

      AuthenticationLogger.logSuccess(
        'email_verification_deep_link',
        stopwatch: sw,
        method: 'handleEmailVerificationDeepLink',
        authMethod: 'email_link',
        email: user.email,
        params: {'verified': true},
      );

      const authRoutes = {
        Routes.verifyEmail,
        Routes.login,
        Routes.register,
        Routes.splash,
      };
      if (authRoutes.contains(Get.currentRoute)) {
        await _navigateHomeLaunchingTourIfNeeded(afterSignup: true);
      }
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_verification_deep_link',
        e,
        stopwatch: sw,
        method: 'handleEmailVerificationDeepLink',
        authMethod: 'email_link',
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> verifyEmailWithOtp({
    required String email,
    required String code,
    String purpose = 'signup',
    String? signupPassword,
    bool navigateOnSuccess = true,
  }) async {
    final sw = AuthenticationLogger.logStart(
      'email_verification_complete',
      method: 'verifyEmailWithOtp',
      authMethod: 'email_otp',
      email: email,
      params: {'purpose': purpose},
    );
    isLoading.value = true;
    try {
      _log('Verifying email OTP ($purpose)');
      if (purpose == 'email_change') {
        await OTPService.to.verifyEmailOtp(
          email: email,
          code: code,
          purpose: 'email_change',
          newValue: email,
        );
        await AuthSecurityService.refreshUserProfileState();
        pendingVerificationEmail.value = null;
        AuthenticationLogger.logSuccess(
          'email_verification_complete',
          stopwatch: sw,
          method: 'verifyEmailWithOtp',
          authMethod: 'email_otp',
          email: email,
          params: {'purpose': purpose},
        );
        if (navigateOnSuccess) {
          AppSnack.success('success'.tr, 'email_changed_success'.tr);
          Get.offAllNamed(Routes.personalProfile);
        }
        return;
      }

      await AuthSecurityService.confirmSignupEmailOtp(email: email, code: code);

      if (SupabaseService.auth.currentSession == null) {
        final password = signupPassword ?? passwordController.text;
        if (password.trim().isEmpty) {
          throw AuthException('enter_current_password'.tr);
        }
        await AuthSecurityService.signInAfterSignup(
          email: email,
          password: password,
        );
      }

      authStatus.value = AuthStatus.authenticated;
      pendingVerificationEmail.value = null;
      await AuthSecurityService.refreshUserProfileState();
      unawaited(
        SecurityActivityService.to.logEvent(SecurityEventType.registration),
      );
      AuthenticationLogger.logSuccess(
        'email_verification_complete',
        stopwatch: sw,
        method: 'verifyEmailWithOtp',
        authMethod: 'email_otp',
        email: email,
        params: {'purpose': purpose},
      );
      if (navigateOnSuccess) {
        AppSnack.success('success'.tr, 'email_verified_success'.tr);
        await _navigateHomeLaunchingTourIfNeeded(afterSignup: true);
      }
    } on AuthException catch (e, stack) {
      AuthenticationLogger.logFailure(
        'email_verification_complete',
        e,
        stopwatch: sw,
        method: 'verifyEmailWithOtp',
        authMethod: 'email_otp',
        email: email,
        stackTrace: stack,
        params: {'purpose': purpose},
      );
      _log(
        'Email OTP verification failed',
        isError: true,
        error: e.message,
        stack: stack,
      );
      throw AuthException(AuthSecurityService.translateOtpError(e));
    } finally {
      isLoading.value = false;
    }
  }

  String translateAuthError(Object error) =>
      AuthSecurityService.translateAuthError(error);

  void _showAuthFailureSnack(Object error) {
    final message = extractAuthErrorMessage(error);
    if (message.startsWith('DELETED_ACCOUNT:')) {
      final type = message.substring('DELETED_ACCOUNT:'.length);
      AppSnack.error(
        AuthSecurityService.deletedAccountTitle(type),
        AuthSecurityService.deletedAccountMessage(type),
      );
      return;
    }
    AppSnack.error('error'.tr, translateAuthError(error));
  }

  String extractAuthErrorMessage(Object error) =>
      AuthSecurityService.extractAuthErrorMessage(error);

  String translateOtpError(Object error) =>
      AuthSecurityService.translateOtpError(error);

  void _goToVerifyEmail(
    String email, {
    String purpose = 'signup',
    String? password,
  }) {
    pendingVerificationEmail.value = email;
    if (AuthOtpConfig.tempSkipEmailVerification && purpose == 'signup') {
      return;
    }
    Get.offAllNamed(
      Routes.verifyEmail,
      arguments: {
        'email': email,
        'purpose': purpose,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
  }

  void updateCountry(Country country) {
    selectedCountry.value = country;
  }

  void toggleRememberMe(bool? value) {
    rememberMe.value = value ?? false;
  }

  void toggleTerms(bool? value) {
    termsAccepted.value = value ?? false;
  }

  /// Navigate home and launch onboarding for brand-new registrations only.
  Future<void> _navigateHomeLaunchingTourIfNeeded({
    required bool afterSignup,
  }) async {
    if (afterSignup) {
      TourService.beginNewUserTourSetup();
      try {
        await TourService.enableAutoToursForNewUser();
        Get.offAllNamed(Routes.home);
        TourService.markPendingAutoHomeTour();
        EnterpriseOperationsLogger.log(
          domain: 'tutorial',
          operation: 'post_signup_navigation',
          phase: 'COMPLETE',
          userId: SupabaseService.userId,
        );
      } finally {
        TourService.endNewUserTourSetup();
      }
      return;
    }
    Get.offAllNamed(Routes.home);
  }

  /// Completes signup session and navigates to home (interactive tour on first visit).
  Future<bool> _finalizeRegistrationAndNavigateHome({
    required String email,
    required String password,
    AuthResponse? signupResponse,
  }) async {
    TourService.beginNewUserTourSetup();
    try {
      if (signupResponse?.session == null) {
        final signedIn = await AuthSecurityService.completeRegistrationSession(
          email: email,
          password: password,
        );
        if (!signedIn) return false;
      }

      if (SupabaseService.auth.currentSession == null) return false;

      authStatus.value = AuthStatus.authenticated;
      pendingVerificationEmail.value = null;
      await AuthSecurityService.refreshUserProfileState();
      await TourService.enableAutoToursForNewUser();
      Get.offAllNamed(Routes.home);
      TourService.markPendingAutoHomeTour();
      EnterpriseOperationsLogger.log(
        domain: 'tutorial',
        operation: 'finalize_registration_navigation',
        phase: 'COMPLETE',
        userId: SupabaseService.userId,
      );
      return true;
    } finally {
      TourService.endNewUserTourSetup();
    }
  }

  Future<void> login({bool skipFormValidation = false}) async {
    if (!skipFormValidation && !loginFormKey.currentState!.validate()) return;

    final loginId = loginIdentifierController.text.trim();
    if (loginId.isEmpty) {
      AppSnack.error('error'.tr, 'email_or_phone'.tr);
      return;
    }

    isLoading.value = true;
    unawaited(CrashReportingService.log(CrashBreadcrumb.loginStarted));
    final password = passwordController.text;

    try {
      _log(
        '🔑 Login attempt via ${LoginIdentifierUtils.isEmail(loginId) ? 'EMAIL' : 'PHONE'}: $loginId',
      );
      await AuthSecurityService.signInWithIdentifier(
        identifier: loginId,
        password: password,
      );

      final user = SupabaseService.currentUser;
      if (kDebugMode && user != null) {
        SafeGetx.debugTrace(
          className: 'AuthController',
          method: 'login',
          feature: 'Auth',
          status: 'SUCCESS',
          params: {'userId': user.id},
        );
      }

      if (rememberMe.value) {
        await _storage.write(key: 'saved_login_id', value: loginId);
      } else {
        await _storage.delete(key: 'saved_login_id');
      }
      await _storage.delete(key: 'saved_password');

      isLoading.value = false;
      _log('Login successful for: $loginId');
      unawaited(SecurityActivityService.to.logEvent(SecurityEventType.login));
      unawaited(SecurityActivityService.to.registerCurrentDevice());

      if (!AuthOtpConfig.tempSkipEmailVerification &&
          user != null &&
          _requiresEmailVerification(user)) {
        AppSnack.warning('verify_email'.tr, 'email_not_verified_login'.tr);
        _goToVerifyEmail(user.email ?? loginId, password: password);
      } else if (user != null && _requiresPhoneVerification(user)) {
        final phone =
            AuthSecurityService.getUserPhone() ??
            (LoginIdentifierUtils.isEmail(loginId)
                ? null
                : LoginIdentifierUtils.toE164(loginId));
        if (phone != null) {
          await _goToPhoneVerification(phone, purpose: 'phone_confirm');
        }
      }
    } on AuthException catch (e, stack) {
      isLoading.value = false;
      unawaited(
        SecurityActivityService.to.logEvent(
          SecurityEventType.failedLogin,
          status: 'failed',
          details: e.message,
        ),
      );
      _log(
        'Login failed (AuthException)',
        isError: true,
        error: e.message,
        stack: stack,
      );
      if (!AuthOtpConfig.tempSkipEmailVerification &&
          e.message.contains('Email not confirmed') &&
          LoginIdentifierUtils.isEmail(loginId)) {
        AppSnack.warning('verify_email'.tr, 'email_not_verified_login'.tr);
        _goToVerifyEmail(loginId, password: password);
        return;
      }
      _showAuthFailureSnack(e);
    } catch (e, stack) {
      isLoading.value = false;
      _log('Login failed (Unexpected)', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
    }
  }

  Future<void> register({bool skipFormValidation = false}) async {
    if (!skipFormValidation && !registerFormKey.currentState!.validate()) {
      return;
    }
    if (!termsAccepted.value) {
      AppSnack.error('error'.tr, 'agree_error'.tr);
      return;
    }

    isLoading.value = true;

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;
      final emailAvailable = await AuthSecurityService.isEmailAvailable(email);
      if (!emailAvailable) {
        isLoading.value = false;
        AppSnack.error('error'.tr, 'auth_error_user_exists'.tr);
        return;
      }
      final fullName = nameController.text.trim();
      final phone = registerPhoneE164.value.trim();
      if (phone.isEmpty) {
        isLoading.value = false;
        AppSnack.error('error'.tr, 'invalid_phone'.tr);
        return;
      }
      final phoneAvailable = await AuthSecurityService.isPhoneAvailable(phone);
      if (!phoneAvailable) {
        isLoading.value = false;
        AppSnack.error('error'.tr, 'phone_already_used'.tr);
        return;
      }
      final referralCodeInput = ReferralService.normalizeCode(
        referralCodeController.text,
      );

      _log(
        'Registering with referral code: ${referralCodeInput.isNotEmpty ? referralCodeInput : "none"}',
      );

      // Validate referral code if provided
      ReferralCodeLookup? referralLookup;
      if (referralCodeInput.isNotEmpty) {
        referralLookup = await ReferralService.validateReferralCode(
          referralCodeInput,
        );
        if (referralLookup == null) {
          _log(
            'Referral code validation failed during registration: $referralCodeInput',
          );
          isLoading.value = false;
          AppSnack.error('error'.tr, 'invalid_referral_code'.tr);
          return;
        }
        _log(
          'Referral code validated successfully during registration, referrerId: ${referralLookup.referrerId}',
        );
      }

      SafeGetx.debugTrace(
        className: 'AuthController',
        method: 'register',
        feature: 'Auth',
        status: 'INFO',
        params: {
          'hasReferral': referralCodeInput.isNotEmpty,
          'countryCode': registerCountryCode.value,
        },
      );

      final response = await AuthSecurityService.signUpWithEmailVerification(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'country_code': registerCountryCode.value,
          if (referralLookup != null)
            'referred_by_code': referralLookup.canonicalCode,
        },
      );

      if (kDebugMode && response.user != null) {
        SafeGetx.debugTrace(
          className: 'AuthController',
          method: 'register',
          feature: 'Auth',
          status: 'SUCCESS',
          params: {
            'userId': response.user!.id,
            'hasSession': response.session != null,
          },
        );
      }

      // Referral is linked server-side via signup metadata (referred_by_code)
      // while the user has no session yet — client UPDATE would fail RLS.
      await DeepLinkService.clearPendingReferralCode();

      isLoading.value = false;
      _log('Registration successful for: $email');

      final user = response.user;

      // Supabase returns an empty identities array on repeated signup to
      // prevent enumeration — no confirmation email is sent in that case.
      final isRepeatedSignup =
          user != null &&
          response.session == null &&
          (user.identities == null || user.identities!.isEmpty);

      if (isRepeatedSignup) {
        _log('Repeated signup detected — account already exists');
        AppSnack.info('info'.tr, 'auth_error_user_exists'.tr);
        Get.offAllNamed(Routes.login);
        return;
      }

      if (user != null) {
        if (AuthOtpConfig.tempSkipEmailVerification) {
          final completed = await _finalizeRegistrationAndNavigateHome(
            email: email,
            password: password,
            signupResponse: response,
          );
          if (!completed) {
            AppSnack.error('error'.tr, 'auth_error_email_not_confirmed'.tr);
          }
        } else {
          authStatus.value = AuthStatus.unauthenticated;
          _goToVerifyEmail(email, password: password);
          AppSnack.success('success'.tr, 'verification_email_sent'.tr);
        }
      }
    } on AuthException catch (e, stack) {
      isLoading.value = false;
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (AuthSecurityService.isEmailDeliveryFailureError(e)) {
        _log(
          'Signup SMTP failed — attempting direct sign-in (email verify skipped)',
          isError: true,
          error: e.message,
          stack: stack,
        );

        if (AuthOtpConfig.tempSkipEmailVerification) {
          await DeepLinkService.clearPendingReferralCode();
          final completed = await _finalizeRegistrationAndNavigateHome(
            email: email,
            password: password,
          );
          if (completed) return;

          AppSnack.error('error'.tr, 'auth_error_email_not_confirmed'.tr);
          return;
        }

        // Production path: resend signup OTP via Supabase Auth
        try {
          await AuthSecurityService.ensureSignupVerificationSent(email);
          await DeepLinkService.clearPendingReferralCode();
          _goToVerifyEmail(email, password: password);
          AppSnack.success('success'.tr, 'verification_email_sent'.tr);
          return;
        } catch (fallbackError, fallbackStack) {
          _log(
            'Supabase signup OTP resend failed after SMTP error',
            isError: true,
            error: fallbackError,
            stack: fallbackStack,
          );
        }
      }

      _log(
        'Registration failed (AuthException)',
        isError: true,
        error: e.message,
        stack: stack,
      );
      _showAuthFailureSnack(e);
    } catch (e, stack) {
      isLoading.value = false;
      _log(
        'Registration failed (Unexpected)',
        isError: true,
        error: e,
        stack: stack,
      );
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
    }
  }

  Future<void> logout() async {
    try {
      await SecurityActivityService.to.logEvent(SecurityEventType.logout);
      await SupabaseService.auth.signOut();
      await _storage.delete(key: 'saved_login_id');
      await _storage.delete(key: 'saved_password');
      SensitiveOperationGuard.clearStepUp();
      pendingVerificationPhone.value = null;
      _log('Logout successful');
      // Navigation is handled by the signedOut auth-state listener.
    } catch (e, stack) {
      _log('Logout error', isError: true, error: e, stack: stack);
    }
  }

  /// Resend phone OTP via Supabase Auth SMS.
  Future<void> resendPhoneOtp(
    String phoneNumber, {
    OtpType type = OtpType.sms,
    String purpose = 'login',
  }) async {
    _log('Resending phone OTP ($purpose)');
    try {
      await AuthSecurityService.resendPhoneOtp(
        phone: phoneNumber,
        type: type,
        purpose: purpose == 'phone_confirm' ? 'verification' : purpose,
      );
      _log('Phone OTP resent');
      AppSnack.success('success'.tr, 'otp_resend_success'.tr);
    } on AuthException catch (e, stack) {
      _log(
        'Phone OTP resend failed',
        isError: true,
        error: e.message,
        stack: stack,
      );
      AppSnack.error('error'.tr, translateOtpError(e));
      rethrow;
    }
  }

  /// Verify Supabase SMS OTP and complete authentication.
  Future<bool> verifyPhoneOtpCode({
    required String phone,
    required String otp,
    OtpType type = OtpType.sms,
    String purpose = 'login',
  }) async {
    isLoading.value = true;
    _log('Verifying phone OTP ($purpose)');
    try {
      await AuthSecurityService.verifyPhoneOtpCode(
        phone: phone,
        token: otp,
        type: type,
      );
      _log('Phone OTP verified — authentication completed');
      pendingVerificationPhone.value = null;
      authStatus.value = AuthStatus.authenticated;
      await AuthSecurityService.refreshUserProfileState();

      if (purpose == 'signup' ||
          purpose == 'login' ||
          purpose == 'phone_confirm') {
        await _navigateHomeLaunchingTourIfNeeded(
          afterSignup: purpose == 'signup',
        );
      }

      AppSnack.success('success'.tr, 'otp_verified_success'.tr);
      return true;
    } on AuthException catch (e, stack) {
      _log(
        'OTP verification failed',
        isError: true,
        error: e.message,
        stack: stack,
      );
      AppSnack.error('error'.tr, translateOtpError(e));
      return false;
    } catch (e, stack) {
      _log('OTP verification failed', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, 'invalid_otp'.tr);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final sanitizedEmail = email.trim().toLowerCase();

    if (sanitizedEmail.isEmpty) {
      AppSnack.error('error'.tr, 'enter_email_hint'.tr);
      return;
    }

    if (!GetUtils.isEmail(sanitizedEmail)) {
      AppSnack.error('error'.tr, 'invalid_email'.tr);
      return;
    }

    isLoading.value = true;
    final sw = AuthenticationLogger.logStart(
      'password_reset_request',
      method: 'sendPasswordResetEmail',
      authMethod: 'email_otp',
      email: sanitizedEmail,
    );
    try {
      _log('Checking account existence before password reset email');
      final exists = await AuthSecurityService.accountExistsByEmail(
        sanitizedEmail,
      );
      if (!exists) {
        AuthenticationLogger.logSuccess(
          'password_reset_request',
          stopwatch: sw,
          method: 'sendPasswordResetEmail',
          authMethod: 'email_otp',
          email: sanitizedEmail,
          params: {'exists': false},
        );
        AppSnack.error('error'.tr, 'no_account_email'.tr);
        _log('Password reset blocked — email not registered');
        return;
      }

      _log('Sending password reset email');
      await AuthSecurityService.sendPasswordResetEmail(sanitizedEmail);
      AuthenticationLogger.logSuccess(
        'password_reset_request',
        stopwatch: sw,
        method: 'sendPasswordResetEmail',
        authMethod: 'email_otp',
        email: sanitizedEmail,
        params: {'exists': true, 'otpSent': true},
      );
      AppSnack.success('success'.tr, 'reset_otp_sent'.tr);
      Get.toNamed(
        Routes.otp,
        arguments: {
          'identifier': sanitizedEmail,
          'isPhone': false,
          'isFreeOtp': true,
          'isRecovery': true,
          'purpose': 'password_reset',
          'otpLength': AuthOtpConfig.unifiedOtpLength,
        },
      );
    } on AuthException catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_reset_request',
        e,
        stopwatch: sw,
        method: 'sendPasswordResetEmail',
        authMethod: 'email_otp',
        email: sanitizedEmail,
        stackTrace: stack,
      );
      _log(
        'Password reset email failed',
        isError: true,
        error: e.message,
        stack: stack,
      );
      _showAuthFailureSnack(e);
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_reset_request',
        e,
        stopwatch: sw,
        method: 'sendPasswordResetEmail',
        authMethod: 'email_otp',
        email: sanitizedEmail,
        stackTrace: stack,
      );
      _log(
        'Password reset email failed',
        isError: true,
        error: e,
        stack: stack,
      );
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// Password reset via phone OTP (Supabase Auth + Twilio SMS).
  Future<void> sendPasswordResetPhone(String phone) async {
    final sanitized = phone.trim();
    if (sanitized.isEmpty) {
      AppSnack.error('error'.tr, 'invalid_phone'.tr);
      return;
    }

    final e164 = AuthSecurityService.normalizePhone(sanitized);
    final normalizedPhone = e164.startsWith('+') ? e164 : '+$e164';
    if (normalizedPhone.replaceAll(RegExp(r'[^\d]'), '').length < 8) {
      AppSnack.error('error'.tr, 'invalid_phone'.tr);
      return;
    }

    isLoading.value = true;
    final sw = AuthenticationLogger.logStart(
      'password_reset_request',
      method: 'sendPasswordResetPhone',
      authMethod: 'phone_otp',
      phone: normalizedPhone,
    );
    try {
      _log('Checking account existence before password reset phone OTP');
      final exists = await AuthSecurityService.accountExistsByPhone(
        normalizedPhone,
      );
      if (!exists) {
        AuthenticationLogger.logSuccess(
          'password_reset_request',
          stopwatch: sw,
          method: 'sendPasswordResetPhone',
          authMethod: 'phone_otp',
          phone: normalizedPhone,
          params: {'exists': false},
        );
        AppSnack.error('error'.tr, 'no_account_phone'.tr);
        _log('Password reset blocked — phone not registered');
        return;
      }

      _log('Sending password reset phone OTP');
      await OTPService.to.sendPhoneOtp(
        phone: normalizedPhone,
        purpose: 'password_reset',
      );
      AuthenticationLogger.logSuccess(
        'password_reset_request',
        stopwatch: sw,
        method: 'sendPasswordResetPhone',
        authMethod: 'phone_otp',
        phone: normalizedPhone,
        params: {'exists': true, 'otpSent': true},
      );
      AppSnack.success('success'.tr, 'reset_otp_sent'.tr);
      Get.toNamed(
        Routes.otp,
        arguments: {
          'identifier': normalizedPhone,
          'isPhone': true,
          'isFreeOtp': true,
          'isRecovery': true,
          'purpose': 'password_reset',
          'otpLength': AuthOtpConfig.unifiedOtpLength,
        },
      );
    } on AuthException catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_reset_request',
        e,
        stopwatch: sw,
        method: 'sendPasswordResetPhone',
        authMethod: 'phone_otp',
        phone: normalizedPhone,
        stackTrace: stack,
      );
      _log(
        'Password reset phone failed',
        isError: true,
        error: e.message,
        stack: stack,
      );
      _showAuthFailureSnack(e);
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'password_reset_request',
        e,
        stopwatch: sw,
        method: 'sendPasswordResetPhone',
        authMethod: 'phone_otp',
        phone: normalizedPhone,
        stackTrace: stack,
      );
      _log(
        'Password reset phone failed',
        isError: true,
        error: e,
        stack: stack,
      );
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// Sends SMS OTP to verify the signed-in user's phone number.
  Future<void> startPhoneVerification() async {
    final phone = AuthSecurityService.getUserPhone();
    if (phone == null || phone.trim().isEmpty) {
      AppSnack.error('error'.tr, 'phone_verification_required'.tr);
      return;
    }

    isLoading.value = true;
    try {
      await _goToPhoneVerification(phone, purpose: 'phone_confirm');
    } finally {
      isLoading.value = false;
    }
  }

  void updateRegisterPhone(String completeNumber, String countryCode) {
    registerPhoneE164.value = completeNumber;
    registerCountryCode.value = countryCode;
  }

  void goToLegal({int initialTab = 0}) {
    Get.toNamed(Routes.legal, arguments: {'initialTab': initialTab});
  }

  /// Send OTP to an email address via Supabase Auth Email OTP.
  Future<void> sendEmailOtp(
    String email, {
    bool isRecovery = false,
    String purpose = 'verification',
  }) async {
    isLoading.value = true;
    _log('Sending email OTP to: $email');

    try {
      final resolvedPurpose = isRecovery || purpose == 'recovery'
          ? 'password_reset'
          : purpose;
      await OTPService.to.sendEmailOtp(
        email: email.trim().toLowerCase(),
        purpose: resolvedPurpose,
      );

      _log('Email OTP request finished');
      AppSnack.success('success'.tr, 'verification_code_resent'.tr);

      Get.toNamed(
        Routes.otp,
        arguments: {
          'identifier': email.trim().toLowerCase(),
          'isPhone': false,
          'isFreeOtp': true,
          'isRecovery': isRecovery,
          'purpose': resolvedPurpose,
          'otpLength': AuthOtpConfig.unifiedOtpLength,
        },
      );
    } catch (e, stack) {
      _log('Failed to send email OTP', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, translateAuthError(e));
    } finally {
      isLoading.value = false;
    }
  }
}
