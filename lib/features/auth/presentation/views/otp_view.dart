import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/profile/presentation/controllers/profile_update_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpView extends StatefulWidget {
  const OtpView({super.key});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;

  // Get arguments from navigation
  final Map<String, dynamic> _args = Get.arguments ?? {};

  String get _identifier =>
      _args['identifier'] ?? AuthController.to.emailController.text.trim();
  OtpType get _otpType => _args['type'] ?? OtpType.signup;
  bool get _isPhone => _args['isPhone'] ?? false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    
    // Listen for incoming OTP via FCM
    if (_args['isFreeOtp'] == true) {
      ever(FCMService.to.lastOtpCode, (String? otp) {
        if (otp != null && otp.length == 6 && mounted) {
          for (int i = 0; i < 6; i++) {
            _controllers[i].text = otp[i];
          }
          _verifyOtp();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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
    if (!_canResend) return;

    try {
      debugPrint('[VIEW] OtpView: Resending OTP to $_identifier');
      
      if (_args['isFreeOtp'] == true) {
        if (_isPhone) {
          await AuthController.to.sendPhoneOtp(
            _identifier, 
            isRecovery: _args['isRecovery'] ?? false,
            purpose: _args['isRecovery'] == true ? 'password_reset' : 'verification',
          );
        } else {
          await AuthController.to.sendEmailOtp(
            _identifier,
            purpose: _args['isRecovery'] == true ? 'password_reset' : 'verification',
          );
        }
      } else {
        // Fallback for legacy flows if any remain
        if (_isPhone) {
          await SupabaseService.auth.signInWithOtp(
            phone: _identifier,
            shouldCreateUser: false,
          );
        } else {
          await SupabaseService.auth.resend(type: _otpType, email: _identifier);
        }
      }

      _startResendTimer();
      Get.snackbar(
        'success'.tr,
        'تم إعادة إرسال الرمز بنجاح',
        backgroundColor: AppColors.softGreen.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'فشل إعادة إرسال الرمز. حاول مرة أخرى.',
        backgroundColor: AppColors.error.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      Get.snackbar(
        'error'.tr,
        'الرجاء إدخال رمز التحقق كاملاً',
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    if (_args['isFreeOtp'] == true) {
      final purpose = _args['purpose'] ?? 'verification';
      
      if (_args['isRecovery'] == true || purpose == 'password_reset') {
        debugPrint('[VIEW] OtpView: Custom OTP collected for recovery. Redirecting to ChangePasswordView.');
        Get.toNamed(Routes.changePassword, arguments: {
          'isRecovery': true,
          'identifier': _identifier,
          'otp': otp,
        });
        return;
      }

      if (purpose == 'email_change' || purpose == 'phone_change') {
        debugPrint('[VIEW] OtpView: Custom OTP collected for $purpose. Calling ProfileUpdateController.');
        final success = await Get.find<ProfileUpdateController>().verifyAndUpdate(
          type: purpose,
          newValue: _identifier,
          otpCode: otp,
        );
        if (success) {
          Get.back(); // Close OTP view
          Get.back(); // Close Edit view
        }
        return;
      }

      await AuthController.to.verifyPhoneOtp(_identifier, otp, targetType: _isPhone ? 'phone' : 'email', purpose: purpose);
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint(
        '[VIEW] OtpView: Verifying OTP: $otp for $_identifier ($_otpType)',
      );

      if (_otpType == OtpType.recovery && _isPhone) {
        await AuthController.to.verifyPasswordResetOTP(_identifier, otp);
      } else {
        await SupabaseService.auth.verifyOTP(
          token: otp,
          type: _otpType,
          email: _isPhone ? null : _identifier,
          phone: _isPhone ? _identifier : null,
        );

        if (_otpType == OtpType.signup) {
          Get.offAllNamed(Routes.home);
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint(
          '[VIEW] OtpView ❌ ERROR: OTP Verification failed: ${e.message}',
        );
        Get.snackbar(
          'error'.tr,
          e.message,
          backgroundColor: AppColors.error.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Get.snackbar('error'.tr, 'حدث خطأ أثناء التحقق. حاول مرة أخرى.');
      }
    }
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'otp_verification'.tr,
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
              // ─── SECURITY ICON & TITLE ─────────────
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
                    ),
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
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // ─── OTP INPUT BOXES ───────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 46,
                    height: 58,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        final currentOtp = _controllers.map((c) => c.text).join();
                        if (currentOtp.length == 6) {
                          _verifyOtp();
                        }
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.darkGold, width: 2),
                        ),
                        enabledBorder: _controllers[index].text.isNotEmpty
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.darkGold.withValues(alpha: 0.5)),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ─── RESEND SECTION ────────────────────
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
                      onPressed: _canResend ? _resendOtp : null,
                      child: Text(
                        _canResend
                            ? 'resend_code'.tr
                            : '${'resend_code'.tr} (${_resendCountdown.toString().padLeft(2, '0')}s)',
                        style: TextStyle(
                          color: _canResend
                              ? AppColors.darkGold
                              : (isDark
                                    ? Colors.white24
                                    : Colors.black26),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // ─── VERIFY BUTTON ─────────────────────
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.darkGold),
                    )
                  : KasbyButton(
                      text: 'verify'.tr,
                      onPressed: _verifyOtp,
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
