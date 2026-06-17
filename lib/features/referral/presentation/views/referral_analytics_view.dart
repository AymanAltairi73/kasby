import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/widgets/empty_state_widget.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/widgets/mini_charts.dart';
import 'package:kasby/features/referral/presentation/controllers/referral_analytics_controller.dart';

class ReferralAnalyticsView extends StatelessWidget {
  const ReferralAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ReferralAnalyticsController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('referral_analytics'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _buildShimmerState();
        }
        if (controller.hasError.value) {
          return ErrorStateWidget(onRetry: controller.fetchAll);
        }
        if (controller.totalReferrals.value == 0 &&
            controller.referralEarnings.value == 0.0) {
          return EmptyStateWidget(
            title: 'no_referrals'.tr,
            description: 'no_referrals_desc'.tr,
            icon: Icons.people_outline_rounded,
          );
        }
        return RefreshIndicator(
          color: AppColors.darkGold,
          onRefresh: controller.fetchAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: KasbySpacing.lg,
              vertical: KasbySpacing.md,
            ),
            children: [
              _buildHeroMetrics(controller, isDark),
              const SizedBox(height: KasbySpacing.xl),
              _buildPeriodSelector(controller, isDark),
              const SizedBox(height: KasbySpacing.xl),
              _buildTeamGrowthChart(controller, isDark),
              const SizedBox(height: KasbySpacing.lg),
              _buildEarningsChart(controller, isDark),
              const SizedBox(height: KasbySpacing.xl),
              _buildMetricsGrid(controller, isDark),
              const SizedBox(height: KasbySpacing.xl),
              _buildMemberBreakdown(controller, isDark),
              const SizedBox(height: KasbySpacing.xl),
              _buildTopReferrals(controller, isDark),
              const SizedBox(height: KasbySpacing.huge),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildShimmerState() {
    return Padding(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        children: [
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KasbySpacing.xs,
                  ),
                  child: KasbyShimmer(height: 100, borderRadius: KasbyRadius.cardR),
                ),
              ),
            ),
          ),
          const SizedBox(height: KasbySpacing.xl),
          KasbyShimmer(height: 48, borderRadius: KasbyRadius.chipR),
          const SizedBox(height: KasbySpacing.xl),
          KasbyShimmer(height: 140, borderRadius: KasbyRadius.cardR),
          const SizedBox(height: KasbySpacing.lg),
          KasbyShimmer(height: 140, borderRadius: KasbyRadius.cardR),
          const SizedBox(height: KasbySpacing.xl),
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: KasbySpacing.md),
              child: KasbyShimmer(height: 72, borderRadius: KasbyRadius.cardR),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetrics(
    ReferralAnalyticsController controller,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'total_referrals'.tr,
            value: controller.totalReferrals.value.toString(),
            icon: Icons.group_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: KasbySpacing.sm),
        Expanded(
          child: _MetricCard(
            label: 'active_members'.tr,
            value: controller.activeMembers.value.toString(),
            icon: Icons.trending_up_rounded,
            color: AppColors.softGreen,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: KasbySpacing.sm),
        Expanded(
          child: _MetricCard(
            label: 'referral_earnings'.tr,
            value: CurrencyController.to
                .formatToUSD(controller.referralEarnings.value),
            icon: Icons.monetization_on_rounded,
            color: AppColors.darkGold,
            isDark: isDark,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _buildPeriodSelector(
    ReferralAnalyticsController controller,
    bool isDark,
  ) {
    const periods = ['7d', '30d', '90d', '1y'];
    const labels = ['7D', '30D', '90D', '1Y'];

    return Row(
      children: List.generate(periods.length, (i) {
        final isSelected = controller.selectedPeriod.value == periods[i];
        return Expanded(
          child: GestureDetector(
            onTap: () => controller.changePeriod(periods[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                right: i < periods.length - 1 ? KasbySpacing.sm : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: KasbySpacing.md),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.darkGold
                    : (isDark
                        ? AppColors.surface
                        : AppColors.surfaceLight),
                borderRadius: KasbyRadius.chipR,
                border: Border.all(
                  color: isSelected
                      ? AppColors.darkGold
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08)),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildTeamGrowthChart(
    ReferralAnalyticsController controller,
    bool isDark,
  ) {
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: KasbySpacing.sm),
              Text(
                'team_growth'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${controller.totalReferrals.value} ${'team_size'.tr}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: KasbySpacing.lg),
          KasbySparkline(
            data: controller.teamGrowthHistory.isNotEmpty
                ? controller.teamGrowthHistory
                : [0, 0],
            lineColor: AppColors.primary,
            height: 80,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart(
    ReferralAnalyticsController controller,
    bool isDark,
  ) {
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money_rounded,
                  size: 18, color: AppColors.softGreen),
              const SizedBox(width: KasbySpacing.sm),
              Text(
                'earnings_this_period'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                CurrencyController.to
                    .formatToUSD(controller.referralEarnings.value),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.softGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: KasbySpacing.lg),
          KasbySparkline(
            data: controller.earningsHistory.isNotEmpty
                ? controller.earningsHistory
                : [0, 0],
            lineColor: AppColors.softGreen,
            height: 80,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(
    ReferralAnalyticsController controller,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'referral_performance'.tr,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: KasbySpacing.md),
        Row(
          children: [
            Expanded(
              child: _SmallMetricTile(
                label: 'daily_referrals'.tr,
                value: controller.dailyReferrals.value.toString(),
                icon: Icons.today_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: KasbySpacing.sm),
            Expanded(
              child: _SmallMetricTile(
                label: 'monthly_referrals'.tr,
                value: controller.monthlyReferrals.value.toString(),
                icon: Icons.calendar_month_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: KasbySpacing.sm),
            Expanded(
              child: _SmallMetricTile(
                label: 'conversion_rate'.tr,
                value:
                    '${controller.conversionRate.value.toStringAsFixed(1)}%',
                icon: Icons.pie_chart_rounded,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildMemberBreakdown(
    ReferralAnalyticsController controller,
    bool isDark,
  ) {
    final active = controller.activeMembers.value.toDouble();
    final inactive = controller.inactiveMembers.value.toDouble();
    if (active + inactive <= 0) return const SizedBox.shrink();

    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'team_size'.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: KasbySpacing.lg),
          KasbyAllocationBar(
            segments: [
              AllocationSegment(
                label: 'active_members'.tr,
                value: active,
                color: AppColors.softGreen,
              ),
              AllocationSegment(
                label: 'inactive_members'.tr,
                value: inactive,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopReferrals(
    ReferralAnalyticsController controller,
    bool isDark,
  ) {
    if (controller.topReferrals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'top_referrals'.tr,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: KasbySpacing.md),
        ...controller.topReferrals.asMap().entries.map((entry) {
          final index = entry.key;
          final member = entry.value;
          final name = member['full_name'] ?? 'user'.tr;
          final joinDate = DateTime.tryParse(member['created_at'] ?? '');
          final status =
              member['status']?.toString().toLowerCase() ?? 'inactive';
          final isActive = status == 'active';

          return KasbyCard(
            margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: KasbySpacing.lg,
              vertical: KasbySpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.darkGold.withValues(alpha: 0.15),
                    borderRadius: KasbyRadius.chipR,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGold,
                    ),
                  ),
                ),
                const SizedBox(width: KasbySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${'member_since'.tr} ${DateHelper.date(joinDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KasbySpacing.sm,
                    vertical: KasbySpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: (isActive ? AppColors.softGreen : AppColors.error)
                        .withValues(alpha: 0.12),
                    borderRadius: KasbyRadius.chipR,
                  ),
                  child: Text(
                    isActive
                        ? 'active_members'.tr
                        : 'inactive_members'.tr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppColors.softGreen : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: (50 * index).ms).fadeIn().slideX(begin: 0.05, end: 0);
        }),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.md),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KasbyRadius.chipR,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: KasbySpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: KasbySpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SmallMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _SmallMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.darkGold),
          const SizedBox(height: KasbySpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: KasbySpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
