import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/country_data.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/auth/domain/models/country_model.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/referral_service.dart';
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
    _checkInitialSession();
    _listenToAuthChanges();
    _linkVerificationStatus();
    _setupReferralListener();
  }

  void _setupReferralListener() {
    referralCodeController.addListener(() {
      final code = referralCodeController.text.trim();
      if (code.isEmpty) {
        referralCodeValid.value = null;
        return;
      }

      // Debounce logic: clear after 500ms and check
      _debounceReferralCheck(code);
    });
  }

  Worker? _referralWorker;
  void _debounceReferralCheck(String code) {
    _referralWorker?.dispose();
    _referralWorker = debounce(
      RxString(code),
      (String val) => checkReferralCode(val),
      time: const Duration(milliseconds: 600),
    );
  }

  Future<void> checkReferralCode(String code) async {
    if (code.isEmpty) {
      referralCodeValid.value = null;
      return;
    }

    try {
      isCheckingReferral.value = true;
      _log('Checking referral code: $code');

      final response = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('referral_code', code)
          .maybeSingle();

      referralCodeValid.value = response != null;
      _log('Referral code $code validity: ${referralCodeValid.value}');
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
        authStatus.value = AuthStatus.authenticated;

        // Pre-fetch data
        if (Get.isRegistered<HomeController>()) {
          HomeController.to.fetchAll();
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
    phoneController.dispose();
    passwordController.dispose();
    nameController.dispose();
    emailController.dispose();
    referralCodeController.dispose();

    super.onClose();
  }

  /// Listen to Supabase auth state changes for session management.
  void _listenToAuthChanges() {
    SupabaseService.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      _log('Auth State Changed: ${event.name}');

      switch (event) {
        case AuthChangeEvent.signedIn:
          _log('User signed in: ${session?.user.id}');
          authStatus.value = AuthStatus.authenticated;

          // Refresh data
          if (Get.isRegistered<HomeController>()) {
            HomeController.to.fetchAll();
            HomeController.to.reconnectStreams();
          }
          if (Get.isRegistered<CurrencyController>()) {
            CurrencyController.to.fetchWalletBalances();
          }

          // Centralized navigation - Skip if already on home or during profile update re-authentication
          if (Get.currentRoute != Routes.home && Get.currentRoute != Routes.profileUpdate) {
            Get.offAllNamed(Routes.home);
          }
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

          // Centralized navigation
          Get.offAllNamed(Routes.login);
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
          if (Get.isRegistered<HomeController>()) {
            HomeController.to.fetchProfile();
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
      final savedPassword = await _storage.read(key: 'saved_password');

      if (savedLoginId != null && savedPassword != null) {
        phoneController.text = savedLoginId;
        passwordController.text = savedPassword;
        rememberMe.value = true;
      }
    } catch (e, stack) {
      _log('Error loading credentials', isError: true, error: e, stack: stack);
    }
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

  Future<void> login() async {
    if (!loginFormKey.currentState!.validate()) return;

    if (phoneController.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'email_or_phone'.tr);
      return;
    }

    isLoading.value = true;

    try {
      final loginId = phoneController.text.trim();
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

      // Print session data after login
      final user = SupabaseService.currentUser;
      if (user != null) {
        debugPrint('\n╔══════════════════════════════════════════════════');
        debugPrint('║ 🔐 LOGIN SUCCESSFUL - USER DATA');
        debugPrint('╠──────────────────────────────────────────────────');
        debugPrint('║ ID:        ${user.id}');
        debugPrint('║ Email:     ${user.email}');
        debugPrint('║ Phone:     ${user.phone}');
        debugPrint('║ Created:   ${user.createdAt}');
        debugPrint('║ Metadata:  ${user.userMetadata}');
        debugPrint('╚══════════════════════════════════════════════════\n');
      }

      // Save credentials if "remember me" is enabled
      if (rememberMe.value) {
        await _storage.write(key: 'saved_login_id', value: loginId);
        await _storage.write(key: 'saved_password', value: password);
      } else {
        await _storage.delete(key: 'saved_login_id');
        await _storage.delete(key: 'saved_password');
      }

      isLoading.value = false;
      _log('Login successful for: $loginId');
      Get.offAllNamed(Routes.home);
    } on AuthException catch (e, stack) {
      isLoading.value = false;
      _log(
        'Login failed (AuthException)',
        isError: true,
        error: e.message,
        stack: stack,
      );
      Get.snackbar(
        'error'.tr,
        _getAuthErrorMessage(e.message),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.2),
      );
    } catch (e, stack) {
      isLoading.value = false;
      _log('Login failed (Unexpected)', isError: true, error: e, stack: stack);
      Get.snackbar(
        'error'.tr,
        'حدث خطأ غير متوقع. حاول مرة أخرى.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> register() async {
    if (!registerFormKey.currentState!.validate()) return;
    if (!termsAccepted.value) {
      Get.snackbar('error'.tr, 'agree_error'.tr);
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
      String? referrerId;
      if (referralCodeInput.isNotEmpty) {
        referrerId = await ReferralService.validateReferralCode(
          referralCodeInput,
        );
        if (referrerId == null) {
          isLoading.value = false;
          Get.snackbar(
            'error'.tr,
            'invalid_referral_code'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withValues(alpha: 0.2),
          );
          return;
        }
      }

      // Generate own referral code (k-XXXXX)
      final ownReferralCode = ReferralService.generateReferralCode();

      // Log all registration data before sending
      debugPrint('\n╔══════════════════════════════════════════════════');
      debugPrint('║ 📝 REGISTRATION ATTEMPT - DATA BEING SENT');
      debugPrint('╠──────────────────────────────────────────────────');
      debugPrint('║ Full Name:     $fullName');
      debugPrint('║ Email:         $email');
      debugPrint('║ Phone:         $phone');
      debugPrint('║ Country Code:  ${selectedCountry.value.code}');
      debugPrint('║ Referral Code: $ownReferralCode');
      debugPrint('║ Referred By:   $referralCodeInput');
      debugPrint('║ Referrer ID:   $referrerId');
      debugPrint('╚══════════════════════════════════════════════════\n');

      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'country_code': selectedCountry.value.code,
          'referral_code': ownReferralCode,
          if (referralCodeInput.isNotEmpty)
            'referred_by_code': referralCodeInput,
        },
      );

      // Print response data after registration
      if (response.user != null) {
        debugPrint('\n╔══════════════════════════════════════════════════');
        debugPrint('║ ✅ REGISTRATION SUCCESSFUL - RESPONSE DATA');
        debugPrint('╠──────────────────────────────────────────────────');
        debugPrint('║ User ID:     ${response.user!.id}');
        debugPrint('║ Email:       ${response.user!.email}');
        debugPrint('║ Phone:       ${response.user!.phone}');
        debugPrint('║ Created:     ${response.user!.createdAt}');
        debugPrint('║ Metadata:    ${response.user!.userMetadata}');
        debugPrint('║ App Meta:    ${response.user!.appMetadata}');
        debugPrint('║ Session:     ${response.session != null ? "Active" : "None"}');
        debugPrint('╚══════════════════════════════════════════════════\n');
      }

      // Link referral after successful registration
      if (referrerId != null && response.user != null) {
        await ReferralService.linkReferral(
          newUserId: response.user!.id,
          referrerId: referrerId,
        );
      }

      isLoading.value = false;
      _log('Registration successful for: $email');
      Get.offAllNamed(Routes.home);
    } on AuthException catch (e, stack) {
      isLoading.value = false;
      _log(
        'Registration failed (AuthException)',
        isError: true,
        error: e.message,
        stack: stack,
      );
      Get.snackbar(
        'error'.tr,
        _getAuthErrorMessage(e.message),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.2),
      );
    } catch (e, stack) {
      isLoading.value = false;
      _log(
        'Registration failed (Unexpected)',
        isError: true,
        error: e,
        stack: stack,
      );
      Get.snackbar(
        'error'.tr,
        'حدث خطأ غير متوقع. حاول مرة أخرى.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> logout() async {
    try {
      await SupabaseService.auth.signOut();
      await _storage.delete(key: 'saved_login_id');
      await _storage.delete(key: 'saved_password');
      _log('Logout successful');
      Get.offAllNamed(Routes.login);
    } catch (e, stack) {
      _log('Logout error', isError: true, error: e, stack: stack);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final sanitizedEmail = email.trim().toLowerCase();

    if (sanitizedEmail.isEmpty) {
      Get.snackbar('error'.tr, 'enter_email_hint'.tr);
      return;
    }

    if (!GetUtils.isEmail(sanitizedEmail)) {
      Get.snackbar('error'.tr, 'invalid_email'.tr);
      return;
    }

    _log('Routing email password reset to custom FCM OTP: $sanitizedEmail');
    await sendEmailOtp(
      sanitizedEmail,
      purpose: 'password_reset',
      isRecovery: true,
    );
  }

  Future<void> sendPasswordResetOTP(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar('error'.tr, 'enter_phone_hint'.tr);
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
        },
      );
    } catch (e, stack) {
      _log('Failed to send phone OTP', isError: true, error: e, stack: stack);
      Get.snackbar('error'.tr, e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  /// Send OTP to an email address via FCM.
  Future<void> sendEmailOtp(
    String email, {
    bool isRecovery = false,
    String purpose = 'verification',
  }) async {
    isLoading.value = true;
    _log('Sending email OTP via FCM to: $email');

    try {
      final fcmToken = FCMService.to.fcmToken.value;
      if (fcmToken.isEmpty) {
        throw Exception(
          'FCM Token not available. Please enable notifications.',
        );
      }

      final bool success = await Get.find<OTPService>().sendOtp(
        target: email,
        targetType: 'email',
        fcmToken: fcmToken,
        purpose: purpose,
      );

      _log('Email OTP request finished. Success: $success');

      if (success) {
        AppSnack.success(
          'success'.tr,
          'تم إرسال رمز التحقق بنجاح',
        );
      }

      Get.toNamed(
        Routes.otp,
        arguments: {
          'identifier': email,
          'isPhone': false,
          'isFreeOtp': true,
          'isRecovery': isRecovery,
          'purpose': purpose,
        },
      );
    } catch (e, stack) {
      _log('Failed to send email OTP', isError: true, error: e, stack: stack);
      Get.snackbar('error'.tr, e.toString());
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
        Get.offAllNamed(Routes.home);
      }

      Get.snackbar(
        'success'.tr,
        'تم التحقق بنجاح',
        backgroundColor: AppColors.softGreen,
        colorText: Colors.white,
      );
    } catch (e, stack) {
      _log('OTP verification failed', isError: true, error: e, stack: stack);
      if (e is OTPVerificationException && e.remainingAttempts != null) {
        Get.snackbar(
          'error'.tr,
          '${e.message}\n${'remaining_attempts'.tr}: ${e.remainingAttempts}',
        );
      } else {
        Get.snackbar('error'.tr, e.toString());
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Translate Supabase auth error messages to Arabic.
  String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'بيانات الدخول غير صحيحة';
    } else if (message.contains('Email not confirmed')) {
      return 'البريد الإلكتروني غير مفعّل. تحقق من بريدك';
    } else if (message.contains('User already registered')) {
      return 'هذا الحساب مسجل مسبقاً';
    } else if (message.contains('Password should be')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    } else if (message.contains('rate limit')) {
      return 'محاولات كثيرة. حاول بعد قليل';
    } else if (message.toLowerCase().contains('invalid email') ||
        message.contains('Email address')) {
      return 'البريد الإلكتروني غير مسجل في النظام أو غير صالح';
    } else if (message.contains('User not found')) {
      return 'هذا الحساب غير موجود لدينا';
    } else if (message.contains('Signups not allowed')) {
      return 'هذا الحساب غير مسجل مسبقاً في النظام';
    } else if (message.contains('Database error saving new user')) {
      return 'رقم الهاتف أو البريد الإلكتروني مسجل مسبقاً';
    }
    return message;
  }
}
