import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/utils/country_data.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/auth/domain/models/country_model.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/domain/utils/login_identifier_utils.dart';
import 'package:kasby/core/services/deep_link_service.dart';
import 'package:kasby/core/services/tour_service.dart';
import 'package:kasby/core/services/sensitive_operation_guard.dart';
import 'package:kasby/core/services/crash_reporting/crash_breadcrumb.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
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
        unawaited(CrashReportingService.recordAuthError(
          error,
          stack: stack,
          expectedFailure: error is AuthException,
        ));
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
      final code = ReferralService.normalizeCode(referralCodeController.text);
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
    final normalized = ReferralService.normalizeCode(code);
    if (normalized.isEmpty) {
      referralCodeValid.value = null;
      return;
    }

    if (!ReferralService.isValidFormat(normalized)) {
      referralCodeValid.value = false;
      return;
    }

    try {
      isCheckingReferral.value = true;
      _log('Checking referral code: $normalized');

      final referrerId = await ReferralService.validateReferralCode(normalized);
      referralCodeValid.value = referrerId != null;
      _log('Referral code $normalized validity: ${referralCodeValid.value}');
    } catch (e) {
      _log('Error checking referral code', isError: true, error: e);
      referralCodeValid.value = false;
    } finally {
      isCheckingReferral.value = false;
    }
  }

  void _linkVerificationStatus() {
    if (Get.isRegistered<HomeController>()) {
      ever(HomeController.to.profile, (profile) {
        isVerified.value = profile?.kycStatus == 'verified';
        _log('isVerified updated: ${isVerified.value}');
      });
    } else {
      _log(
        'HomeController not registered yet, skipping verification link',
        isError: true,
      );
    }
  }

  /// Check current session status on startup
  Future<void> _checkInitialSession() async {
    try {
      final session = SupabaseService.auth.currentSession;
      if (session != null) {
        _log('Initial session found for user: ${session.user.id}');
        if (_requiresEmailVerification(session.user)) {
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
          if (session != null && _requiresEmailVerification(session.user)) {
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
              _goToPhoneVerification(phone, purpose: 'phone_confirm');
            }
            break;
          }

          authStatus.value = AuthStatus.authenticated;
          pendingVerificationEmail.value = null;
          pendingVerificationPhone.value = null;

          unawaited(CrashReportingService.log(CrashBreadcrumb.loginCompleted));
          if (Get.isRegistered<HomeController>()) {
            HomeController.to.fetchAll();
            HomeController.to.reconnectStreams();
          }
          if (Get.isRegistered<CurrencyController>()) {
            CurrencyController.to.fetchWalletBalances();
          }

          unawaited(CrashReportingService.syncUserContextFromProfile());
          _navigateAfterAuthentication();
          break;

        case AuthChangeEvent.signedOut:
          _log('User signed out');
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
          if (Get.isRegistered<HomeController>()) {
            HomeController.to.reconnectStreams();
          }
          break;

        case AuthChangeEvent.passwordRecovery:
          _log('Password recovery mode');
          Get.toNamed(Routes.changePassword, arguments: {'isRecovery': true});
          break;

        case AuthChangeEvent.userUpdated:
          _log('User updated');
          AuthSecurityService.refreshUserProfileState();
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

  void _goToPhoneVerification(
    String phone, {
    String purpose = 'login',
    bool isRecovery = false,
  }) {
    pendingVerificationPhone.value = phone;
    Get.toNamed(
      Routes.otp,
      arguments: {
        'identifier': phone,
        'isPhone': true,
        'isFreeOtp': false,
        'type': OtpType.sms,
        'purpose': purpose,
        'isRecovery': isRecovery,
        'otpLength': AuthSecurityService.phoneOtpLength,
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

  Future<void> resendVerificationEmail(String email, {String purpose = 'signup'}) async {
    _log('Resending verification ($purpose)');
    if (purpose == 'signup') {
      await AuthSecurityService.ensureSignupVerificationSent(email);
      return;
    }
    await AuthSecurityService.resendOtp(
      email: email,
      type: OtpType.emailChange,
    );
  }

  Future<bool> checkEmailVerificationStatus({
    String purpose = 'signup',
    String? targetEmail,
  }) async {
    _log('Checking email verification status ($purpose)');
    if (purpose == 'email_change') {
      final target =
          targetEmail ?? pendingVerificationEmail.value ?? '';
      if (target.isEmpty) return false;
      final complete =
          await AuthSecurityService.isPendingEmailChangeComplete(target);
      if (complete) {
        await AuthSecurityService.refreshUserProfileState();
      }
      return complete;
    }
    final verified = await AuthSecurityService.refreshAndCheckEmailVerified();
    if (verified) {
      authStatus.value = AuthStatus.authenticated;
      pendingVerificationEmail.value = null;
      await AuthSecurityService.refreshUserProfileState();
    }
    return verified;
  }

  Future<void> verifyEmailWithOtp({
    required String email,
    required String code,
    String purpose = 'signup',
    String? signupPassword,
  }) async {
    isLoading.value = true;
    try {
      _log('Verifying email OTP ($purpose)');
      if (purpose == 'email_change') {
        await AuthSecurityService.verifyOtpCode(
          email: email,
          token: code,
          type: OtpType.emailChange,
        );
        await AuthSecurityService.refreshUserProfileState();
        pendingVerificationEmail.value = null;
        AppSnack.success('success'.tr, 'email_changed_success'.tr);
        Get.offAllNamed(Routes.personalProfile);
        return;
      }

      await AuthSecurityService.confirmSignupEmailOtp(
        email: email,
        code: code,
      );

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
      AppSnack.success('success'.tr, 'email_verified_success'.tr);
      final tourDone = await TourService.isTourCompleted();
      if (!tourDone) {
        Get.offAllNamed(Routes.guidedTour);
      } else {
        Get.offAllNamed(Routes.home);
      }
    } on AuthException catch (e, stack) {
      _log('Email OTP verification failed', isError: true, error: e.message, stack: stack);
      throw AuthException(AuthSecurityService.translateOtpError(e));
    } finally {
      isLoading.value = false;
    }
  }

  String translateAuthError(Object error) =>
      AuthSecurityService.translateAuthError(error);

  String translateOtpError(Object error) =>
      AuthSecurityService.translateOtpError(error);

  void _goToVerifyEmail(
    String email, {
    String purpose = 'signup',
    String? password,
  }) {
    pendingVerificationEmail.value = email;
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

  Future<void> login({bool skipFormValidation = false}) async {
    if (!skipFormValidation && !loginFormKey.currentState!.validate()) return;

    final loginId = loginIdentifierController.text.trim();
    if (loginId.isEmpty) {
      AppSnack.error('error'.tr, 'email_or_phone'.tr);
      return;
    }

    isLoading.value = true;
    unawaited(CrashReportingService.log(CrashBreadcrumb.loginStarted));

    try {
      final password = passwordController.text;

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

      if (user != null && _requiresEmailVerification(user)) {
        _goToVerifyEmail(user.email ?? loginId);
      } else if (user != null && _requiresPhoneVerification(user)) {
        final phone = AuthSecurityService.getUserPhone() ??
            (LoginIdentifierUtils.isEmail(loginId)
                ? null
                : LoginIdentifierUtils.toE164(loginId));
        if (phone != null) {
          _goToPhoneVerification(phone, purpose: 'phone_confirm');
        }
      }
    } on AuthException catch (e, stack) {
      isLoading.value = false;
      _log(
        'Login failed (AuthException)',
        isError: true,
        error: e.message,
        stack: stack,
      );
      if (e.message.contains('Email not confirmed') &&
          LoginIdentifierUtils.isEmail(loginId)) {
        _goToVerifyEmail(loginId);
        return;
      }
      AppSnack.error('error'.tr, translateAuthError(e));
    } catch (e, stack) {
      isLoading.value = false;
      _log('Login failed (Unexpected)', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
    }
  }

  Future<void> register({bool skipFormValidation = false}) async {
    if (!skipFormValidation && !registerFormKey.currentState!.validate()) return;
    if (!termsAccepted.value) {
      AppSnack.error('error'.tr, 'agree_error'.tr);
      return;
    }

    isLoading.value = true;

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;
      final fullName = nameController.text.trim();
      final phone = registerPhoneE164.value.trim();
      if (phone.isEmpty) {
        isLoading.value = false;
        AppSnack.error('error'.tr, 'invalid_phone'.tr);
        return;
      }
      final referralCodeInput = referralCodeController.text
          .trim()
          .toUpperCase();

      // Validate referral code if provided
      ReferralCodeLookup? referralLookup;
      if (referralCodeInput.isNotEmpty) {
        referralLookup = await ReferralService.validateReferralCode(
          referralCodeInput,
        );
        if (referralLookup == null) {
          isLoading.value = false;
          AppSnack.error('error'.tr, 'invalid_referral_code'.tr);
          return;
        }
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
      final isRepeatedSignup = user != null &&
          response.session == null &&
          (user.identities == null || user.identities!.isEmpty);

      if (isRepeatedSignup) {
        _log('Repeated signup detected — account already exists');
        AppSnack.info(
          'info'.tr,
          'auth_error_user_exists'.tr,
        );
        Get.offAllNamed(Routes.login);
        return;
      }

      final needsVerification = user != null &&
          (response.session == null || _requiresEmailVerification(user));
      if (needsVerification) {
        // GoTrue already sends the "Confirm sign up" email on signUp().
        // Avoid an immediate resend — it invalidates the active OTP.
        _goToVerifyEmail(email, password: password);
        AppSnack.success('success'.tr, 'verification_email_sent'.tr);
      } else if (response.session != null) {
        authStatus.value = AuthStatus.authenticated;
        final tourDone = await TourService.isTourCompleted();
        if (!tourDone) {
          Get.offAllNamed(Routes.guidedTour);
        } else {
          Get.offAllNamed(Routes.home);
        }
      }
    } on AuthException catch (e, stack) {
      isLoading.value = false;
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (AuthSecurityService.isEmailDeliveryFailureError(e)) {
        _log(
          'Signup SMTP failed — trying Resend fallback',
          isError: true,
          error: e.message,
          stack: stack,
        );
        try {
          await AuthSecurityService.ensureSignupVerificationSent(email);
          await DeepLinkService.clearPendingReferralCode();
          _goToVerifyEmail(email, password: password);
          AppSnack.success('success'.tr, 'verification_email_sent'.tr);
          return;
        } catch (fallbackError, fallbackStack) {
          _log(
            'Resend fallback failed after signup SMTP error',
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
      AppSnack.error('error'.tr, translateAuthError(e));
    } catch (e, stack) {
      isLoading.value = false;
      _log(
        'Registration failed (Unexpected)',
        isError: true,
        error: e,
        stack: stack,
      );
      AppSnack.error('error'.tr, 'حدث خطأ غير متوقع. حاول مرة أخرى.');
    }
  }

  Future<void> logout() async {
    try {
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

  /// Resend Supabase SMS OTP to a phone number (verification / step-up flows).
  Future<void> resendPhoneOtp(
    String phoneNumber, {
    OtpType type = OtpType.sms,
    String purpose = 'login',
  }) async {
    _log('Resending phone OTP ($purpose)');
    try {
      await AuthSecurityService.resendPhoneOtp(phone: phoneNumber, type: type);
      _log('Phone OTP resent');
      AppSnack.success('success'.tr, 'otp_resend_success'.tr);
    } on AuthException catch (e, stack) {
      _log('Phone OTP resend failed', isError: true, error: e.message, stack: stack);
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

      if (purpose == 'signup' || purpose == 'login' || purpose == 'phone_confirm') {
        final tourDone = await TourService.isTourCompleted();
        if (!tourDone) {
          Get.offAllNamed(Routes.guidedTour);
        } else {
          Get.offAllNamed(Routes.home);
        }
      }

      AppSnack.success('success'.tr, 'otp_verified_success'.tr);
      return true;
    } on AuthException catch (e, stack) {
      _log('OTP verification failed', isError: true, error: e.message, stack: stack);
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
    try {
      _log('Sending password reset email');
      await AuthSecurityService.sendPasswordResetEmail(sanitizedEmail);
      AppSnack.success('success'.tr, 'reset_otp_sent'.tr);
      Get.toNamed(
        Routes.otp,
        arguments: {
          'identifier': sanitizedEmail,
          'isPhone': false,
          'isFreeOtp': false,
          'type': OtpType.recovery,
          'isRecovery': true,
          'otpLength': AuthOtpConfig.lengthForOtpType(OtpType.recovery),
        },
      );
    } on AuthException catch (e, stack) {
      _log('Password reset email failed', isError: true, error: e.message, stack: stack);
      AppSnack.error('error'.tr, translateAuthError(e));
      rethrow;
    } catch (e, stack) {
      _log('Password reset email failed', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, 'unexpected_error'.tr);
      rethrow;
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
      await AuthSecurityService.sendPhoneOtp(
        phone: phone,
        shouldCreateUser: false,
      );
      AppSnack.success('success'.tr, 'otp_sent_success'.tr);
      _goToPhoneVerification(phone, purpose: 'phone_confirm');
    } on AuthException catch (e, stack) {
      _log('Phone verification OTP failed', isError: true, error: e.message, stack: stack);
      AppSnack.error('error'.tr, translateOtpError(e));
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

  /// Send OTP to an email address via the hardened edge function (Resend).
  Future<void> sendEmailOtp(
    String email, {
    bool isRecovery = false,
    String purpose = 'verification',
  }) async {
    isLoading.value = true;
    _log('Sending email OTP to: $email');

    try {
      final bool success = await Get.find<OTPService>().sendOtp(
        target: email.trim().toLowerCase(),
        targetType: 'email',
        purpose: purpose,
      );

      _log('Email OTP request finished. Success: $success');

      if (success) {
        AppSnack.success('success'.tr, 'verification_code_resent'.tr);
      }

      Get.toNamed(
        Routes.otp,
        arguments: {
          'identifier': email.trim().toLowerCase(),
          'isPhone': false,
          'isFreeOtp': true,
          'isRecovery': isRecovery,
          'purpose': purpose,
          'otpLength': purpose == 'email_change'
              ? AuthOtpConfig.lengthForPurpose('email_change')
              : AuthOtpConfig.fcmOtpLength,
        },
      );
    } catch (e, stack) {
      _log('Failed to send email OTP', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
