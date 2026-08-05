import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/services/biometric_login_service.dart';
import 'package:kasby/features/auth/domain/utils/login_identifier_utils.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/accessibility_utils.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  @override
  Widget build(BuildContext context) {
    final controller = AuthController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final biometric = BiometricLoginService.to;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: controller.loginFormKey,
            autovalidateMode: _autoValidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'welcome_back'.tr,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                Text(
                  'sign_in_desc'.tr,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                Semantics(
                  textField: true,
                  label: 'email_or_phone'.tr,
                  child: KasbyTextField(
                    label: 'email_or_phone'.tr,
                    hint: 'enter_email_phone'.tr,
                    controller: controller.loginIdentifierController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    onChanged: (_) {
                      if (_autoValidate == AutovalidateMode.onUserInteraction) {
                        controller.loginFormKey.currentState?.validate();
                      }
                    },
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
                ),
                const SizedBox(height: 20),
                Semantics(
                  textField: true,
                  label: 'password'.tr,
                  child: KasbyTextField(
                    label: 'password'.tr,
                    hint: 'enter_password'.tr,
                    isPassword: true,
                    controller: controller.passwordController,
                    onChanged: (_) {
                      if (_autoValidate == AutovalidateMode.onUserInteraction) {
                        controller.loginFormKey.currentState?.validate();
                      }
                    },
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.darkGold,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'fill_all_data'.tr;
                      }
                      if (value.length < 8) return 'weak_password'.tr;
                      return null;
                    },
                  ),
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
                      : Semantics(
                          button: true,
                          label: 'login'.tr,
                          child: KasbyButton(
                            text: 'login'.tr,
                            onPressed: () async {
                              setState(
                                () => _autoValidate =
                                    AutovalidateMode.onUserInteraction,
                              );
                              await controller.login();
                              if (controller.isLoggedIn &&
                                  controller.rememberMe.value) {
                                await biometric.enableAfterLogin(
                                  controller.loginIdentifierController.text,
                                );
                              }
                            },
                          ),
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
                const SizedBox(height: 32),
                Obx(() {
                  if (!biometric.isAvailable.value ||
                      !biometric.isEnabled.value) {
                    return const SizedBox.shrink();
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Semantics(
                        button: true,
                        label: 'biometric_login'.tr,
                        child: IconButton(
                          onPressed: () async {
                            final ok = await biometric.attemptBiometricLogin();
                            if (!ok && mounted) {
                              setState(
                                () => _autoValidate =
                                    AutovalidateMode.onUserInteraction,
                              );
                            }
                          },
                          icon: Icon(
                            Icons.fingerprint_rounded,
                            color: AppColors.darkGold,
                            size: 40,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: Size.square(
                              AccessibilityUtils.minTouchTarget,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
