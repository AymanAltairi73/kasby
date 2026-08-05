import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';

/// Inline error state with a retry action for use inside list/detail bodies.
///
/// Standardizes the "silent fetch failure" recovery flow flagged across the
/// investments, KSP, and agents screens (audit item C5).
class ErrorStateWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    this.title,
    this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title ?? 'something_went_wrong'.tr,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KasbySpacing.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(KasbySpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 56, color: AppColors.error),
              ),
              const SizedBox(height: KasbySpacing.xxl),
              Text(
                title ?? 'something_went_wrong'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: KasbySpacing.md),
              Text(
                message ?? 'couldnt_load_data'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: KasbySpacing.xxl),
              KasbyButton(
                text: 'retry'.tr,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                width: 200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
