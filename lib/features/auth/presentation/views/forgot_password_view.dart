import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/auth/presentation/widgets/kasby_intl_phone_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _ResetMethod { email, phone }

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  _ResetMethod _method = _ResetMethod.email;
  String _phoneE164 = '';
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_method == _ResetMethod.email) {
        await AuthController.to.sendPasswordResetEmail(
          _emailController.text.trim(),
        );
      } else {
        await AuthController.to.sendPasswordResetPhone(_phoneE164);
      }
    } on AuthException catch (_) {
      // Error surfaced by controller
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidate,
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
                ),
                const SizedBox(height: 12),
                Text(
                  'forgot_password_dual_desc'.tr,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SegmentedButton<_ResetMethod>(
                  segments: [
                    ButtonSegment(
                      value: _ResetMethod.email,
                      label: Text('reset_via_email'.tr),
                      icon: const Icon(Icons.email_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: _ResetMethod.phone,
                      label: Text('reset_via_phone'.tr),
                      icon: const Icon(Icons.phone_android_outlined, size: 18),
                    ),
                  ],
                  selected: {_method},
                  onSelectionChanged: (s) {
                    setState(() => _method = s.first);
                  },
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.black;
                      }
                      return isDark ? Colors.white70 : Colors.black54;
                    }),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.darkGold;
                      }
                      return isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04);
                    }),
                  ),
                ),
                const SizedBox(height: 28),
                if (_method == _ResetMethod.email)
                  KasbyTextField(
                    controller: _emailController,
                    label: 'email_address'.tr,
                    hint: 'enter_email_hint'.tr,
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
                  )
                else
                  KasbyIntlPhoneField(
                    onChanged: (completeNumber, _) {
                      _phoneE164 = completeNumber;
                    },
                    validator: (phone) {
                      if (phone == null || phone.number.trim().isEmpty) {
                        return 'fill_all_data'.tr;
                      }
                      try {
                        if (!phone.isValidNumber()) return 'invalid_phone'.tr;
                      } catch (_) {
                        return 'invalid_phone'.tr;
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 32),
                Obx(
                  () => KasbyButton(
                    text: _method == _ResetMethod.email
                        ? 'send_reset_link'.tr
                        : 'send_reset_code'.tr,
                    isLoading: AuthController.to.isLoading.value,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
