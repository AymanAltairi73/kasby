import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/investment_plan_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/widgets/mini_charts.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/routes/app_routes.dart';

class MyInvestmentsView extends StatelessWidget {
  const MyInvestmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('my_investments'.tr),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Get.back(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'portfolio_analytics'.tr,
              onPressed: () => Get.toNamed(Routes.portfolioAnalytics),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.darkGold,
            labelColor: AppColors.darkGold,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              IndicatorTab(text: 'active'.tr),
              IndicatorTab(text: 'investment_plans'.tr),
            ],
          ),
        ),
        body: TabBarView(
          children: [_InvestmentsList(isActive: true), _InvestmentPlansList()],
        ),
      ),
    );
  }
}

class IndicatorTab extends StatelessWidget {
  final String text;
  const IndicatorTab({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}

class _InvestmentPlansList extends StatefulWidget {
  const _InvestmentPlansList();

  @override
  State<_InvestmentPlansList> createState() => _InvestmentPlansListState();
}

class _InvestmentPlansListState extends State<_InvestmentPlansList> {
  final RxList<InvestmentPlanModel> plans = <InvestmentPlanModel>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: '_InvestmentPlansList',
      method: 'initState',
      feature: 'Investment',
      status: 'INFO',
    );
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    try {
      final response = await SupabaseService.client
          .from('investment_plans')
          .select()
          .eq('is_active', true)
          .order('min_amount');

      plans.value = (response as List)
          .map((json) => InvestmentPlanModel.fromJson(json))
          .toList();
      SafeGetx.debugTrace(
        className: '_InvestmentPlansList',
        method: '_fetchPlans',
        feature: 'Investment',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'count': plans.length},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: '_InvestmentPlansList',
        method: '_fetchPlans',
        feature: 'Investment',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Color _planColor(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return const Color(0xFFC0C0C0); // silver
      case 'high':
        return const Color(0xFF4CAF50); // green
      default:
        return const Color(0xFFFFD700); // gold
    }
  }

  String _getPlanImage(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('gold') || lowerName.contains('ذهب')) {
      return 'assets/images/gold.png';
    } else if (lowerName.contains('silver') ||
        lowerName.contains('sliver') ||
        lowerName.contains('فض')) {
      return 'assets/images/sliver.png';
    } else if (lowerName.contains('real') ||
        lowerName.contains('estate') ||
        lowerName.contains('عقار')) {
      return 'assets/images/real_estate.png';
    }
    return 'assets/images/gold.png';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (isLoading.value) {
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (_, __) => const KasbyShimmer.card(height: 320),
        );
      }

      if (plans.isEmpty) {
        return RefreshIndicator(
          onRefresh: _fetchPlans,
          color: AppColors.darkGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: Get.height * 0.7,
              child: Center(
                child: Text(
                  'no_plans'.tr,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _fetchPlans,
        color: AppColors.darkGold,
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final plan = plans[index];
            final amounts =
                plan.availableAmounts
                    ?.map((e) => '\$${(e as num).toInt()}')
                    .toList() ??
                [];

            return Hero(
                  tag: 'plan_${plan.id}',
                  child: Material(
                    color: Colors.transparent,
                    child: InvestmentPlanCard(
                      id: plan.id,
                      title: plan.nameAr,
                      profit: '${plan.profitPercentage.toInt()}%',
                      minAmount: '\$${plan.minAmount.toInt()}',
                      imagePath: _getPlanImage(plan.nameEn ?? plan.nameAr),
                      color: _planColor(plan.riskLevel),
                      amounts: amounts,
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: Duration(milliseconds: index * 100))
                .slideY(begin: 0.1, end: 0);
          },
        ),
      );
    });
  }
}

class _InvestmentsList extends StatefulWidget {
  final bool isActive;
  const _InvestmentsList({required this.isActive});

  @override
  State<_InvestmentsList> createState() => _InvestmentsListState();
}

class _InvestmentsListState extends State<_InvestmentsList> {
  final RxList<UserInvestmentModel> investments = <UserInvestmentModel>[].obs;
  final RxBool isLoading = true.obs;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: '_InvestmentsList',
      method: 'initState',
      feature: 'Investment',
      status: 'INFO',
      params: {'isActive': widget.isActive},
    );
    _fetchInvestments();
  }

  Future<void> _fetchInvestments() async {
    if (!SupabaseService.isLoggedIn) return;
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    try {
      final response = await SupabaseService.client
          .from('user_investments')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false);

      investments.value = (response as List)
          .map((json) => UserInvestmentModel.fromJson(json))
          .toList();
      SafeGetx.debugTrace(
        className: '_InvestmentsList',
        method: '_fetchInvestments',
        feature: 'Investment',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'count': investments.length},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: '_InvestmentsList',
        method: '_fetchInvestments',
        feature: 'Investment',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (isLoading.value) {
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => const KasbyShimmer.card(height: 180),
        );
      }

      if (investments.isEmpty) {
        return RefreshIndicator(
          onRefresh: _fetchInvestments,
          color: AppColors.darkGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: Get.height * 0.7,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'no_investments'.tr,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _fetchInvestments,
        color: AppColors.darkGold,
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: investments.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, rawIndex) {
            if (rawIndex == 0) {
              return _buildPortfolioSummary()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.05, end: 0);
            }
            final index = rawIndex - 1;
            final inv = investments[index];
            final isActive = inv.status == 'active';
            final dailyProfit = (inv.amount * inv.profitPercentage / 100 / 30);

            return Hero(
              tag: 'inv_${inv.id}',
              child: Material(
                color: Colors.transparent,
                child: KasbyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${inv.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isActive
                                          ? AppColors.softGreen
                                          : AppColors.textSecondary)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'active'.tr : inv.status.tr,
                              style: TextStyle(
                                color: isActive
                                    ? AppColors.softGreen
                                    : AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildProgressRow(
                        'daily_profit'.tr,
                        '+\$${dailyProfit.toStringAsFixed(2)}',
                        AppColors.softGreen,
                      ),
                      const SizedBox(height: 8),
                      _buildProgressRow(
                        'total_profit'.tr,
                        '+\$${(inv.actualProfit ?? inv.expectedProfit).toStringAsFixed(2)}',
                        AppColors.softGreen,
                      ),
                      const SizedBox(height: 8),
                      if (isActive)
                        Obx(() {
                          final countdown = HomeController.to.investmentCountdowns[inv.id] ?? '--:--:--';
                          return _buildProgressRow(
                            'next_profit'.tr,
                            countdown,
                            AppColors.darkGold,
                          );
                        }),
                      const SizedBox(height: 8),
                      _buildProgressRow(
                        'investment_duration'.tr,
                        '30_months_2_5_years'.tr,
                        AppColors.darkGold,
                      ),
                      const SizedBox(height: 8),
                      if (isActive && inv.endDate != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:
                                inv.remainingDays != null &&
                                    inv.startDate != null
                                ? 1 -
                                      (inv.remainingDays! /
                                          inv.endDate!
                                              .difference(inv.startDate!)
                                              .inDays
                                              .clamp(1, 99999))
                                : 1,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            color: AppColors.darkGold,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildProgressRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Portfolio performance summary (audit C20): totals, return trend sparkline
  /// and an asset allocation bar derived from the user's active investments.
  Widget _buildPortfolioSummary() {
    final palette = <Color>[
      AppColors.darkGold,
      AppColors.softGreen,
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      Colors.teal,
    ];

    double totalInvested = 0;
    double totalReturns = 0;
    final segments = <AllocationSegment>[];
    final trend = <double>[];
    double cumulative = 0;

    for (var i = 0; i < investments.length; i++) {
      final inv = investments[i];
      totalInvested += inv.amount;
      final profit = inv.actualProfit ?? inv.expectedProfit;
      totalReturns += profit;
      cumulative += inv.amount;
      trend.add(cumulative);
      segments.add(
        AllocationSegment(
          label: '\$${inv.amount.toStringAsFixed(0)}',
          value: inv.amount,
          color: palette[i % palette.length],
        ),
      );
    }

    return KasbyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'total_portfolio_value'.tr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${(totalInvested + totalReturns).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: KasbySpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  'total_invested'.tr,
                  '\$${totalInvested.toStringAsFixed(2)}',
                  AppColors.darkGold,
                ),
              ),
              Expanded(
                child: _buildSummaryStat(
                  'total_returns'.tr,
                  '+\$${totalReturns.toStringAsFixed(2)}',
                  AppColors.softGreen,
                ),
              ),
            ],
          ),
          if (trend.length >= 2) ...[
            const SizedBox(height: KasbySpacing.lg),
            Text(
              'portfolio_trend_7d'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: KasbySpacing.sm),
            KasbySparkline(data: trend, lineColor: AppColors.softGreen),
          ],
          if (segments.length >= 2) ...[
            const SizedBox(height: KasbySpacing.lg),
            Text(
              'asset_allocation'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: KasbySpacing.md),
            KasbyAllocationBar(segments: segments),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
