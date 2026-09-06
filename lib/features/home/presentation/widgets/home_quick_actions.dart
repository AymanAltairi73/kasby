import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/theme/kasby_typography.dart';
import 'package:kasby/features/social/presentation/widgets/invite_friends_sheet.dart';
import 'package:kasby/routes/app_routes.dart';

/// Secondary actions surfaced in the "More" bottom sheet.
List<Map<String, dynamic>> homeSecondaryActions() => [
  {
    'icon': Icons.calendar_today_rounded,
    'label': 'check_in'.tr,
    'onTap': () => Get.toNamed(Routes.dailyCheckIn),
  },
  {
    'icon': Icons.storefront_rounded,
    'label': 'marketplace'.tr,
    'onTap': () => Get.toNamed(Routes.store),
  },
  {
    'icon': Icons.analytics_rounded,
    'label': 'portfolio_analytics'.tr,
    'onTap': () => Get.toNamed(Routes.portfolioAnalytics),
  },
  // {
  //   'icon': Icons.leaderboard_rounded,
  //   'label': 'referral_analytics'.tr,
  //   'onTap': () => Get.toNamed(Routes.referralAnalytics),
  // },
  // {
  //   'icon': Icons.trending_up_rounded,
  //   'label': 'investment_plans'.tr,
  //   'onTap': () => Get.toNamed(Routes.investmentPlans),
  // },
  // {
  //   'icon': Icons.add_circle_outline_rounded,
  //   'label': 'deposit'.tr,
  //   'onTap': () => Get.toNamed(Routes.deposit),
  // },
  // {
  //   'icon': Icons.remove_circle_outline_rounded,
  //   'label': 'withdraw'.tr,
  //   'onTap': () => Get.toNamed(Routes.withdraw),
  // },
  // {
  //   'icon': Icons.verified_user_outlined,
  //   'label': 'kyc_verification'.tr,
  //   'onTap': () => Get.toNamed(Routes.kyc),
  // },
  // {
  //   'icon': Icons.qr_code_scanner_rounded,
  //   'label': 'scan_qr'.tr,
  //   'onTap': () => Get.toNamed(Routes.qrScanner),
  // },
  {
    'icon': Icons.description_outlined,
    'label': 'statements'.tr,
    'onTap': () => Get.toNamed(Routes.statements),
  },
  {
    'icon': Icons.person_add_alt_1_rounded,
    'label': 'invite_friends'.tr,
    'onTap': InviteFriendsSheet.show,
  },
];

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, this.tourKey, this.marketplaceKey});

  final Key? tourKey;
  final Key? marketplaceKey;

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
      'onTap': () {
        if (Get.currentRoute != Routes.myInvestments) {
          Get.toNamed(Routes.myInvestments);
        }
      },
    },
    {
      'icon': Icons.handshake_rounded,
      'label': 'salefni_kasby'.tr,
      'onTap': () => Get.toNamed(Routes.loan),
    },
    {
      'icon': Icons.card_membership_rounded,
      'label': 'subscriptions'.tr,
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
                style: TextStyle(
                  fontFamily: KasbyTypography.fontFamily,
                  fontSize: KasbyTypography.sectionHeader(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: KasbySpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width < 340 ? 3 : 4;
                  const crossAxisSpacing = 14.0;
                  const mainAxisSpacing = 18.0;
                  final itemWidth =
                      (width - crossAxisSpacing * (crossAxisCount - 1)) /
                      crossAxisCount;
                  final itemHeight = 112.0;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: mainAxisSpacing,
                    crossAxisSpacing: crossAxisSpacing,
                    childAspectRatio: itemWidth / itemHeight,
                    children: homeSecondaryActions()
                        .map(
                          (a) => HomeQuickActionItem(
                            icon: a['icon'] as IconData,
                            label: a['label'] as String,
                            maxLabelWidth: itemWidth,
                            onPressed: () {
                              Get.back();
                              (a['onTap'] as VoidCallback)();
                            },
                          ),
                        )
                        .toList(),
                  );
                },
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

    return KeyedSubtree(
      key: tourKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const crossAxisCount = 4;
          const crossAxisSpacing = 12.0;
          const mainAxisSpacing = 16.0;
          const mainAxisExtent = 112.0;
          final itemWidth =
              (width - crossAxisSpacing * (crossAxisCount - 1)) /
              crossAxisCount;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisExtent: mainAxisExtent,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              final isMarketplaceMore = index == actions.length - 1;
              return HomeQuickActionItem(
                key: isMarketplaceMore ? marketplaceKey : null,
                icon: action['icon'] as IconData,
                label: action['label'] as String,
                maxLabelWidth: itemWidth,
                onPressed: action['onTap'] as VoidCallback,
              );
            },
          );
        },
      ),
    );
  }
}

class HomeQuickActionItem extends StatelessWidget {
  const HomeQuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.maxLabelWidth,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double? maxLabelWidth;

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
            const SizedBox(height: 8),
            SizedBox(
              width: maxLabelWidth,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontFamily: KasbyTypography.fontFamily,
                  fontSize: KasbyTypography.isEnglish(context)
                      ? ((maxLabelWidth ?? 72) < 68 ? 9 : 10)
                      : ((maxLabelWidth ?? 72) < 68 ? 10 : 11),
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
