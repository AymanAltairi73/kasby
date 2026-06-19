import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/features/auth/domain/utils/login_identifier_utils.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/routes/app_routes.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
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
            key: controller.loginFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'welcome_back'.tr,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'sign_in_desc'.tr,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                KasbyTextField(
                  label: 'email_or_phone'.tr,
                  hint: 'enter_email_phone'.tr,
                  controller: controller.loginIdentifierController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.darkGold,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'fill_all_data'.tr;
                    if (LoginIdentifierUtils.isEmail(trimmed)) {
                      if (!GetUtils.isEmail(trimmed)) {
                        return 'invalid_email'.tr;
                      }
                      return null;
                    }
                    if (!LoginIdentifierUtils.isPhone(trimmed)) {
                      return 'invalid_login_identifier'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                KasbyTextField(
                  label: 'password'.tr,
                  hint: 'enter_password'.tr,
                  isPassword: true,
                  controller: controller.passwordController,
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.darkGold,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'fill_all_data'.tr;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => Row(
                        children: [
                          Checkbox(
                            value: controller.rememberMe.value,
                            onChanged: controller.toggleRememberMe,
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
                          Text(
                            'remember_me'.tr,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.toNamed(Routes.forgotPassword),
                      child: Text(
                        'forgot_password'.tr,
                        style: TextStyle(color: AppColors.darkGold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Obx(
                  () => controller.isLoading.value
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.darkGold,
                          ),
                        )
                      : KasbyButton(
                          text: 'login'.tr,
                          onPressed: controller.login,
                        ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'no_account'.tr,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.toNamed(Routes.register),
                      child: Text(
                        'register_now'.tr,
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
}
