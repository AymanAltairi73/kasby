import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/localization/model_localization_extensions.dart';
import 'package:kasby/core/models/earnings_analytics_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/services/currency_conversion_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/features/earnings/presentation/controllers/earnings_analytics_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

/// Modern, enterprise-grade Earnings Analytics Dashboard
class EarningsAnalyticsView extends GetView<EarningsAnalyticsController> {
  const EarningsAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'earnings_analytics'.tr,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _buildLoadingState(isDark);
        }

        if (controller.hasError.value) {
          return _buildErrorState(context, isDark);
        }

        final analytics = controller.analytics.value;
        if (analytics == null || analytics.summary == null) {
          return _buildEmptyState(context, isDark);
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          color: AppColors.darkGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSubtitle(context, isDark),
                const SizedBox(height: 16),
                _buildPeriodPills(context, isDark),
                const SizedBox(height: 24),
                _buildSummaryGrid(context, analytics, isDark),
                const SizedBox(height: 24),
                _buildTrendChartSection(context, analytics, isDark),
                const SizedBox(height: 24),
                _buildSourceBreakdownSection(context, analytics, isDark),
                const SizedBox(height: 24),
                _buildPerformanceInsightsSection(context, analytics, isDark),
                const SizedBox(height: 24),
                _buildInvestmentPerformanceSection(context, isDark),
                const SizedBox(height: 24),
                _buildTimelineSection(context, analytics, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeaderSubtitle(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'earnings_analytics_subtitle'.tr,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPeriodPills(BuildContext context, bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: EarningsAnalyticsController.periods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = EarningsAnalyticsController.periods[index];
          return Obx(() {
            final isSelected = controller.selectedPeriod.value == period;
            return InkWell(
              onTap: () => controller.changePeriod(period),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.darkGold
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.darkGold
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
                child: Center(
                  child: Text(
                    controller.getLocalizedPeriodName(period),
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.black
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            );
          });
        },
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildSummaryGrid(
    BuildContext context,
    EarningsAnalyticsModel analytics,
    bool isDark,
  ) {
    final stats = analytics.statistics;
    final totalUsd = controller.getTotalEarningsUsd();
    final todayUsd = controller.getTodayEarningsUsd();
    final last24hUsd = controller.getLast24hEarningsUsd();
    final highestUsd = stats?.highestDailyEarningsUsd ?? 0.0;
    final averageUsd = stats?.averageDailyEarningsUsd ?? 0.0;
    final daysInPeriod = stats?.daysInPeriod ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          context,
          title: 'total_earnings'.tr,
          value: CurrencyConversionService.formatUsd(totalUsd),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.darkGold,
          isDark: isDark,
        ),
        _buildStatCard(
          context,
          title: 'today_earnings'.tr,
          value: CurrencyConversionService.formatUsd(todayUsd),
          icon: Icons.today_rounded,
          color: AppColors.softGreen,
          isDark: isDark,
        ),
        _buildStatCard(
          context,
          title: 'last_24h'.tr,
          value: CurrencyConversionService.formatUsd(last24hUsd),
          icon: Icons.schedule_rounded,
          color: Colors.orangeAccent,
          isDark: isDark,
        ),
        _buildStatCard(
          context,
          title: 'highest_daily'.tr,
          value: CurrencyConversionService.formatUsd(highestUsd),
          icon: Icons.trending_up_rounded,
          color: Colors.purpleAccent,
          isDark: isDark,
        ),
        _buildStatCard(
          context,
          title: 'average_daily'.tr,
          value: CurrencyConversionService.formatUsd(averageUsd),
          icon: Icons.bar_chart_rounded,
          color: Colors.tealAccent,
          isDark: isDark,
        ),
        _buildStatCard(
          context,
          title: 'days_in_period'.tr,
          value: '$daysInPeriod',
          icon: Icons.calendar_today_rounded,
          color: Colors.blueAccent,
          isDark: isDark,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return KasbyCard(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : AppColors.surfaceLight,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartSection(
    BuildContext context,
    EarningsAnalyticsModel analytics,
    bool isDark,
  ) {
    final chartData = analytics.chartData?.trendChart ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'earnings_trend'.tr,
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Icon(
              Icons.insights_rounded,
              color: AppColors.darkGold,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 12),
        KasbyCard(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : AppColors.surfaceLight,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          child: Column(
            children: [
              if (chartData.isEmpty)
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: Text(
                    'no_growth_data'.tr,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: InteractiveTrendChart(
                    data: chartData,
                    lineColor: AppColors.darkGold,
                    isDark: isDark,
                  ),
                ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms);
  }

  Widget _buildSourceBreakdownSection(
    BuildContext context,
    EarningsAnalyticsModel analytics,
    bool isDark,
  ) {
    final breakdown = controller.getBreakdownWithConversion();
    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalUsd = controller.getTotalEarningsUsd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'source_breakdown'.tr,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...breakdown.map(
          (item) => _buildBreakdownItem(context, item, totalUsd, isDark),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildBreakdownItem(
    BuildContext context,
    BreakdownItem item,
    double totalUsd,
    bool isDark,
  ) {
    final icon = _getSourceIcon(item.source);
    final percentage = item.percentage;
    final totalUsdEquivalent = item.getTotalUsdEquivalent();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: KasbyCard(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : AppColors.surfaceLight,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkGold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: AppColors.darkGold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.getLocalizedSource(),
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyConversionService.formatUsd(totalUsdEquivalent),
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.softGreen,
                      ),
                    ),
                    if (item.amountKsp != null && item.amountKsp! > 0)
                      Text(
                        '(${CurrencyConversionService.formatKsp(item.amountKsp!.toDouble())} KSP)',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percentage / 100).clamp(0.0, 1.0),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkGold),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'investments':
        return Icons.trending_up_rounded;
      case 'lucky_wheel':
        return Icons.casino_rounded;
      case 'referral_rewards':
        return Icons.people_rounded;
      case 'registration_bonuses':
        return Icons.card_giftcard_rounded;
      case 'other_rewards':
        return Icons.stars_rounded;
      case 'investment_returns':
        return Icons.account_balance_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }

  Widget _buildPerformanceInsightsSection(
    BuildContext context,
    EarningsAnalyticsModel analytics,
    bool isDark,
  ) {
    final stats = analytics.statistics;
    final breakdown = controller.getBreakdownWithConversion();

    final hasHighestDay = stats != null && stats.highestDailyEarningsUsd > 0;
    final hasAvg = stats != null && stats.averageDailyEarningsUsd > 0;
    final hasTopSource = breakdown.isNotEmpty;

    if (!hasHighestDay && !hasAvg && !hasTopSource) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'performance_insights'.tr,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          KasbyCard(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : AppColors.surfaceLight,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.darkGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'no_insights_yet'.tr,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final topSource = breakdown.isNotEmpty ? breakdown.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'performance_insights'.tr,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        KasbyCard(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : AppColors.surfaceLight,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          child: Column(
            children: [
              if (hasHighestDay)
                _buildInsightTile(
                  icon: Icons.star_rounded,
                  color: Colors.amber,
                  text: 'insight_highest_day'.trParams({
                    'date': '—',
                    'amount': CurrencyConversionService.formatUsd(
                      stats.highestDailyEarningsUsd,
                    ),
                  }),
                  isDark: isDark,
                ),
              if (hasHighestDay && hasAvg) const Divider(height: 16),
              if (hasAvg)
                _buildInsightTile(
                  icon: Icons.bar_chart_rounded,
                  color: Colors.tealAccent,
                  text: 'insight_average_daily'.trParams({
                    'amount': CurrencyConversionService.formatUsd(
                      stats.averageDailyEarningsUsd,
                    ),
                  }),
                  isDark: isDark,
                ),
              if (topSource != null) ...[
                if (hasHighestDay || hasAvg) const Divider(height: 16),
                _buildInsightTile(
                  icon: Icons.pie_chart_rounded,
                  color: AppColors.softGreen,
                  text: 'insight_top_source'.trParams({
                    'source': topSource.getLocalizedSource(),
                    'percent': topSource.percentage.toStringAsFixed(1),
                  }),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 550.ms);
  }

  Widget _buildInsightTile({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestmentPerformanceSection(BuildContext context, bool isDark) {
    if (!Get.isRegistered<HomeController>()) return const SizedBox.shrink();
    final homeController = HomeController.to;

    return Obx(() {
      final investments = homeController.myInvestments;
      if (investments.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'investment_performance'.tr,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              InkWell(
                onTap: () => Get.toNamed(Routes.myInvestments),
                child: Text(
                  'see_all'.tr,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: investments.length > 3 ? 3 : investments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final inv = investments[index];
              return _buildInvestmentItem(context, inv, isDark);
            },
          ),
        ],
      ).animate().fadeIn(duration: 600.ms);
    });
  }

  Widget _buildInvestmentItem(
    BuildContext context,
    UserInvestmentModel inv,
    bool isDark,
  ) {
    final plan = inv.investment;
    final name = plan != null
        ? (Get.locale?.languageCode == 'en'
            ? (plan.nameEn ?? plan.nameAr)
            : plan.nameAr)
        : 'investment'.tr;
    final amountUsd = CurrencyConversionService.formatUsd(inv.amount);
    final expectedProfitUsd = CurrencyConversionService.formatUsd(
      inv.expectedProfit,
    );

    return KasbyCard(
      color: isDark
          ? Colors.white.withValues(alpha: 0.03)
          : AppColors.surfaceLight,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              color: AppColors.darkGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${'amount'.tr}: $amountUsd',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                expectedProfitUsd,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.softGreen,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: inv.autoRestartEnabled
                      ? AppColors.softGreen.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  inv.autoRestartEnabled ? 'تلقائي' : 'يدوي',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: inv.autoRestartEnabled
                        ? AppColors.softGreen
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(
    BuildContext context,
    EarningsAnalyticsModel analytics,
    bool isDark,
  ) {
    final timeline = analytics.timeline;
    if (timeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'earnings_timeline'.tr,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...timeline.map((item) => _buildTimelineItem(context, item, isDark)),
      ],
    ).animate().fadeIn(duration: 650.ms);
  }

  Widget _buildTimelineItem(
    BuildContext context,
    TimelineItem item,
    bool isDark,
  ) {
    final icon = _getSourceIcon(item.source);
    final totalUsd = item.getTotalUsdEquivalent();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: KasbyCard(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : AppColors.surfaceLight,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.softGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.getLocalizedSource(),
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.localizedDescription,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyConversionService.formatUsd(totalUsd),
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.softGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(item.createdAt),
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'today'.tr;
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr;
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${'days_ago'.tr}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.darkGold),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل تحليلات الأرباح...',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage.value,
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: controller.refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'retry'.tr,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.query_stats_rounded,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'no_earnings_data'.tr,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Interactive Trend Chart with touch gesture inspection tooltips
class InteractiveTrendChart extends StatefulWidget {
  final List<TrendChartItem> data;
  final Color lineColor;
  final bool isDark;

  const InteractiveTrendChart({
    super.key,
    required this.data,
    required this.lineColor,
    required this.isDark,
  });

  @override
  State<InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<InteractiveTrendChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final selectedItem = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < widget.data.length
        ? widget.data[_selectedIndex!]
        : null;

    return GestureDetector(
      onPanUpdate: (details) => _handleTouch(details.localPosition, context),
      onTapDown: (details) => _handleTouch(details.localPosition, context),
      child: Column(
        children: [
          if (selectedItem != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkGold),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selectedItem.date}: ',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 11,
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Text(
                    CurrencyConversionService.formatUsd(selectedItem.amountUsd),
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.softGreen,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SmoothTrendChartPainter(
                data: widget.data,
                lineColor: widget.lineColor,
                selectedIndex: _selectedIndex,
                isDark: widget.isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTouch(Offset position, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final padding = 16.0;
    final chartWidth = size.width - padding * 2;

    if (position.dx < padding || position.dx > size.width - padding) return;

    final pointWidth = chartWidth / (widget.data.length - 1 == 0 ? 1 : widget.data.length - 1);
    final index = ((position.dx - padding) / pointWidth).round();

    if (index >= 0 && index < widget.data.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }
}

class _SmoothTrendChartPainter extends CustomPainter {
  final List<TrendChartItem> data;
  final Color lineColor;
  final int? selectedIndex;
  final bool isDark;

  _SmoothTrendChartPainter({
    required this.data,
    required this.lineColor,
    this.selectedIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padding = 16.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    double maxValue = 0.0;
    for (var item in data) {
      if (item.amountUsd > maxValue) maxValue = item.amountUsd;
    }
    if (maxValue == 0) maxValue = 1.0;

    final scale = chartHeight / maxValue;

    // Grid lines
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = padding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    if (data.length == 1) {
      final y = padding + chartHeight - (data[0].amountUsd * scale);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        Paint()
          ..color = lineColor
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(size.width / 2, y),
        6,
        Paint()..color = lineColor,
      );
      return;
    }

    final pointWidth = chartWidth / (data.length - 1);
    final path = Path();
    final fillPath = Path();

    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = padding + pointWidth * i;
      final y = padding + chartHeight - (data[i].amountUsd * scale);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height - padding);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p2.dx,
        p2.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p2.dx,
        p2.dy,
      );
    }

    fillPath.lineTo(points.last.dx, size.height - padding);
    fillPath.close();

    // Gradient fill under curve
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: 0.3),
        lineColor.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line drawing
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Points and selected point highlight
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final isSelected = selectedIndex == i;
      final pt = points[i];

      if (isSelected) {
        canvas.drawCircle(
          pt,
          8,
          Paint()..color = lineColor.withValues(alpha: 0.3),
        );
        canvas.drawCircle(pt, 5, pointPaint);
        canvas.drawCircle(pt, 2, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(pt, 3, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SmoothTrendChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.data != data ||
        oldDelegate.isDark != isDark;
  }
}

