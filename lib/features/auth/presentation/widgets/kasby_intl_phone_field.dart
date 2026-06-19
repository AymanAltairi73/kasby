import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field_continued/intl_phone_field.dart';
import 'package:intl_phone_field_continued/phone_number.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// Kasby-styled international phone input with country selector, flag,
/// dial code, formatting, masking, and per-country validation.
class KasbyIntlPhoneField extends StatelessWidget {
  final String? initialCountryCode;
  final String? initialValue;
  final void Function(String completeNumber, String countryCode)? onChanged;
  final String? Function(PhoneNumber? phone)? validator;
  final bool enabled;

  const KasbyIntlPhoneField({
    super.key,
    this.initialCountryCode = 'YE',
    this.initialValue,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'phone_number'.tr,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        IntlPhoneField(
          initialCountryCode: initialCountryCode ?? 'YE',
          initialValue: initialValue,
          enabled: enabled,
          disableLengthCheck: false,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          languageCode: Get.locale?.languageCode ?? 'en',
          dropdownTextStyle: TextStyle(color: onSurface),
          dropdownIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          flagsButtonPadding: const EdgeInsets.only(left: 12),
          decoration: InputDecoration(
            hintText: 'enter_phone_hint'.tr,
            hintStyle: TextStyle(
              color: onSurface.withValues(alpha: 0.55),
            ),
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.darkGold,
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: (phone) {
            onChanged?.call(phone.completeNumber, phone.countryISOCode);
          },
          validator: validator,
        ),
      ],
    );
  }
}
