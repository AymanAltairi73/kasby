import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/features/profile/presentation/controllers/profile_update_controller.dart';
import 'package:kasby/routes/app_routes.dart';

class ProfileUpdateView extends StatelessWidget {
  const ProfileUpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final String type = args['type'] ?? 'email_change';
    final String currentValue = args['current_value'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final TextEditingController inputController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController otpController = TextEditingController();
    final RxInt currentStep = 0.obs;
    final String label = type == 'email_change' ? 'new_email'.tr : 'new_phone'.tr;
    final profileCtrl = ProfileUpdateController.to;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
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
        ),
        title: Text(
          type == 'email_change' ? 'change_email'.tr : 'change_phone'.tr,
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
          child: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── SECURITY NOTICE ─────────────────────
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
                      child: Icon(Icons.shield_rounded, color: AppColors.darkGold, size: 22),
                    ),
                    const SizedBox(width: 14),
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
              const SizedBox(height: 28),

              // ─── STEP INDICATOR ──────────────────────
              _buildStepIndicator(currentStep.value, isDark)
                  .animate().fadeIn(duration: 500.ms, delay: 100.ms),
              const SizedBox(height: 32),

              // ─── STEP 1: PASSWORD VERIFICATION (FIRST) ──────
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
                const SizedBox(height: 20),
                KasbyTextField(
                  controller: passwordController,
                  hint: 'current_password'.tr,
                  isPassword: true,
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.darkGold),
                ),
                const SizedBox(height: 32),
                profileCtrl.isVerifyingPassword.value
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
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
                            // Password verified → proceed to enter new value
                            currentStep.value = 1;
                          }
                        },
                      ).animate().fadeIn(delay: 200.ms),
              ]

              // ─── STEP 2: ENTER NEW VALUE ─────────────
              else if (currentStep.value == 1) ...[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 6),
                Text(
                  type == 'email_change'
                      ? 'enter_new_email_desc'.tr
                      : 'enter_new_phone_desc'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 20),
                KasbyTextField(
                  controller: inputController,
                  hint: label,
                  prefixIcon: Icon(
                    type == 'email_change' ? Icons.email_outlined : Icons.phone_android_rounded,
                    color: AppColors.darkGold,
                  ),
                  keyboardType: type == 'email_change'
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                ),
                const SizedBox(height: 32),
                KasbyButton(
                  text: 'next'.tr,
                  onPressed: () async {
                    final newValue = inputController.text.trim();
                    if (newValue.isEmpty || newValue == currentValue) return;
                    
                    // Send OTP to the NEW value
                    await profileCtrl.sendUpdateOtp(
                      target: newValue,
                      type: type,
                    );
                    
                    // If OTP sent successfully (timer started), advance to Step 3
                    if (profileCtrl.resendTimer.value > 0) {
                      currentStep.value = 2;
                    }
                  },
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => currentStep.value = 0,
                    icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                    label: Text(
                      'back'.tr,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ]

              // ─── STEP 3: OTP VERIFICATION ───────────
              else if (currentStep.value == 2) ...[
                Text(
                  'verify_otp_title'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 6),
                Text(
                  'otp_sent_to'.trParams({'target': inputController.text.trim()}),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 4),
                Text(
                  'otp_sent_notification'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 20),
                KasbyTextField(
                  controller: otpController,
                  hint: 'enter_otp'.tr,
                  prefixIcon: Icon(Icons.security_rounded, color: AppColors.darkGold),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 32),
                profileCtrl.isLoading.value
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : KasbyButton(
                        text: 'verify'.tr,
                        onPressed: () async {
                          final success = await profileCtrl.verifyAndUpdate(
                            type: type,
                            newValue: inputController.text.trim(),
                            otpCode: otpController.text.trim(),
                          );
                          if (success) {
                            profileCtrl.resetFlow();
                            // Navigate back to personal profile (controller handles the success message)
                            Get.offNamed(Routes.personalProfile);
                          }
                        },
                      ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 20),
                Center(
                  child: Obx(() => TextButton(
                    onPressed: profileCtrl.resendTimer.value > 0
                        ? null
                        : () => profileCtrl.sendUpdateOtp(
                              target: inputController.text.trim(),
                              type: type,
                            ),
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
                  )),
                ),
              ],
            ],
          )),
        ),
      ),
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
                    isCompleted ? Icons.check_rounded : step['icon'] as IconData,
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
