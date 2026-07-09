import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/services/sensitive_operation_guard.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/domain/repositories/authentication_repository.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/utils/mask_utils.dart';
import 'package:kasby/features/auth/presentation/widgets/auth_otp_input.dart';
import 'package:kasby/features/profile/presentation/controllers/profile_update_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpView extends StatefulWidget {
  const OtpView({super.key});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final GlobalKey<AuthOtpInputState> _otpKey = GlobalKey<AuthOtpInputState>();

  bool _isLoading = false;
  bool _isVerified = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;
  int _retryCount = 0;

  final Map<String, dynamic> _args = Get.arguments ?? {};

  String get _identifier =>
      _args['identifier'] ?? AuthController.to.emailController.text.trim();
  OtpType get _otpType => _args['type'] ?? OtpType.sms;
  bool get _isPhone => _args['isPhone'] ?? true;
  bool get _isRecovery => _args['isRecovery'] == true;
  bool get _isFreeOtp => _args['isFreeOtp'] == false ? false : (_args['isFreeOtp'] ?? false);
  bool get _isStepUp => _args['isStepUp'] == true;
  String get _purpose => _args['purpose']?.toString() ?? 'login';

  int get _otpLength {
    final fromArgs = _args['otpLength'];
    if (fromArgs is int && fromArgs > 0) return fromArgs;
    if (_isPhone) return AuthSecurityService.phoneOtpLength;
    if (_isFreeOtp) {
      return AuthOtpConfig.lengthForPurpose(_purpose);
    }
    return AuthOtpConfig.lengthForOtpType(_otpType);
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    SafeGetx.debugTrace(
      className: 'OtpView',
      method: 'initState',
      feature: 'Auth',
      status: 'INFO',
      params: {
        'isPhone': _isPhone,
        'isRecovery': _isRecovery,
        'isStepUp': _isStepUp,
        'otpType': _otpType.name,
        'purpose': _purpose,
        'otpLength': _otpLength,
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCountdown--;
          if (_resendCountdown <= 0) {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;

    try {
      if (_isStepUp) {
        await AuthSecurityService.requestStepUpOtp();
      } else if (_purpose == 'phone_change') {
        await AuthSecurityService.resendPhoneOtp(
          phone: _identifier,
          type: OtpType.phoneChange,
        );
      } else if (_isPhone) {
        await AuthController.to.resendPhoneOtp(
          _identifier,
          type: _otpType,
          purpose: _purpose,
        );
      } else if (_otpType == OtpType.recovery ||
          (_isRecovery && !_isPhone && !_isFreeOtp)) {
        await AuthSecurityService.resendPasswordRecovery(_identifier);
      } else if (_isFreeOtp) {
        if (_isPhone) {
          await AuthController.to.resendPhoneOtp(
            _identifier,
            type: _otpType,
            purpose: _purpose,
          );
        } else if (_isRecovery || _purpose == 'password_reset') {
          await AuthSecurityService.resendPasswordRecovery(_identifier);
        } else if (_purpose == 'signup') {
          await AuthSecurityService.ensureSignupVerificationSent(_identifier);
        } else if (_purpose == 'email_change') {
          await AuthSecurityService.sendProfileChangeOtp(
            target: _identifier,
            targetType: 'email',
            purpose: 'email_change',
          );
        } else {
          await AuthController.to.sendEmailOtp(
            _identifier,
            isRecovery: _isRecovery,
            purpose: _purpose,
          );
        }
      } else {
        await AuthSecurityService.resendOtp(
          email: _identifier,
          type: _otpType,
        );
      }

      _startResendTimer();
      AppSnack.success('success'.tr, 'otp_resend_success'.tr);
      SafeGetx.debugTrace(
        className: 'OtpView',
        method: '_resendOtp',
        feature: 'Auth',
        status: 'INFO',
        message: 'OTP resent',
        params: {'purpose': _purpose},
      );
    } on AuthException catch (e) {
      AppSnack.error('error'.tr, AuthController.to.translateOtpError(e));
    } catch (_) {
      AppSnack.error('error'.tr, 'otp_resend_failed'.tr);
    }
  }

  Future<void> _verifyOtp([String? codeOverride]) async {
    final otp = codeOverride ?? _otpKey.currentState?.code ?? '';
    if (!AuthOtpConfig.isComplete(otp, _otpLength)) {
      AppSnack.error(
        'error'.tr,
        'enter_full_otp'.trParams({'count': '$_otpLength'}),
      );
      return;
    }

    if (_isFreeOtp && !_isPhone) {
      await _verifyFreeOtp(otp);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isStepUp) {
        await AuthSecurityService.verifyStepUpOtp(
          token: otp,
          phone: _identifier,
        );
        SensitiveOperationGuard.markStepUpVerified();
        setState(() => _isVerified = true);
        await Future.delayed(const Duration(milliseconds: 800));
        Get.back(result: true);
        return;
      }

      if (_purpose == 'phone_change') {
        final success = await Get.find<ProfileUpdateController>().verifyAndUpdate(
          type: _purpose,
          newValue: _identifier,
          otpCode: otp,
        );
        if (success) {
          setState(() => _isVerified = true);
          AppSnack.success('success'.tr, 'phone_updated_success'.tr);
          await Future.delayed(const Duration(milliseconds: 600));
          Get.back(result: true);
        }
        return;
      }

      if (_isPhone) {
        if (_isRecovery || _purpose == 'password_reset') {
          await AuthenticationRepository.to.verifyPasswordResetPhoneOtp(
            phone: _identifier,
            code: otp,
          );
          setState(() => _isVerified = true);
          await Future.delayed(const Duration(milliseconds: 400));
          Get.offNamed(
            Routes.changePassword,
            arguments: {
              'isRecovery': true,
              'otpVerified': true,
              'identifier': _identifier,
              'isPhone': true,
            },
          );
          return;
        }

        final success = await AuthController.to.verifyPhoneOtpCode(
          phone: _identifier,
          otp: otp,
          type: _otpType,
          purpose: _purpose,
        );
        if (success) {
          setState(() => _isVerified = true);
        } else {
          _otpKey.currentState?.clear();
        }
        return;
      }

      await AuthSecurityService.verifyOtpCode(
        email: _identifier,
        token: otp,
        type: _otpType,
      );

      if (_otpType == OtpType.recovery) {
        AppSnack.success('success'.tr, 'otp_verified_success'.tr);
        Get.offNamed(
          Routes.changePassword,
          arguments: {'isRecovery': true},
        );
      } else if (_otpType == OtpType.signup) {
        AuthController.to.authStatus.value = AuthStatus.authenticated;
        await AuthSecurityService.refreshUserProfileState();
        setState(() => _isVerified = true);
        await Future.delayed(const Duration(milliseconds: 600));
        Get.offAllNamed(Routes.home);
      }
    } on AuthException catch (e) {
      AppSnack.error('error'.tr, AuthController.to.translateOtpError(e));
      _otpKey.currentState?.clear();
      if (_retryCount < 2 && mounted) {
        _retryCount++;
      }
    } catch (_) {
      AppSnack.error('error'.tr, 'invalid_otp'.tr);
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyFreeOtp(String otp) async {
    if (_isRecovery || _purpose == 'password_reset') {
      setState(() => _isLoading = true);
      try {
        if (_isPhone) {
          await AuthenticationRepository.to.verifyPasswordResetPhoneOtp(
            phone: _identifier,
            code: otp,
          );
        } else {
          await AuthenticationRepository.to.verifyPasswordResetEmailOtp(
            email: _identifier,
            code: otp,
          );
        }
        setState(() => _isVerified = true);
        await Future.delayed(const Duration(milliseconds: 400));
        Get.offNamed(
          Routes.changePassword,
          arguments: {
            'isRecovery': true,
            'otpVerified': true,
            'identifier': _identifier,
            'isPhone': _isPhone,
          },
        );
      } on AuthException catch (e) {
        AppSnack.error('error'.tr, AuthController.to.translateOtpError(e));
        _otpKey.currentState?.clear();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (_purpose == 'email_change') {
      final success = await Get.find<ProfileUpdateController>().verifyAndUpdate(
        type: _purpose,
        newValue: _identifier,
        otpCode: otp,
      );
      if (success) {
        Get.back(result: true);
        Get.back();
      }
      return;
    }

    await AuthController.to.verifyPhoneOtpCode(
      phone: _identifier,
      otp: otp,
      purpose: _purpose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Get.back(result: false),
        ),
        title: Text(
          _isRecovery
              ? 'reset_password'.tr
              : _isStepUp
                  ? 'security_verification'.tr
                  : 'otp_verification'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: 300.ms,
                        child: _isVerified
                            ? Container(
                                key: const ValueKey('success'),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.softGreen.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.softGreen,
                                  size: 48,
                                ),
                              ).animate().scale(curve: Curves.elasticOut)
                            : Container(
                                key: const ValueKey('lock'),
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
                                  Icons.sms_rounded,
                                  color: AppColors.darkGold,
                                  size: 40,
                                ),
                              ).animate().scale(curve: Curves.easeOutBack),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isVerified
                            ? 'otp_verified_success'.tr
                            : 'verify_otp_title'.tr,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (!_isVerified) ...[
                        const SizedBox(height: 12),
                    Text(
                      '${'code_sent_to'.tr}\n${MaskUtils.maskIdentifier(value: _identifier, isPhone: _isPhone)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'enter_verification_code'.trParams({'count': '$_otpLength'}),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_isVerified) ...[
                  const SizedBox(height: 48),
                  AuthOtpInput(
                    key: _otpKey,
                    length: _otpLength,
                    enabled: !_isLoading,
                    enableSmsAutofill: _isPhone,
                    onCompleted: _verifyOtp,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'didnt_receive_code'.tr,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _canResend && !_isLoading ? _resendOtp : null,
                          child: Text(
                            _canResend
                                ? 'resend_code'.tr
                                : '${'resend_code'.tr} (${_resendCountdown.toString().padLeft(2, '0')}s)',
                            style: TextStyle(
                              color: _canResend
                                  ? AppColors.darkGold
                                  : (isDark ? Colors.white24 : Colors.black26),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: AppColors.darkGold),
                        )
                      : KasbyButton(
                          text: 'verify'.tr,
                          onPressed: () => _verifyOtp(),
                        ).animate().fadeIn(delay: 300.ms),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
