import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/auth/presentation/widgets/country_selector.dart';

class PhoneAuthView extends StatefulWidget {
  const PhoneAuthView({super.key});

  @override
  State<PhoneAuthView> createState() => _PhoneAuthViewState();
}

class _PhoneAuthViewState extends State<PhoneAuthView> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final controller = AuthController.to;
      final fullPhone = '${controller.selectedCountry.value.dialCode}${_phoneController.text.trim()}';
      controller.sendPhoneOtp(fullPhone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = AuthController.to;

    return Scaffold(
      appBar: AppBar(
        title: Text('phone_verification'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'enter_phone_number'.tr,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'phone_verification_desc'.tr,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Obx(() => CountrySelector(
                    selectedCountry: controller.selectedCountry.value,
                    onSelect: controller.updateCountry,
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'enter_phone_hint'.tr;
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '500 000 000',
                        filled: true,
                        fillColor: isDark ? AppColors.surface : AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Obx(() => controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : KasbyButton(
                    text: 'send_code'.tr,
                    onPressed: _submit,
                  )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
