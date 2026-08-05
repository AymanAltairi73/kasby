import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field_continued/countries.dart';
import 'package:intl_phone_field_continued/intl_phone_field.dart';
import 'package:intl_phone_field_continued/phone_number.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// Kasby-styled international phone input with country selector, flag,
/// dial code, formatting, masking, and per-country validation.
/// Enterprise-grade UI with integrated country code like WhatsApp/Telegram.
class KasbyIntlPhoneField extends StatefulWidget {
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
  State<KasbyIntlPhoneField> createState() => _KasbyIntlPhoneFieldState();
}

class _KasbyIntlPhoneFieldState extends State<KasbyIntlPhoneField> {
  String? _currentCountryCode;
  String _hintText = '';

  @override
  void initState() {
    super.initState();
    _currentCountryCode = widget.initialCountryCode ?? 'YE';
    _hintText = _generateHint(_currentCountryCode!);
  }

  /// Generates a dynamic hint based on the country's expected phone number length
  String _generateHint(String countryCode) {
    final country = countries.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => countries.firstWhere((c) => c.code == 'YE'),
    );

    // Get the maximum length for this country's phone number
    final maxLength = country.maxLength;

    // Generate hint with 'x' characters
    return 'x' * maxLength;
  }

  void _onCountryChanged(Country country) {
    if (_currentCountryCode != country.code) {
      setState(() {
        _currentCountryCode = country.code;
        _hintText = _generateHint(country.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel)
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
        if (widget.showLabel) const SizedBox(height: 8),

        Directionality(
          textDirection: TextDirection.ltr,
          child: IntlPhoneField(
            initialCountryCode: widget.initialCountryCode ?? 'YE',
            initialValue: widget.initialValue,
            enabled: widget.enabled,
            languageCode: Get.locale?.languageCode ?? 'ar',

            showCountryFlag: true,
            showDropdownIcon: true,

            dropdownIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
            ),

            //flagsButtonPadding: const EdgeInsets.only(right: 7),
            textAlign: TextAlign.left,

            style: TextStyle(color: onSurface, fontSize: 16),

            dropdownTextStyle: TextStyle(
              color: onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),

            decoration: InputDecoration(
              hintText: _hintText,

              filled: true,
              fillColor: surface,

              counterText: '',

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),

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
                borderSide: const BorderSide(
                  color: AppColors.darkNavy,
                  width: 2,
                ),
              ),

              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.errorDark),
              ),

              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.errorDark,
                  width: 2,
                ),
              ),
            ),

            onChanged: (phone) {
              widget.onChanged?.call(
                phone.completeNumber,
                phone.countryISOCode,
              );
            },

            onCountryChanged: _onCountryChanged,

            validator: widget.validator,
          ),
        ),
      ],
    );
  }
}
