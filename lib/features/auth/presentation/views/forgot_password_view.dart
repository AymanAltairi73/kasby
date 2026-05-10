import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/features/auth/presentation/widgets/country_selector.dart';
import 'package:kasby/core/utils/country_data.dart';
import 'package:kasby/features/auth/domain/models/country_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';

enum ResetMethod { email, phone, none }

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  ResetMethod _selectedMethod = ResetMethod.none;
  Country _selectedCountry = CountryData.defaultCountry;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            debugPrint('[VIEW] ForgotPasswordView: Back button pressed');
            Get.back();
          },
        ),
      ),
      body: AnimatedSwitcher(
        duration: 400.ms,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _selectedMethod == ResetMethod.none
            ? _buildMethodSelection()
            : _buildResetForm(),
      ),
    );
  }

  Widget _buildMethodSelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'forgot_password_title'.tr,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textBodyLight,
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Text(
            'reset_method_desc'.tr,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
              fontSize: 16,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 48),
          _buildMethodCard(
            method: ResetMethod.email,
            title: 'via_email'.tr,
            icon: Icons.alternate_email_rounded,
            delay: 400,
          ),
          const SizedBox(height: 20),
          _buildMethodCard(
            method: ResetMethod.phone,
            title: 'via_phone'.tr,
            icon: Icons.phone_android_rounded,
            delay: 600,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required ResetMethod method,
    required String title,
    required IconData icon,
    required int delay,
  }) {
    return KasbyCard(
      padding: EdgeInsets.zero,
      color: isDark ? AppColors.surface : AppColors.surfaceLight,
      hasShadow: true,
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = method),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.darkGold, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textBodyLight,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildResetForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _selectedMethod = ResetMethod.none),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.darkGold,
            ),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerRight,
          ),
          const SizedBox(height: 20),
          Text(
            _selectedMethod == ResetMethod.email
                ? 'via_email'.tr
                : 'via_phone'.tr,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textBodyLight,
            ),
          ),
          const SizedBox(height: 48),
          if (_selectedMethod == ResetMethod.email)
            KasbyTextField(
              controller: _emailController,
              label: 'email_address'.tr,
              hint: 'enter_email_hint'.tr,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: AppColors.darkGold,
              ),
            )
          else
            KasbyTextField(
              controller: _phoneController,
              label: 'phone_number'.tr,
              hint: 'enter_phone_hint'.tr,
              keyboardType: TextInputType.phone,
              prefixIcon: CountrySelector(
                showBackground: false,
                selectedCountry: _selectedCountry,
                onSelect: (country) =>
                    setState(() => _selectedCountry = country),
              ),
            ),
          const SizedBox(height: 48),
          Obx(
            () => KasbyButton(
              text: 'send_otp'.tr,
              isLoading: AuthController.to.isLoading.value,
              onPressed: () {
                debugPrint(
                  '[VIEW] ForgotPasswordView: Send Reset Link pressed for ${_selectedMethod.name}',
                );
                if (_selectedMethod == ResetMethod.email) {
                  AuthController.to.sendPasswordResetEmail(
                    _emailController.text.trim(),
                  );
                } else if (_selectedMethod == ResetMethod.phone) {
                  final phoneText = _phoneController.text.trim();
                  final fullPhone = '${_selectedCountry.dialCode}$phoneText';
                  AuthController.to.sendPasswordResetOTP(fullPhone);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
