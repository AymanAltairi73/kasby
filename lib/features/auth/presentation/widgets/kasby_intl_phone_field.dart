import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field_continued/intl_phone_field.dart';
import 'package:intl_phone_field_continued/phone_number.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// Kasby-styled international phone input with country selector, flag,
/// dial code, formatting, masking, and per-country validation.
/// Enterprise-grade UI with integrated country code like WhatsApp/Telegram.
class KasbyIntlPhoneField extends StatelessWidget {
  final String? initialCountryCode;
  final String? initialValue;
  final void Function(String completeNumber, String countryCode)? onChanged;
  final String? Function(PhoneNumber? phone)? validator;
  final bool enabled;
  final bool showLabel;

  const KasbyIntlPhoneField({
    super.key,
    this.initialCountryCode = 'YE',
    this.initialValue,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
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
        if (showLabel) const SizedBox(height: 8),
        IntlPhoneField(
          dropdownIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          initialCountryCode: initialCountryCode ?? 'YE',
          initialValue: initialValue,
          enabled: enabled,
          disableLengthCheck: false,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          languageCode: Get.locale?.languageCode ?? 'en',
          dropdownTextStyle: TextStyle(
            color: onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
         
          flagsButtonPadding: const EdgeInsets.only(left: 12),
          showCountryFlag: true,
          showDropdownIcon: true,
          decoration: InputDecoration(
            hintText: 'enter_phone_hint'.tr,
            hintStyle: TextStyle(
              color: onSurface.withValues(alpha: 0.55),
              fontSize: 16,
            ),
            filled: true,
            fillColor: surface,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.darkGold,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
          style: TextStyle(
            color: onSurface,
            fontSize: 16,
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
