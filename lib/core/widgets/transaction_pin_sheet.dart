import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/auth/presentation/widgets/auth_otp_input.dart';
import 'package:kasby/core/services/transaction_auth_service.dart';

/// Modal 6-digit transaction PIN entry (setup, confirm, or verify).
class TransactionPinSheet {
  TransactionPinSheet._();

  static Future<String?> show({
    required String title,
    required String subtitle,
  }) async {
    return Get.bottomSheet<String>(
      _TransactionPinSheetBody(title: title, subtitle: subtitle),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
    );
  }
}

class _TransactionPinSheetBody extends StatefulWidget {
  const _TransactionPinSheetBody({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<_TransactionPinSheetBody> createState() => _TransactionPinSheetBodyState();
}

class _TransactionPinSheetBodyState extends State<_TransactionPinSheetBody> {
  final _pinKey = GlobalKey<AuthOtpInputState>();
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: AppColors.darkGold, size: 40),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AuthOtpInput(
                key: _pinKey,
                length: TransactionAuthService.pinLength,
                onChanged: (v) => setState(() => _pin = v),
                onCompleted: (v) => Get.back(result: v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back<String>(),
                      child: Text('cancel'.tr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KasbyButton(
                      text: 'confirm'.tr,
                      onPressed: _pin.length == TransactionAuthService.pinLength
                          ? () => Get.back(result: _pin)
                          : null,
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
