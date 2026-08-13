import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/presentation/widgets/auth_otp_input.dart';
import 'package:kasby/features/auth/presentation/widgets/kasby_intl_phone_field.dart';
import 'package:kasby/features/profile/presentation/controllers/profile_update_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/utils/country_data.dart';

class ProfileUpdateView extends StatefulWidget {
  final Map<String, dynamic>? embeddedArguments;

  const ProfileUpdateView({super.key, this.embeddedArguments});

  @override
  State<ProfileUpdateView> createState() => _ProfileUpdateViewState();
}

class _ProfileUpdateViewState extends State<ProfileUpdateView> {
  late final String type;
  late final String currentValue;
  late final TextEditingController inputController;
  late final TextEditingController passwordController;
  final GlobalKey<AuthOtpInputState> _otpKey = GlobalKey<AuthOtpInputState>();
  final RxInt currentStep = 0.obs;
  String? initialCountryCode;
  String? currentCompletePhone;

  bool get isEmailChange => type == 'email_change';
  String get label => isEmailChange ? 'new_email'.tr : 'new_phone'.tr;

  bool get _isEmbedded => widget.embeddedArguments != null;

  @override
  void initState() {
    super.initState();
    final args =
        widget.embeddedArguments ??
        (Get.arguments as Map<String, dynamic>? ?? {});
    type = args['type'] ?? 'email_change';
    currentValue = args['current_value'] ?? '';

    inputController = TextEditingController();
    passwordController = TextEditingController();

    if (!isEmailChange && currentValue.isNotEmpty) {
      final country = CountryData.countryForPhone(currentValue);
      initialCountryCode = country.code;
      currentCompletePhone = currentValue;
      inputController.text = CountryData.stripDialCode(currentValue, country);
    }

    SafeGetx.debugTrace(
      className: 'ProfileUpdateView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
      params: {'type': type},
    );
  }

  @override
  void dispose() {
    inputController.dispose();
    passwordController.dispose();
    SafeGetx.debugTrace(
      className: 'ProfileUpdateView',
      method: 'dispose',
      feature: 'Profile',
      status: 'INFO',
    );
    super.dispose();
  }

  String _buildTargetValue() {
    if (isEmailChange) {
      return inputController.text.trim();
    }
    return currentCompletePhone?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileCtrl = ProfileUpdateController.to;

    final content = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.darkGold.withValues(alpha: 0.10),
                      AppColors.darkGold.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.darkGold.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.darkGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        color: AppColors.darkGold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'security_notice'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
              const SizedBox(height: 10),
              _buildStepIndicator(
                currentStep.value,
                isDark,
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
              const SizedBox(height: 15),
              if (currentStep.value == 0) ...[
                Text(
                  'verify_password'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 6),
                Text(
                  'enter_current_password_to_verify'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 10),
                KasbyTextField(
                  key: const ValueKey('profile_update_password'),
                  controller: passwordController,
                  hint: 'current_password'.tr,
                  isPassword: true,
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.darkGold,
                  ),
                ),
                const SizedBox(height: 10),
                profileCtrl.isVerifyingPassword.value
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : KasbyButton(
                        text: 'verify_password'.tr,
                        onPressed: () async {
                          final success = await profileCtrl.verifyPassword(
                            passwordController.text,
                          );
                          if (success) {
                            currentStep.value = 1;
                          }
                        },
                      ).animate().fadeIn(delay: 200.ms),
              ] else if (currentStep.value == 1) ...[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 10),
                Text(
                  isEmailChange
                      ? 'enter_new_email_desc'.tr
                      : 'enter_new_phone_desc'.tr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 10),
                if (isEmailChange)
                  KasbyTextField(
                    key: const ValueKey('profile_update_email'),
                    controller: inputController,
                    hint: label,
                    isPassword: false,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: AppColors.darkGold,
                    ),
                  )
                else
                  KasbyIntlPhoneField(
                    key: const ValueKey('profile_update_phone'),
                    initialCountryCode: initialCountryCode ?? 'YE',
                    initialValue: inputController.text,
                    showLabel: false,
                    onChanged: (completeNumber, countryCode) {
                      currentCompletePhone = completeNumber;
                    },
                  ),
                const SizedBox(height: 10),
                KasbyButton(
                  text: 'next'.tr,
                  onPressed: () async {
                    final newValue = _buildTargetValue();
                    final success = await profileCtrl.sendUpdateOtp(
                      target: newValue,
                      type: type,
                      currentValue: currentValue,
                    );
                    if (success) {
                      currentStep.value = 2;
                    }
                  },
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => currentStep.value = 0,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    label: Text(
                      'back'.tr,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ] else if (currentStep.value == 2) ...[
                // ─── Unified OTP verification step ───
                Text(
                  isEmailChange
                      ? 'email_change_pending_title'.tr
                      : 'verify_otp_title'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 6),
                Text(
                  isEmailChange
                      ? 'email_change_pending_desc'.trParams({
                          'target': _buildTargetValue(),
                        })
                      : 'otp_sent_to'.trParams({'target': _buildTargetValue()}),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                if (!isEmailChange) ...[
                  const SizedBox(height: 4),
                  Text(
                    'otp_sent_notification'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ],
                const SizedBox(height: 12),

                // // ─── OTP expiry countdown ───
                // if (profileCtrl.otpExpiryCountdown.value > 0 ||
                //     profileCtrl.otpExpired.value)
                //   Center(
                //     child: Container(
                //       padding: const EdgeInsets.symmetric(
                //         horizontal: 16,
                //         vertical: 10,
                //       ),
                //       decoration: BoxDecoration(
                //         color: profileCtrl.otpExpired.value
                //             ? Colors.red.withValues(alpha: 0.08)
                //             : AppColors.darkGold.withValues(alpha: 0.08),
                //         borderRadius: BorderRadius.circular(12),
                //         border: Border.all(
                //           color: profileCtrl.otpExpired.value
                //               ? Colors.red.withValues(alpha: 0.2)
                //               : AppColors.darkGold.withValues(alpha: 0.15),
                //         ),
                //       ),
                //       child: Row(
                //         mainAxisSize: MainAxisSize.min,
                //         children: [
                //           Icon(
                //             profileCtrl.otpExpired.value
                //                 ? Icons.timer_off_rounded
                //                 : Icons.timer_outlined,
                //             size: 18,
                //             color: profileCtrl.otpExpired.value
                //                 ? Colors.red
                //                 : AppColors.darkGold,
                //           ),
                //           const SizedBox(width: 8),
                //           Text(
                //             profileCtrl.otpExpired.value
                //                 ? 'otp_has_expired'.tr
                //                 : '${'otp_expires_in'.tr} ${profileCtrl.formattedExpiry}',
                //             style: TextStyle(
                //               fontSize: 13,
                //               fontWeight: FontWeight.w600,
                //               color: profileCtrl.otpExpired.value
                //                   ? Colors.red
                //                   : AppColors.darkGold,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ).animate().fadeIn(delay: 180.ms),
                const SizedBox(height: 20),

                // ─── 6-box OTP input ───
                AuthOtpInput(
                  key: _otpKey,
                  length: AuthOtpConfig.lengthForPurpose(
                    isEmailChange ? 'email_change' : 'phone_change',
                  ),
                  enabled:
                      !profileCtrl.isLoading.value &&
                      !profileCtrl.otpExpired.value,
                  onCompleted: (code) async {
                    final success = await profileCtrl.verifyAndUpdate(
                      type: type,
                      newValue: _buildTargetValue(),
                      otpCode: code,
                    );
                    if (success) {
                      profileCtrl.resetFlow();
                      if (_isEmbedded && context.mounted) {
                        Navigator.of(context).pop();
                      } else {
                        Get.offNamed(Routes.personalProfile);
                      }
                    } else {
                      _otpKey.currentState?.clear();
                    }
                  },
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 24),

                // ─── Verify button ───
                profileCtrl.isLoading.value
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : KasbyButton(
                        text: 'verify'.tr,
                        onPressed: profileCtrl.otpExpired.value
                            ? null
                            : () async {
                                final code = _otpKey.currentState?.code ?? '';
                                if (code.isEmpty) return;
                                final success = await profileCtrl
                                    .verifyAndUpdate(
                                      type: type,
                                      newValue: _buildTargetValue(),
                                      otpCode: code,
                                    );
                                if (success) {
                                  profileCtrl.resetFlow();
                                  if (_isEmbedded && context.mounted) {
                                    Navigator.of(context).pop();
                                  } else {
                                    Get.offNamed(Routes.personalProfile);
                                  }
                                } else {
                                  _otpKey.currentState?.clear();
                                }
                              },
                      ).animate().fadeIn(delay: 280.ms),

                const SizedBox(height: 20),

                // ─── Resend OTP button ───
                Center(
                  child: TextButton(
                    onPressed:
                        profileCtrl.resendTimer.value > 0 ||
                            profileCtrl.isLoading.value
                        ? null
                        : () async {
                            await profileCtrl.resendUpdateOtp();
                            _otpKey.currentState?.clear();
                          },
                    child: Text(
                      profileCtrl.resendTimer.value > 0
                          ? '${'resend_code'.tr} (${profileCtrl.resendTimer.value}s)'
                          : 'resend_code'.tr,
                      style: TextStyle(
                        color: profileCtrl.resendTimer.value > 0
                            ? Colors.grey
                            : AppColors.darkGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // // ─── Check verification status (email only) ───
                // if (isEmailChange) ...[
                //   const SizedBox(height: 4),
                //   Center(
                //     child: TextButton.icon(
                //       onPressed: profileCtrl.isLoading.value
                //           ? null
                //           : () async {
                //               final success = await profileCtrl
                //                   .checkEmailChangeComplete(
                //                     _buildTargetValue(),
                //                   );
                //               if (success) {
                //                 profileCtrl.resetFlow();
                //                 if (_isEmbedded && context.mounted) {
                //                   Navigator.of(context).pop();
                //                 } else {
                //                   Get.offNamed(Routes.personalProfile);
                //                 }
                //               } else {
                //                 AppSnack.warning(
                //                   'change_email'.tr,
                //                   'email_not_verified_yet'.tr,
                //                 );
                //               }
                //             },
                //       icon: Icon(
                //         Icons.refresh_rounded,
                //         size: 18,
                //         color: AppColors.darkGold,
                //       ),
                //       label: Text(
                //         'check_verification_status'.tr,
                //         style: TextStyle(
                //           color: AppColors.darkGold,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //     ),
                //   ),
                //],
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => currentStep.value = 1,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    label: Text(
                      'back'.tr,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (_isEmbedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEmailChange ? 'change_email'.tr : 'change_phone'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  tooltip: 'close'.tr,
                  onPressed: () {
                    profileCtrl.resetFlow();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            profileCtrl.resetFlow();
            Get.back();
          },
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          tooltip: 'back'.tr,
        ),
        title: Text(
          isEmailChange ? 'change_email'.tr : 'change_phone'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _buildStepIndicator(int currentStep, bool isDark) {
    final steps = [
      {'icon': Icons.lock_rounded, 'label': 'step_password'.tr},
      {'icon': Icons.edit_rounded, 'label': 'step_new_value'.tr},
      {'icon': Icons.verified_rounded, 'label': 'step_verification'.tr},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;
        final step = steps[index];

        return Row(
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.darkGold
                        : isActive
                        ? AppColors.darkGold.withValues(alpha: 0.15)
                        : isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    border: Border.all(
                      color: isActive || isCompleted
                          ? AppColors.darkGold
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_rounded
                        : step['icon'] as IconData,
                    size: 18,
                    color: isCompleted
                        ? Colors.black
                        : isActive
                        ? AppColors.darkGold
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive || isCompleted
                        ? AppColors.darkGold
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (index < steps.length - 1)
              Container(
                width: 48,
                height: 2,
                margin: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.darkGold
                      : isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        );
      }),
    );
  }
}
