import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  // Recovery mode check
  bool get _isRecovery =>
      Get.arguments != null && Get.arguments['isRecovery'] == true;

  String get _recoveryIdentifier => Get.arguments?['identifier'] ?? '';
  String get _recoveryOtp => Get.arguments?['otp'] ?? '';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // If recovery, we don't need current password, Supabase session is authorized via recovery link/OTP
      if (_isRecovery) {
        if (_recoveryIdentifier.isNotEmpty && _recoveryOtp.isNotEmpty) {
          await OTPService.to.resetPasswordSecure(
            target: _recoveryIdentifier,
            otpCode: _recoveryOtp,
            newPassword: _newPasswordController.text.trim(),
          );
        } else {
          throw AuthException('بيانات الاستعادة غير مكتملة، يرجى المحاولة مرة أخرى.');
        }
      } else {
        await SupabaseService.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );
      }

      if (mounted) {
        setState(() => _isLoading = false);

        if (_isRecovery) {
          Get.offAllNamed(Routes.login);
        } else {
          Get.back();
        }

        Get.snackbar(
          'success'.tr,
          'password_changed_success'.tr,
          backgroundColor: AppColors.softGreen.withValues(alpha: 0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
          borderRadius: 16,
        );
      }
    }
     on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'error'.tr,
          e.message,
          backgroundColor: AppColors.error.withValues(alpha: 0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
          borderRadius: 16,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'error'.tr,
          'حدث خطأ أثناء تغيير كلمة المرور. حاول مرة أخرى.',
          backgroundColor: AppColors.error.withValues(alpha: 0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
          borderRadius: 16,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isRecovery ? 'reset_password'.tr : 'change_password'.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildHeader(context),
              const SizedBox(height: 40),
              _buildInputFields(context),
              const SizedBox(height: 48),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: Colors.purpleAccent,
            size: 32,
          ),
        ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text(
          _isRecovery ? 'reset_password'.tr : 'change_password'.tr,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
        const SizedBox(height: 8),
        Text(
          _isRecovery
              ? 'enter_new_password_desc'.tr
              : 'update_your_security'.tr,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildInputFields(BuildContext context) {
    return Column(
      children: [
        if (!_isRecovery) ...[
          _buildInputField(
            context: context,
            label: 'current_password'.tr,
            controller: _currentPasswordController,
            hint: 'enter_current_password'.tr,
            isPassword: true,
          ),
          const SizedBox(height: 24),
        ],
        _buildInputField(
          context: context,
          label: 'new_password'.tr,
          controller: _newPasswordController,
          hint: 'enter_new_password'.tr,
          isPassword: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'fill_all_data'.tr;
            }
            if (value.length < 6) {
              return 'password_too_short'.tr;
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        _buildInputField(
          context: context,
          label: 'confirm_new_password'.tr,
          controller: _confirmPasswordController,
          hint: 'confirm_new_password'.tr,
          isPassword: true,
          validator: (value) {
            if (value != _newPasswordController.text) {
              return 'passwords_dont_match'.tr;
            }
            return null;
          },
        ),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05);
  }

  Widget _buildInputField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: KasbyTextField(
            controller: controller,
            hint: hint,
            isPassword: isPassword,
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: AppColors.darkGold,
              size: 22,
            ),
            validator:
                validator ??
                (value) {
                  if (value == null || value.isEmpty) {
                    return 'fill_all_data'.tr;
                  }
                  return null;
                },
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return _isLoading
        ? Center(
            child: CircularProgressIndicator(color: AppColors.darkGold),
          )
        : KasbyButton(
            text: 'save_changes'.tr,
            onPressed: _changePassword,
          ).animate().fadeIn(delay: 700.ms).scale();
  }
}
