import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/widgets/password_strength_meter.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/auth/presentation/widgets/kasby_intl_phone_field.dart';
import 'package:kasby/features/auth/presentation/widgets/referral_code_formatter.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  @override
  Widget build(BuildContext context) {
    final controller = AuthController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: controller.registerFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'create_account'.tr,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'register_desc'.tr,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                KasbyTextField(
                  label: 'full_name'.tr,
                  hint: 'enter_full_name'.tr,
                  controller: controller.nameController,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.darkGold,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'fill_all_data'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                KasbyTextField(
                  label: 'email_address'.tr,
                  hint: 'enter_email_hint'.tr,
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    color: AppColors.darkGold,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'fill_all_data'.tr;
                    }
                    if (!GetUtils.isEmail(value.trim())) {
                      return 'invalid_email'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                KasbyIntlPhoneField(
                  initialCountryCode: controller.registerCountryCode.value,
                  onChanged: controller.updateRegisterPhone,
                  validator: (phone) {
                    if (phone == null || phone.number.trim().isEmpty) {
                      return 'fill_all_data'.tr;
                    }
                    try {
                      if (!phone.isValidNumber()) {
                        return 'invalid_phone'.tr;
                      }
                    } catch (_) {
                      return 'invalid_phone'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                KasbyTextField(
                  label: 'password'.tr,
                  hint: 'create_strong_password'.tr,
                  isPassword: true,
                  controller: controller.passwordController,
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.darkGold,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'fill_all_data'.tr;
                    if (value.length < 8) return 'weak_password'.tr;
                    return null;
                  },
                ),
                PasswordStrengthMeter(controller: controller.passwordController),
                const SizedBox(height: 20),
                KasbyTextField(
                  label: 'confirm_password'.tr,
                  hint: 'confirm_password_hint'.tr,
                  isPassword: true,
                  controller: controller.confirmPasswordController,
                  prefixIcon: Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.darkGold,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'fill_all_data'.tr;
                    if (value != controller.passwordController.text) {
                      return 'passwords_dont_match'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                KasbyTextField(
                  label: 'referral_code_optional'.tr,
                  hint: 'KXXXXXX',
                  controller: controller.referralCodeController,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  inputFormatters: const [ReferralCodeFormatter()],
                  prefixIcon: Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.darkGold,
                  ),
                  suffixIcon: Obx(() => _buildReferralStatus(controller)),
                ),
                const SizedBox(height: 24),
                Obx(
                  () => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: controller.termsAccepted.value,
                        onChanged: controller.toggleTerms,
                        activeColor: AppColors.darkGold,
                        side: BorderSide(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLight,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(text: '${'i_agree_to'.tr} '),
                              TextSpan(
                                text: 'terms_conditions'.tr,
                                style: TextStyle(
                                  color: AppColors.darkGold,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => controller.goToLegal(initialTab: 0),
                              ),
                              TextSpan(text: ' ${'and'.tr} '),
                              TextSpan(
                                text: 'privacy_policy'.tr,
                                style: TextStyle(
                                  color: AppColors.darkGold,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => controller.goToLegal(initialTab: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // const SizedBox(height: 24),
                // _buildNextSteps(context, isDark),
                const SizedBox(height: 24),
                Obx(
                  () => controller.isLoading.value
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.darkGold,
                          ),
                        )
                      : KasbyButton(
                          text: 'register'.tr,
                          onPressed: controller.termsAccepted.value
                              ? controller.register
                              : null,
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'already_have_account'.tr,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'login'.tr,
                        style: TextStyle(
                          color: AppColors.darkGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildNextSteps(BuildContext context, bool isDark) {
  //   final steps = [
  //     'register_step_verify'.tr,
  //     'register_step_activate'.tr,
  //     'register_step_start'.tr,
  //   ];
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: isDark
  //           ? Colors.white.withValues(alpha: 0.04)
  //           : AppColors.darkGold.withValues(alpha: 0.06),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(
  //         color: AppColors.darkGold.withValues(alpha: 0.15),
  //       ),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'register_next_steps_title'.tr,
  //           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
  //         ),
  //         const SizedBox(height: 12),
  //         ...steps.asMap().entries.map((e) {
  //           return Padding(
  //             padding: const EdgeInsets.only(bottom: 8),
  //             child: Row(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 CircleAvatar(
  //                   radius: 12,
  //                   backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
  //                   child: Text(
  //                     '${e.key + 1}',
  //                     style: TextStyle(
  //                       color: AppColors.darkGold,
  //                       fontSize: 11,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 10),
  //                 Expanded(
  //                   child: Text(
  //                     e.value,
  //                     style: TextStyle(
  //                       fontSize: 13,
  //                       height: 1.4,
  //                       color: isDark
  //                           ? AppColors.textSecondary
  //                           : AppColors.textSecondaryLight,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           );
  //         }),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildReferralStatus(AuthController controller) {
    if (controller.isCheckingReferral.value) {
      return SizedBox(
        width: 20,
        height: 20,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.darkGold,
          ),
        ),
      );
    }

    if (controller.referralCodeValid.value == null) {
      return const SizedBox.shrink();
    }

    return Icon(
      controller.referralCodeValid.value!
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      color: controller.referralCodeValid.value!
          ? AppColors.softGreen
          : AppColors.error,
    );
  }
}
