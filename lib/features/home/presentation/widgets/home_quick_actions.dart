import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/routes/app_routes.dart';

/// Secondary actions surfaced in the "More" bottom sheet.
List<Map<String, dynamic>> homeSecondaryActions() => [
      {
        'icon': Icons.storefront_rounded,
        'label': 'marketplace'.tr,
        'onTap': () => Get.toNamed(Routes.marketplace),
      },
      {
        'icon': Icons.analytics_rounded,
        'label': 'portfolio_analytics'.tr,
        'onTap': () => Get.toNamed(Routes.portfolioAnalytics),
      },
      {
        'icon': Icons.leaderboard_rounded,
        'label': 'referral_analytics'.tr,
        'onTap': () => Get.toNamed(Routes.referralAnalytics),
      },
      {
        'icon': Icons.calendar_today_rounded,
        'label': 'check_in'.tr,
        'onTap': () => Get.toNamed(Routes.dailyCheckIn),
      },
      {
        'icon': Icons.trending_up_rounded,
        'label': 'investment_plans'.tr,
        'onTap': () => Get.toNamed(Routes.investmentPlans),
      },
      {
        'icon': Icons.add_circle_outline_rounded,
        'label': 'deposit'.tr,
        'onTap': () => Get.toNamed(Routes.deposit),
      },
      {
        'icon': Icons.remove_circle_outline_rounded,
        'label': 'withdraw'.tr,
        'onTap': () => Get.toNamed(Routes.withdraw),
      },
      {
        'icon': Icons.verified_user_outlined,
        'label': 'kyc_verification'.tr,
        'onTap': () => Get.toNamed(Routes.kyc),
      },
      {
        'icon': Icons.qr_code_scanner_rounded,
        'label': 'scan_qr'.tr,
        'onTap': () => Get.toNamed(Routes.qrScanner),
      },
      {
        'icon': Icons.description_outlined,
        'label': 'statements'.tr,
        'onTap': () => Get.toNamed(Routes.statements),
      },
    ];

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  List<Map<String, dynamic>> _primaryActions(BuildContext context) => [
        {
          'icon': Icons.swap_horizontal_circle_rounded,
          'label': 'p2p_transfer'.tr,
          'onTap': () => Get.toNamed(Routes.transfer),
        },
        {
          'icon': Icons.groups_rounded,
          'label': 'authorized_agents'.tr,
          'onTap': () => Get.toNamed(Routes.agents),
        },
        {
          'icon': Icons.diversity_3_rounded,
          'label': 'social_network'.tr,
          'onTap': () => Get.toNamed(Routes.friendRequests),
        },
        {
          'icon': Icons.pie_chart_rounded,
          'label': 'my_investments'.tr,
          'onTap': () => Get.toNamed(Routes.myInvestments),
        },
        {
          'icon': Icons.handshake_rounded,
          'label': 'salefni_kasby'.tr,
          'onTap': () => Get.toNamed(Routes.loan),
        },
        {
          'icon': Icons.card_membership_rounded,
          'label': 'investments'.tr,
          'onTap': () => Get.toNamed(Routes.subscription),
        },
        {
          'icon': Icons.casino_rounded,
          'label': 'spin_wheel'.tr,
          'onTap': () => Get.toNamed(Routes.spinWheel),
        },
        {
          'icon': Icons.grid_view_rounded,
          'label': 'more'.tr,
          'onTap': () => _showMoreActions(context),
        },
      ];

  void _showMoreActions(BuildContext context) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: KasbyRadius.sheetR),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KasbySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'more'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: KasbySpacing.xl),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
                children: homeSecondaryActions()
                    .map(
                      (a) => HomeQuickActionItem(
                        icon: a['icon'] as IconData,
                        label: a['label'] as String,
                        onPressed: () {
                          Get.back();
                          (a['onTap'] as VoidCallback)();
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = _primaryActions(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        mainAxisExtent: 100,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return HomeQuickActionItem(
          icon: action['icon'] as IconData,
          label: action['label'] as String,
          onPressed: action['onTap'] as VoidCallback,
        );
      },
    );
  }
}

class HomeQuickActionItem extends StatelessWidget {
  const HomeQuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.darkGold, size: 28),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
