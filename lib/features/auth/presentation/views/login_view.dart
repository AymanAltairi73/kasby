import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';

import 'package:kasby/routes/app_routes.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
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
                ),
              ),
              const SizedBox(height: 48),

              // Email or Phone Input
              KasbyTextField(
                label: 'email_or_phone'.tr,
                hint: 'enter_email_phone'.tr,
                controller: controller.phoneController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.darkGold,
                ),
              ),

              const SizedBox(height: 24),
              KasbyTextField(
                label: 'password'.tr,
                hint: 'enter_password'.tr,
                isPassword: true,
                controller: controller.passwordController,
                prefixIcon: Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.darkGold,
                ),
              ),
              const SizedBox(height: 12),

              // Remember Me & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Remember Me
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

                  // Forgot Password
                  TextButton(
                    onPressed: () {
                      debugPrint('[VIEW] LoginView: Forgot Password pressed');
                      Get.toNamed(Routes.forgotPassword);
                    },
                    child: Text(
                      'forgot_password'.tr,
                      style: TextStyle(color: AppColors.darkGold),
                    ),
                  ),
                ],
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
                        text: 'login'.tr,
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            controller.login(skipFormValidation: true);
                          }
                        },
                      ),
              ),

              const SizedBox(height: 24),
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
                    onPressed: () {
                      debugPrint(
                        '[VIEW] LoginView: Navigate to Register pressed',
                      );
                      Get.toNamed(Routes.register);
                    },
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
    );
  }
}
