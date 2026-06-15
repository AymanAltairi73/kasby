import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/auth/presentation/widgets/country_selector.dart';
import 'package:kasby/features/auth/presentation/widgets/referral_code_formatter.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final controller = AuthController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
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
                ),
              ),
              const SizedBox(height: 32),

              // Full Name
              KasbyTextField(
                label: 'full_name'.tr,
                hint: 'enter_full_name'.tr,
                controller: controller.nameController,
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.darkGold,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'fill_all_data'.tr;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Email
              KasbyTextField(
                label: 'email_address'.tr,
                hint: 'enter_email_hint'.tr,
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icon(
                  Icons.alternate_email_rounded,
                  color: AppColors.darkGold,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'fill_all_data'.tr;
                  if (!GetUtils.isEmail(value.trim())) return 'invalid_email'.tr;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Phone Input with Integrated Country Selector
              KasbyTextField(
                label: 'phone_number'.tr,
                hint: 'enter_phone_hint'.tr,
                controller: controller.phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Obx(
                  () => CountrySelector(
                    selectedCountry: controller.selectedCountry.value,
                    onSelect: controller.updateCountry,
                    showBackground: false,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'fill_all_data'.tr;
                  }
                  if (value.trim().length < 6) return 'invalid_phone'.tr;
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Password
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
                  if (value.length < 6) return 'weak_password'.tr;
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Referral Code (Optional)
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

              // Terms & Conditions
              Obx(
                () => Row(
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
                                ..onTap = controller.goToLegal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

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
                            ? () {
                                if (_formKey.currentState?.validate() ?? false) {
                                  controller.register(skipFormValidation: true);
                                }
                              }
                            : null,
                        // Disable button style if needed? KasbyButton might not handle null logic visually unless I check.
                        // KasbyButton usually takes onPressed. If null, it might not look disabled.
                        // Let's check KasbyButton.
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
                    onPressed: () {
                      debugPrint(
                        '[VIEW] RegisterView: Navigate back to Login pressed',
                      );
                      Get.back();
                    },
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
    );
  }

  Widget _buildReferralStatus(AuthController controller) {
    if (controller.isCheckingReferral.value) {
      return SizedBox(
        width: 20,
        height: 20,
        child: Padding(
          padding: EdgeInsets.all(12),
          child:
              CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkGold),
        ),
      );
    }

    if (controller.referralCodeValid.value == null) return const SizedBox.shrink();

    return Icon(
      controller.referralCodeValid.value!
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      color:
          controller.referralCodeValid.value!
              ? AppColors.softGreen
              : AppColors.error,
    );
  }
}
