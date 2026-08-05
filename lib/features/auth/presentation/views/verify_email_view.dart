import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/confetti_service.dart';
import 'package:kasby/core/services/network_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/utils/mask_utils.dart';
import 'package:kasby/features/auth/presentation/widgets/auth_otp_input.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Email verification screen for signup and email-change flows.
class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView>
    with WidgetsBindingObserver {
  final AuthController _auth = AuthController.to;
  final GlobalKey<AuthOtpInputState> _otpKey = GlobalKey<AuthOtpInputState>();

  bool _isRefreshing = false;
  bool _isVerifyingOtp = false;
  bool _isResending = false;
  bool _showVerifiedSuccess = false;
  late int _resendCountdown;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  StreamSubscription<AuthState>? _authSubscription;

  String get _purpose {
    final args = Get.arguments;
    if (args is Map && args['purpose'] is String) {
      return args['purpose'] as String;
    }
    return 'signup';
  }

  int get _otpLength => AuthOtpConfig.lengthForPurpose(_purpose);

  bool get _isEmailChange => _purpose == 'email_change';

  bool get _canPollStatus =>
      AuthSecurityService.canPollVerificationStatus(purpose: _purpose);

  String get _email {
    final args = Get.arguments;
    if (args is Map && args['email'] is String) {
      return args['email'] as String;
    }
    return _auth.pendingVerificationEmail.value ??
        _auth.emailController.text.trim();
  }

  String? get _signupPassword {
    final args = Get.arguments;
    if (args is Map && args['password'] is String) {
      final password = (args['password'] as String).trim();
      return password.isEmpty ? null : password;
    }
    return null;
  }

  String get _title =>
      _isEmailChange ? 'confirm_new_email'.tr : 'verify_email'.tr;

  String get _description => _isEmailChange
      ? 'email_change_verify_desc'.trParams({'count': '$_otpLength'})
      : 'verify_email_desc'.trParams({'count': '$_otpLength'});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthenticationLogger.logStart(
      'email_verification_screen',
      method: 'initState',
      authMethod: 'email_otp',
      email: _email,
      params: {'purpose': _purpose},
    );
    if (_email.isNotEmpty) {
      _auth.pendingVerificationEmail.value = _email;
    }
    _resendCountdown = AuthOtpConfig.cooldownSeconds;
    _startCountdown();
    if (_canPollStatus) {
      _startAutoPoll();
    }
    _listenForAuthVerification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from Gmail can briefly mark the app offline; refresh status.
    if (state == AppLifecycleState.resumed) {
      unawaited(NetworkService.to.retryConnection());
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _resendCountdown = AuthOtpConfig.cooldownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _startAutoPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _refreshStatus(silent: true);
    });
  }

  void _listenForAuthVerification() {
    _authSubscription = SupabaseService.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.userUpdated ||
          state.event == AuthChangeEvent.tokenRefreshed) {
        _refreshStatus(silent: true);
      }
    });
  }

  Future<void> _onVerified() async {
    _pollTimer?.cancel();
    if (!mounted) return;

    setState(() => _showVerifiedSuccess = true);
    if (Get.isRegistered<ConfettiService>()) {
      ConfettiService.to.celebrate();
    }

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    AuthenticationLogger.logSuccess(
      'email_verification_complete',
      stopwatch: Stopwatch()..start(),
      method: '_onVerified',
      authMethod: 'email_otp',
      email: _email,
      params: {'purpose': _purpose},
    );

    if (_isEmailChange) {
      AppSnack.success('success'.tr, 'email_changed_success'.tr);
      Get.offAllNamed(Routes.personalProfile);
    } else {
      _auth.authStatus.value = AuthStatus.authenticated;
      _auth.pendingVerificationEmail.value = null;
      AppSnack.success('success'.tr, 'verification_completed'.tr);
      Get.offAllNamed(Routes.home);
    }
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    if (_isRefreshing || _isVerifyingOtp || _showVerifiedSuccess) return;

    if (!_canPollStatus) {
      if (!silent && mounted) {
        AppSnack.info('verify_email'.tr, 'verify_email_enter_code_first'.tr);
      }
      return;
    }

    if (!silent) setState(() => _isRefreshing = true);
    try {
      final verified = await _auth.checkEmailVerificationStatus(
        purpose: _purpose,
        targetEmail: _email,
      );
      if (verified && mounted) {
        await _onVerified();
      } else if (!silent && mounted) {
        AppSnack.warning(_title, 'email_not_verified_yet'.tr);
      }
    } on AuthException catch (e) {
      if (!silent && mounted) {
        AppSnack.error('error'.tr, _auth.translateOtpError(e));
      }
    } catch (_) {
      if (!silent && mounted) {
        AppSnack.error('error'.tr, 'unknown_error'.tr);
      }
    } finally {
      if (mounted && !silent) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_resendCountdown > 0 || _isResending) return;
    if (_email.isEmpty) {
      AppSnack.error('error'.tr, 'enter_email_hint'.tr);
      return;
    }

    setState(() => _isResending = true);
    try {
      await _auth.resendVerificationEmail(_email, purpose: _purpose);
      AppSnack.success('success'.tr, 'verification_email_resent'.tr);
      _startCountdown();
    } on AuthException catch (e) {
      AppSnack.error('error'.tr, _auth.translateAuthError(e));
    } catch (_) {
      AppSnack.error('error'.tr, 'otp_resend_failed'.tr);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtpCode(String code) async {
    if (!AuthOtpConfig.isComplete(code, _otpLength)) {
      AppSnack.error(
        'error'.tr,
        'enter_full_otp'.trParams({'count': '$_otpLength'}),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      await _auth.verifyEmailWithOtp(
        email: _email,
        code: code,
        purpose: _purpose,
        signupPassword: _signupPassword,
        navigateOnSuccess: false,
      );
      if (mounted) await _onVerified();
    } on AuthException catch (e) {
      AppSnack.error('error'.tr, _auth.translateOtpError(e));
      _otpKey.currentState?.clear();
    } catch (_) {
      AppSnack.error('error'.tr, 'invalid_otp'.tr);
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  Future<void> _openEmailApp() async {
    final uri = Uri.parse('mailto:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      AppSnack.info('verify_email'.tr, 'verify_email_hint'.tr);
    }
  }

  Future<void> _changeEmail() async {
    if (_isEmailChange) {
      Get.back();
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('change_email_verify_title'.tr),
        content: Text('change_email_verify_desc'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('change_email'.tr),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _pollTimer?.cancel();
      await _auth.logout();
      Get.offAllNamed(Routes.register);
    }
  }

  Future<void> _backToLogin() async {
    _pollTimer?.cancel();
    if (_isEmailChange) {
      Get.back();
    } else {
      await _auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusy = _isRefreshing || _isVerifyingOtp;

    if (_showVerifiedSuccess) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.background
            : AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_rounded,
                size: 88,
                color: AppColors.softGreen,
              ).animate().scale(curve: Curves.elasticOut, duration: 700.ms),
              const SizedBox(height: 24),
              Text(
                'verification_completed'.tr,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),
              CircularProgressIndicator(color: AppColors.darkGold),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isEmailChange
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: _backToLogin,
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.darkGold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.darkGold.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.mark_email_unread_rounded,
                        color: AppColors.darkGold,
                        size: 44,
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.04, 1.04),
                    duration: 1800.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 28),
              Text(
                _title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),
              Text(
                _description,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.darkGold.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: AppColors.darkGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'code_sent_to'.tr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            _email.isEmpty
                                ? '---'
                                : MaskUtils.maskEmail(_email),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),
              if (!_isEmailChange)
                Center(
                  child: TextButton.icon(
                    onPressed: _openEmailApp,
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.darkGold,
                      size: 18,
                    ),
                    label: Text(
                      'open_email_app'.tr,
                      style: TextStyle(
                        color: AppColors.darkGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'enter_verification_code'.trParams({'count': '$_otpLength'}),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ).animate().fadeIn(delay: 220.ms),
              const SizedBox(height: 16),
              AuthOtpInput(
                key: _otpKey,
                length: _otpLength,
                enabled: !isBusy,
                onCompleted: _verifyOtpCode,
              ).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 24),
              isBusy
                  ? Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.darkGold),
                          const SizedBox(height: 12),
                          Text(
                            _isRefreshing
                                ? 'verification_checking'.tr
                                : 'verify'.tr,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : KasbyButton(
                      text: 'verify'.tr,
                      onPressed: () =>
                          _verifyOtpCode(_otpKey.currentState?.code ?? ''),
                    ).animate().fadeIn(delay: 280.ms),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: (_resendCountdown > 0 || _isResending || isBusy)
                      ? null
                      : _resendVerification,
                  child: _isResending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.darkGold,
                          ),
                        )
                      : Text(
                          _resendCountdown > 0
                              ? 'resend_cooldown_label'.trParams({
                                  'seconds': '$_resendCountdown',
                                })
                              : 'resend_verification_email'.tr,
                          style: TextStyle(
                            color: _resendCountdown > 0
                                ? Colors.grey
                                : AppColors.darkGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              if (_canPollStatus) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: isBusy ? null : () => _refreshStatus(),
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.darkGold,
                    ),
                    label: Text(
                      'check_verification_status'.tr,
                      style: TextStyle(
                        color: AppColors.darkGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: isBusy ? null : _changeEmail,
                  child: Text(
                    'change_email'.tr,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!_isEmailChange)
                Center(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : _backToLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkGold,
                      side: BorderSide(
                        color: AppColors.darkGold.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text('back_to_login'.tr),
                  ),
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.darkGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _canPollStatus
                            ? 'verify_email_hint'.tr
                            : 'verify_email_enter_code_first'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 320.ms),
            ],
          ),
        ),
      ),
    );
  }
}
