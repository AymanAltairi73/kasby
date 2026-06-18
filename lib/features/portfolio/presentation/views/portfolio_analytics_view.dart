import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/widgets/mini_charts.dart';
import 'package:kasby/core/widgets/empty_state_widget.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/features/portfolio/presentation/controllers/portfolio_controller.dart';

class PortfolioAnalyticsView extends StatelessWidget {
  const PortfolioAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PortfolioController());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = CurrencyController.to;

    return Scaffold(
      appBar: AppBar(
        title: Text('portfolio_analytics'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _buildShimmer();
        }

        if (controller.hasError.value) {
          return ErrorStateWidget(onRetry: controller.refresh);
        }

        if (!controller.hasData) {
          return EmptyStateWidget(
            title: 'no_portfolio_data'.tr,
            description: 'no_portfolio_data_desc'.tr,
            icon: Icons.analytics_outlined,
          );
        }

        return RefreshIndicator(
          color: AppColors.darkGold,
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: KasbySpacing.lg,
              vertical: KasbySpacing.md,
            ),
            children: [
              _NetWorthHero(
                netWorth: controller.netWorth.value,
                change: controller.changeFromStart.value,
                currency: currency,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: KasbySpacing.lg),

              _PeriodSelector(
                controller: controller,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms, delay: 50.ms),

              const SizedBox(height: KasbySpacing.lg),

              _GrowthChart(
                data: controller.growthData,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: KasbySpacing.lg),

              if (controller.waterfallSteps.isNotEmpty) ...[
                _WaterfallSection(
                  steps: controller.waterfallSteps,
                  isDark: isDark,
                ).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: KasbySpacing.lg),
              ],

              if (controller.benchmarks.isNotEmpty) ...[
                _BenchmarkSection(
                  benchmarks: controller.benchmarks,
                  isDark: isDark,
                ).animate().fadeIn(duration: 400.ms, delay: 140.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: KasbySpacing.lg),
              ],

              _RoiCard(
                roi: controller.roiPercentage.value,
                totalReturns: controller.totalReturns.value,
                currency: currency,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: KasbySpacing.lg),

              _ProfitLossCard(
                daily: controller.dailyPerformance.value,
                weekly: controller.weeklyPerformance.value,
                monthly: controller.monthlyPerformance.value,
                yearly: controller.yearlyPerformance.value,
                currency: currency,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: KasbySpacing.lg),

              if (controller.distribution.isNotEmpty) ...[
                _AllocationSection(
                  distribution: controller.distribution,
                  currency: currency,
                  isDark: isDark,
                ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: KasbySpacing.lg),
              ],

              if (controller.insights.isNotEmpty) ...[
                _InsightsSection(
                  insights: controller.insights,
                  isDark: isDark,
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: KasbySpacing.lg),
              ],

              const SizedBox(height: KasbySpacing.huge),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        children: [
          const KasbyShimmer.card(height: 140),
          const SizedBox(height: KasbySpacing.lg),
          const KasbyShimmer(height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
          const SizedBox(height: KasbySpacing.lg),
          const KasbyShimmer.card(height: 180),
          const SizedBox(height: KasbySpacing.lg),
          const KasbyShimmer.card(height: 100),
          const SizedBox(height: KasbySpacing.lg),
          const KasbyShimmer.card(height: 160),
        ],
      ),
    );
  }
}

// ─── NET WORTH HERO ───────────────────────────────────────────

class _NetWorthHero extends StatelessWidget {
  final double netWorth;
  final double change;
  final CurrencyController currency;
  final bool isDark;

  const _NetWorthHero({
    required this.netWorth,
    required this.change,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change >= 0;

    return KasbyCard(
      gradient: AppColors.goldGradient,
      padding: const EdgeInsets.all(KasbySpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'net_worth'.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: KasbySpacing.sm),
          Text(
            currency.formatToUSD(netWorth),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: KasbySpacing.md),
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: KasbySpacing.xs),
              Text(
                '${isPositive ? "+" : ""}${currency.formatToUSD(change)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: KasbySpacing.sm),
              Text(
                'change_from_start'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── PERIOD SELECTOR ──────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final PortfolioController controller;
  final bool isDark;

  const _PeriodSelector({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: PortfolioPeriod.values.map((period) {
            final selected = controller.selectedPeriod.value == period;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: KasbySpacing.sm),
              child: ChoiceChip(
                label: Text(controller.periodLabel(period)),
                selected: selected,
                selectedColor: AppColors.darkGold,
                backgroundColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: KasbyRadius.chipR,
                ),
                onSelected: (_) => controller.changePeriod(period),
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

// ─── GROWTH CHART ─────────────────────────────────────────────

class _GrowthChart extends StatelessWidget {
  final RxList<double> data;
  final bool isDark;

  const _GrowthChart({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return KasbyCard(
        padding: const EdgeInsets.all(KasbySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'portfolio_growth'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: KasbySpacing.lg),
            KasbySparkline(
              data: data.isEmpty ? [0, 0] : data.toList(),
              height: 120,
              lineColor: AppColors.darkGold,
              fill: true,
            ),
          ],
        ),
      );
    });
  }
}

// ─── ROI CARD ─────────────────────────────────────────────────

class _RoiCard extends StatelessWidget {
  final double roi;
  final double totalReturns;
  final CurrencyController currency;
  final bool isDark;

  const _RoiCard({
    required this.roi,
    required this.totalReturns,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = roi >= 0;
    final roiColor = isPositive ? AppColors.softGreen : AppColors.error;

    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: roiColor.withValues(alpha: 0.12),
              borderRadius: KasbyRadius.inputR,
            ),
            child: Icon(
              isPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: roiColor,
              size: 24,
            ),
          ),
          const SizedBox(width: KasbySpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: KasbySpacing.xs),
                Text(
                  '${isPositive ? "+" : ""}${roi.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: roiColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'portfolio_value'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: KasbySpacing.xs),
              Text(
                currency.formatToUSD(totalReturns),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── PROFIT/LOSS CARD ─────────────────────────────────────────

class _ProfitLossCard extends StatelessWidget {
  final double daily;
  final double weekly;
  final double monthly;
  final double yearly;
  final CurrencyController currency;
  final bool isDark;

  const _ProfitLossCard({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profit_loss'.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: KasbySpacing.lg),
          _PerfRow(label: 'daily_performance'.tr, value: daily, currency: currency, isDark: isDark),
          const Divider(height: KasbySpacing.xxl),
          _PerfRow(label: 'weekly_performance'.tr, value: weekly, currency: currency, isDark: isDark),
          const Divider(height: KasbySpacing.xxl),
          _PerfRow(label: 'monthly_performance'.tr, value: monthly, currency: currency, isDark: isDark),
          const Divider(height: KasbySpacing.xxl),
          _PerfRow(label: 'yearly_performance'.tr, value: yearly, currency: currency, isDark: isDark),
        ],
      ),
    );
  }
}

class _PerfRow extends StatelessWidget {
  final String label;
  final double value;
  final CurrencyController currency;
  final bool isDark;

  const _PerfRow({
    required this.label,
    required this.value,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = value == 0
        ? AppColors.textSecondary
        : (isPositive ? AppColors.softGreen : AppColors.error);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${isPositive && value > 0 ? "+" : ""}${currency.formatToUSD(value)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── ALLOCATION SECTION ───────────────────────────────────────

class _AllocationSection extends StatelessWidget {
  final RxMap<String, double> distribution;
  final CurrencyController currency;
  final bool isDark;

  const _AllocationSection({
    required this.distribution,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final entries = distribution.entries.toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    final segments = <AllocationSegment>[];
    for (int i = 0; i < entries.length; i++) {
      segments.add(AllocationSegment(
        label: entries[i].key,
        value: entries[i].value,
        color: PortfolioController.allocationColors[
            i % PortfolioController.allocationColors.length],
      ));
    }

    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'investment_distribution'.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: KasbySpacing.lg),
          KasbyAllocationBar(segments: segments),
          const SizedBox(height: KasbySpacing.lg),
          ...entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final pct = total > 0 ? (entry.value / total * 100) : 0.0;
            final color = PortfolioController.allocationColors[
                idx % PortfolioController.allocationColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: KasbySpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: KasbySpacing.md),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.onSurfaceLight,
                      ),
                    ),
                  ),
                  Text(
                    currency.formatToUSD(entry.value),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.onSurfaceLight,
                    ),
                  ),
                  const SizedBox(width: KasbySpacing.sm),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── WATERFALL SECTION ────────────────────────────────────────

class _WaterfallSection extends StatelessWidget {
  final RxList<WaterfallStep> steps;
  final bool isDark;

  const _WaterfallSection({required this.steps, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return KasbyCard(
        padding: const EdgeInsets.all(KasbySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'investment_waterfall'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: KasbySpacing.lg),
            KasbyWaterfallChart(
              steps: steps.toList(),
              height: 200,
            ),
          ],
        ),
      );
    });
  }
}

// ─── BENCHMARK SECTION ────────────────────────────────────────

class _BenchmarkSection extends StatelessWidget {
  final RxList<Map<String, dynamic>> benchmarks;
  final bool isDark;

  const _BenchmarkSection({required this.benchmarks, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final maxRoi = benchmarks.fold<double>(0, (m, b) {
        final expected = (b['expectedRoi'] as num?)?.toDouble() ?? 0;
        final actual = (b['actualRoi'] as num?)?.toDouble() ?? 0;
        return [m, expected, actual].reduce((a, b) => a > b ? a : b);
      });
      final scale = maxRoi > 0 ? maxRoi : 1.0;

      return KasbyCard(
        padding: const EdgeInsets.all(KasbySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'benchmark_comparison'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: KasbySpacing.lg),
            ...benchmarks.map((b) {
              final planName = b['planName'] as String? ?? 'Plan';
              final expected = (b['expectedRoi'] as num?)?.toDouble() ?? 0;
              final actual = (b['actualRoi'] as num?)?.toDouble() ?? 0;
              final isAbove = actual >= expected;

              return Padding(
                padding: const EdgeInsets.only(bottom: KasbySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.onSurfaceLight,
                      ),
                    ),
                    const SizedBox(height: KasbySpacing.sm),
                    _BenchmarkBar(
                      label: 'expected_roi'.tr,
                      value: expected,
                      maxValue: scale,
                      color: AppColors.darkGold,
                      isDark: isDark,
                    ),
                    const SizedBox(height: KasbySpacing.xs),
                    _BenchmarkBar(
                      label: 'actual_roi'.tr,
                      value: actual,
                      maxValue: scale,
                      color: isAbove ? AppColors.softGreen : AppColors.error,
                      isDark: isDark,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

class _BenchmarkBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final bool isDark;

  const _BenchmarkBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: KasbySpacing.sm),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(1)}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── INSIGHTS SECTION ─────────────────────────────────────────

class _InsightsSection extends StatelessWidget {
  final RxList<String> insights;
  final bool isDark;

  const _InsightsSection({required this.insights, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 20,
                color: AppColors.darkGold,
              ),
              const SizedBox(width: KasbySpacing.sm),
              Text(
                'financial_insights'.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: KasbySpacing.lg),
          ...insights.map((key) => Padding(
                padding: const EdgeInsets.only(bottom: KasbySpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.darkGold,
                    ),
                    const SizedBox(width: KasbySpacing.md),
                    Expanded(
                      child: Text(
                        key.tr,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
