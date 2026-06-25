import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';

/// Bottom sheet explaining KSP rewards — financial transparency, not gamification.
class KspRewardsExplainer {
  KspRewardsExplainer._();

  static void show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: KasbyRadius.sheetR),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KasbySpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.stars_rounded, color: AppColors.darkGold),
                  const SizedBox(width: KasbySpacing.sm),
                  Expanded(
                    child: Text(
                      'ksp_explainer_title'.tr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: KasbySpacing.lg),
              _section('ksp_what_is'.tr, 'ksp_what_is_desc'.tr, isDark),
              _section('ksp_how_earned'.tr, 'ksp_how_earned_desc'.tr, isDark),
              _section('ksp_how_used'.tr, 'ksp_how_used_desc'.tr, isDark),
              const SizedBox(height: KasbySpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KasbySpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.darkGold.withValues(alpha: 0.08),
                  borderRadius: KasbyRadius.cardR,
                  border: Border.all(
                    color: AppColors.darkGold.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ksp_rate_transparency'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: KasbySpacing.sm),
                    Text(
                      'ksp_daily_cap'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KasbySpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _section(String title, String body, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              height: 1.5,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
