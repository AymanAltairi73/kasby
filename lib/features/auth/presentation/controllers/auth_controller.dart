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
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/core/services/deep_link_service.dart';
import 'package:kasby/core/services/tour_service.dart';
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

  StreamSubscription<AuthState>? _authSubscription;

  // Text Controllers
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final referralCodeController = TextEditingController();

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
    phoneController.dispose();
    passwordController.dispose();
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

          authStatus.value = AuthStatus.authenticated;
          pendingVerificationEmail.value = null;

          if (Get.isRegistered<HomeController>()) {
            HomeController.to.fetchAll();
            HomeController.to.reconnectStreams();
          }
          if (Get.isRegistered<CurrencyController>()) {
            CurrencyController.to.fetchWalletBalances();
          }

          _navigateAfterAuthentication();
          break;

        case AuthChangeEvent.signedOut:
          _log('User signed out');
          authStatus.value = AuthStatus.unauthenticated;

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
        phoneController.text = savedLoginId;
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

  void _navigateAfterAuthentication() {
    const skipRoutes = {
      Routes.home,
      Routes.profileUpdate,
      Routes.changePassword,
      Routes.verifyEmail,
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
      await AuthSecurityService.signInAfterSignup(
        email: email,
        password: passwordController.text,
      );
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

  void _goToVerifyEmail(String email, {String purpose = 'signup'}) {
    pendingVerificationEmail.value = email;
    Get.offAllNamed(
      Routes.verifyEmail,
      arguments: {'email': email, 'purpose': purpose},
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

    if (phoneController.text.trim().isEmpty) {
      AppSnack.error('error'.tr, 'email_or_phone'.tr);
      return;
    }

    isLoading.value = true;
    final loginId = phoneController.text.trim();

    try {
      final password = passwordController.text;

      // Determine if user is logging in with email or phone
      if (loginId.contains('@')) {
        // Email login
        _log('🔑 Login attempt via EMAIL: $loginId');
        await SupabaseService.auth.signInWithPassword(
          email: loginId,
          password: password,
        );
      } else {
        // Phone login
        final fullPhone = '${selectedCountry.value.dialCode}$loginId';
        _log('🔑 Login attempt via PHONE: $fullPhone');
        await SupabaseService.auth.signInWithPassword(
          phone: fullPhone,
          password: password,
        );
      }

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
      }
    } on AuthException catch (e, stack) {
      isLoading.value = false;
      _log(
        'Login failed (AuthException)',
        isError: true,
        error: e.message,
        stack: stack,
      );
      if (e.message.contains('Email not confirmed') && loginId.contains('@')) {
        _goToVerifyEmail(loginId);
        return;
      }
      AppSnack.error('error'.tr, translateAuthError(e));
    } catch (e, stack) {
      isLoading.value = false;
      _log('Login failed (Unexpected)', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, 'حدث خطأ غير متوقع. حاول مرة أخرى.');
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
      final phone =
          '${selectedCountry.value.dialCode}${phoneController.text.trim()}';
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
          'countryCode': selectedCountry.value.code,
        },
      );

      final response = await AuthSecurityService.signUpWithEmailVerification(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'country_code': selectedCountry.value.code,
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
      final needsVerification = user != null &&
          (response.session == null || _requiresEmailVerification(user));
      if (needsVerification) {
        // Always dispatch signup OTP — GoTrue may return 200 for repeated
        // signups without sending mail unless /resend is called explicitly.
        try {
          await AuthSecurityService.ensureSignupVerificationSent(email);
          _goToVerifyEmail(email);
          AppSnack.success('success'.tr, 'verification_email_sent'.tr);
        } on AuthException catch (e, stack) {
          _log(
            'Signup verification dispatch failed',
            isError: true,
            error: e.message,
            stack: stack,
          );
          _goToVerifyEmail(email);
          AppSnack.error('error'.tr, translateAuthError(e));
        }
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
      _log('Logout successful');
      // Navigation is handled by the signedOut auth-state listener.
    } catch (e, stack) {
      _log('Logout error', isError: true, error: e, stack: stack);
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

  Future<void> sendPasswordResetOTP(String phone) async {
    if (phone.isEmpty) {
      AppSnack.error('error'.tr, 'enter_phone_hint'.tr);
      return;
    }

    _log('Routing phone password reset to custom FCM OTP: $phone');
    await sendPhoneOtp(phone, isRecovery: true, purpose: 'password_reset');
  }

  Future<void> verifyPasswordResetOTP(String phone, String token) async {
    isLoading.value = true;
    _log('Legacy native verification bypassed for custom OTP.');
    isLoading.value = false;
  }

  void goToLegal() {
    Get.toNamed(Routes.legal);
  }

  Future<void> sendPhoneOtp(
    String phoneNumber, {
    bool isRecovery = false,
    String purpose = 'verification',
  }) async {
    isLoading.value = true;
    _log('Sending phone OTP via FCM to: $phoneNumber');

    try {
      final fcmToken = FCMService.to.fcmToken.value;
      if (fcmToken.isEmpty) {
        throw Exception(
          'FCM Token not available. Please enable notifications.',
        );
      }

      final bool success = await Get.find<OTPService>().sendOtp(
        target: phoneNumber,
        targetType: 'phone',
        fcmToken: fcmToken,
        purpose: purpose,
      );

      _log('Phone OTP request finished. Success: $success');

      if (success) {
        AppSnack.success(
          'success'.tr,
          'تم إرسال رمز التحقق بنجاح',
        );
      }

      Get.toNamed(
        Routes.otp,
        arguments: {
          'identifier': phoneNumber,
          'isPhone': true,
          'isFreeOtp': true,
          'isRecovery': isRecovery,
          'purpose': purpose,
          'otpLength': AuthOtpConfig.fcmOtpLength,
        },
      );
    } catch (e, stack) {
      _log('Failed to send phone OTP', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, e.toString());
    } finally {
      isLoading.value = false;
    }
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

  Future<void> verifyPhoneOtp(
    String target,
    String otp, {
    String targetType = 'phone',
    String purpose = 'verification',
  }) async {
    isLoading.value = true;
    _log('Verifying $targetType OTP: $otp for $target ($purpose)');

    try {
      await Get.find<OTPService>().verifyOtp(
        target: target,
        targetType: targetType,
        otpCode: otp,
      );
      _log('$targetType verified successfully via Edge Function');

      // Default navigation for signup/login verification
      if (purpose == 'verification' || purpose == 'signup') {
        final tourDone = await TourService.isTourCompleted();
        if (!tourDone) {
          Get.offAllNamed(Routes.guidedTour);
        } else {
          Get.offAllNamed(Routes.home);
        }
      }

      AppSnack.success('success'.tr, 'تم التحقق بنجاح');
    } catch (e, stack) {
      _log('OTP verification failed', isError: true, error: e, stack: stack);
      if (e is OTPVerificationException && e.remainingAttempts != null) {
        AppSnack.error(
          'error'.tr,
          '${e.message}\n${'remaining_attempts'.tr}: ${e.remainingAttempts}',
        );
      } else {
        AppSnack.error('error'.tr, e.toString());
      }
    } finally {
      isLoading.value = false;
    }
  }
}
