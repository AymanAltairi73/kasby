import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

/// Single-instance post-registration welcome bottom sheet with guided financial journey steps.
class SmartWelcomeBottomSheet extends StatelessWidget {
  const SmartWelcomeBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await Get.bottomSheet(
      const SmartWelcomeBottomSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final home = Get.isRegistered<HomeController>() ? HomeController.to : null;
    final kycVerified = home?.kycStatus == 'verified';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: AppColors.darkGold.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Welcome Header Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkGold.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'welcome_title'.tr,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            'welcome_desc'.tr,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Steps Checklist
          _buildStepRow(
            context: context,
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.softGreen,
            title: 'step_account_created'.tr,
            subtitle: 'success'.tr,
            isCompleted: true,
          ),
          const SizedBox(height: 12),

          _buildStepRow(
            context: context,
            icon: kycVerified
                ? Icons.check_circle_rounded
                : Icons.verified_user_outlined,
            iconColor: kycVerified ? AppColors.softGreen : AppColors.darkGold,
            title: 'step_verify_kyc'.tr,
            subtitle: kycVerified ? 'verified'.tr : 'insight_complete_kyc'.tr,
            isCompleted: kycVerified,
            onTap: kycVerified
                ? null
                : () {
                    Get.back();
                    Get.toNamed(Routes.kyc);
                  },
          ),
          const SizedBox(height: 12),

          _buildStepRow(
            context: context,
            icon: Icons.add_card_rounded,
            iconColor: AppColors.darkGold,
            title: 'step_deposit_funds'.tr,
            subtitle: 'insight_deposit_funds'.tr,
            isCompleted: false,
            onTap: () {
              Get.back();
              Get.toNamed(Routes.deposit);
            },
          ),
          const SizedBox(height: 12),

          _buildStepRow(
            context: context,
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.darkGold,
            title: 'step_explore_investments'.tr,
            subtitle: 'insight_start_investing'.tr,
            isCompleted: false,
            onTap: () {
              Get.back();
              Get.toNamed(Routes.investmentPlans);
            },
          ),

          const SizedBox(height: 28),

          // Primary CTA
          KasbyButton(
            text: kycVerified ? 'invest_now'.tr : 'verify_now'.tr,
            icon: kycVerified
                ? Icons.trending_up_rounded
                : Icons.verified_user_rounded,
            onPressed: () {
              Get.back();
              if (kycVerified) {
                Get.toNamed(Routes.investmentPlans);
              } else {
                Get.toNamed(Routes.kyc);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isCompleted,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KasbyCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null && !isCompleted)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.darkGold,
              ),
          ],
        ),
      ),
    );
  }
}
