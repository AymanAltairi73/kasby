import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
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
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;

  final Map<String, dynamic> _args = Get.arguments ?? {};

  String get _identifier =>
      _args['identifier'] ?? AuthController.to.emailController.text.trim();
  OtpType get _otpType => _args['type'] ?? OtpType.signup;
  bool get _isPhone => _args['isPhone'] ?? false;
  bool get _isRecovery => _args['isRecovery'] == true;
  bool get _isFreeOtp => _args['isFreeOtp'] == true;

  int get _otpLength {
    final fromArgs = _args['otpLength'];
    if (fromArgs is int && fromArgs > 0) return fromArgs;
    if (_isFreeOtp) {
      return AuthOtpConfig.lengthForPurpose(
        _args['purpose']?.toString() ?? 'verification',
      );
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
        'otpType': _otpType.name,
        'otpLength': _otpLength,
      },
    );

    if (_isFreeOtp) {
      ever(FCMService.to.lastOtpCode, (String? otp) {
        if (otp != null &&
            AuthOtpConfig.isComplete(otp, _otpLength) &&
            mounted) {
          _otpKey.currentState?.fillCode(otp);
        }
      });
    }
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
      if (_isFreeOtp) {
        if (_isPhone) {
          await AuthController.to.sendPhoneOtp(
            _identifier,
            isRecovery: _isRecovery,
            purpose: _isRecovery ? 'password_reset' : 'verification',
          );
        } else {
          await AuthController.to.sendEmailOtp(
            _identifier,
            isRecovery: _isRecovery,
            purpose: _isRecovery ? 'password_reset' : 'verification',
          );
        }
      } else if (_otpType == OtpType.recovery) {
        await AuthSecurityService.resendPasswordRecovery(_identifier);
      } else if (_isPhone) {
        await SupabaseService.auth.signInWithOtp(
          phone: _identifier,
          shouldCreateUser: false,
        );
      } else {
        await AuthSecurityService.resendOtp(
          email: _identifier,
          type: _otpType,
        );
      }

      _startResendTimer();
      AppSnack.success('success'.tr, 'otp_resend_success'.tr);
    } on AuthException catch (e) {
      AppSnack.error(
        'error'.tr,
        AuthController.to.translateOtpError(e),
      );
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

    if (_isFreeOtp) {
      final purpose = _args['purpose'] ?? 'verification';

      if (_isRecovery || purpose == 'password_reset') {
        Get.toNamed(
          Routes.changePassword,
          arguments: {
            'isRecovery': true,
            'identifier': _identifier,
            'otp': otp,
          },
        );
        return;
      }

      if (purpose == 'email_change' || purpose == 'phone_change') {
        final success =
            await Get.find<ProfileUpdateController>().verifyAndUpdate(
          type: purpose,
          newValue: _identifier,
          otpCode: otp,
        );
        if (success) {
          Get.back();
          Get.back();
        }
        return;
      }

      await AuthController.to.verifyPhoneOtp(
        _identifier,
        otp,
        targetType: _isPhone ? 'phone' : 'email',
        purpose: purpose,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isPhone) {
        await SupabaseService.auth.verifyOTP(
          type: _otpType,
          token: AuthOtpConfig.normalize(otp),
          phone: _identifier,
        );
      } else {
        await AuthSecurityService.verifyOtpCode(
          email: _identifier,
          token: otp,
          type: _otpType,
        );
      }

      if (_otpType == OtpType.recovery) {
        AppSnack.success('success'.tr, 'otp_verified_success'.tr);
        Get.offNamed(
          Routes.changePassword,
          arguments: {'isRecovery': true},
        );
      } else if (_otpType == OtpType.signup) {
        AuthController.to.authStatus.value = AuthStatus.authenticated;
        await AuthSecurityService.refreshUserProfileState();
        Get.offAllNamed(Routes.home);
      }
    } on AuthException catch (e) {
      AppSnack.error(
        'error'.tr,
        AuthController.to.translateOtpError(e),
      );
      _otpKey.currentState?.clear();
    } catch (_) {
      AppSnack.error('error'.tr, 'invalid_otp'.tr);
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          onPressed: () => Get.back(),
        ),
        title: Text(
          _isRecovery ? 'reset_password'.tr : 'otp_verification'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
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
                        Icons.security_rounded,
                        color: AppColors.darkGold,
                        size: 40,
                      ),
                    ).animate().scale(curve: Curves.easeOutBack),
                    const SizedBox(height: 24),
                    Text(
                      'verify_otp_title'.tr,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'otp_sent_to'.trParams({'target': _identifier}),
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
                ),
              ),
              const SizedBox(height: 48),
              AuthOtpInput(
                key: _otpKey,
                length: _otpLength,
                enabled: !_isLoading,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
