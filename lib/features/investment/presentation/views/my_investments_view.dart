import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/investment_plan_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/widgets/mini_charts.dart';
import 'package:kasby/core/utils/number_formatter.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/investment/presentation/widgets/active_investment_card.dart';

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

  String _formatPlanDuration(int? days) {
    if (days == null || days >= 900 || days == 30) {
      return 'duration_2_5_years'.tr;
    }
    if (days >= 365) {
      final years = days / 365.0;
      return years == years.roundToDouble()
          ? '${years.toInt()} ${'years'.tr}'
          : '${years.toStringAsFixed(1)} ${'years'.tr}';
    }
    final months = (days / 30).round();
    return '$months ${'months'.tr}';
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.darkGold.withValues(alpha: 0.15),
                              AppColors.darkGold.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.darkGold.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.account_balance_rounded,
                          size: 56,
                          color: AppColors.darkGold,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 24),
                      Text(
                        'no_plans'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 12),
                      Text(
                        'no_plans_desc'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _fetchPlans,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text('refresh'.tr),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkGold,
                          side: BorderSide(
                            color: AppColors.darkGold.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),
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
                      title: Get.locale?.languageCode == 'ar'
                          ? plan.nameAr
                          : (plan.nameEn ?? plan.nameAr),
                      profit: KasbyNumberFormatter.formatProfitPercentage(
                        plan.profitPercentage,
                      ),
                      minAmount: '\$${plan.minAmount.toInt()}',
                      imagePath: _getPlanImage(plan.nameEn ?? plan.nameAr),
                      color: _planColor(plan.riskLevel),
                      amounts: amounts,
                      durationDays: plan.durationDays,
                      duration: _formatPlanDuration(plan.durationDays),
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
    debugPrint(
      '[PROFIT_LIFECYCLE] event: MyInvestmentsView opened | isActive: ${widget.isActive}',
    );
    SafeGetx.debugTrace(
      className: '_InvestmentsList',
      method: 'initState',
      feature: 'Investment',
      status: 'INFO',
      params: {'isActive': widget.isActive},
    );
    _fetchInvestments();
  }

  @override
  void dispose() {
    debugPrint(
      '[PROFIT_LIFECYCLE] event: MyInvestmentsView disposed | isActive: ${widget.isActive}',
    );
    super.dispose();
  }

  Future<void> _fetchInvestments() async {
    if (!SupabaseService.isLoggedIn) return;
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    try {
      final response = await SupabaseService.client
          .from('user_investments')
          .select('*, investment:investment_plans(*)')
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.softGreen.withValues(alpha: 0.15),
                              AppColors.softGreen.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.softGreen.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.trending_up_rounded,
                          size: 56,
                          color: AppColors.softGreen,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 24),
                      Text(
                        'no_investments'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 12),
                      Text(
                        'no_investments_desc'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 24),
                      KasbyButton(
                        text: 'browse_plans'.tr,
                        onPressed: () => Get.toNamed(Routes.investmentPlans),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),
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
            final isNotActive = inv.status == 'not_active';
            final isAr = Get.locale?.languageCode == 'ar';
            final plan = inv.investment;
            final nameAr = plan?.nameAr;
            final nameEn = plan?.nameEn;
            final String planName;
            if (isAr) {
              if (nameAr != null && nameAr.isNotEmpty) {
                planName = nameAr;
              } else if (nameEn != null && nameEn.isNotEmpty) {
                planName = nameEn;
              } else {
                planName = 'خطة استثمارية';
              }
            } else {
              if (nameEn != null && nameEn.isNotEmpty) {
                planName = nameEn;
              } else if (nameAr != null && nameAr.isNotEmpty) {
                planName = nameAr;
              } else {
                planName = 'Investment Plan';
              }
            }

            return Hero(
              tag: 'inv_${inv.id}',
              child: Material(
                color: Colors.transparent,
                child: _buildPixelPerfectActiveCard(
                  context: context,
                  inv: inv,
                  plan: plan,
                  planName: planName,
                  isActive: isActive,
                  isNotActive: isNotActive,
                  isDark: isDark,
                  isAr: isAr,
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildPixelPerfectActiveCard({
    required BuildContext context,
    required UserInvestmentModel inv,
    required InvestmentPlanModel? plan,
    required String planName,
    required bool isActive,
    required bool isNotActive,
    required bool isDark,
    required bool isAr,
  }) {
    return ActiveInvestmentCard(
      inv: inv,
      plan: plan,
      planName: planName,
      isActive: isActive,
      isNotActive: isNotActive,
      isDark: isDark,
      isAr: isAr,
      onRefresh: _fetchInvestments,
    );
  }

  /// Portfolio performance summary (audit C20): totals, return trend sparkline /// Portfolio performance summary (audit C20): totals, return trend sparkline
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
      final profit = inv.actualProfit ?? 0.0;
      totalReturns += profit;
      cumulative += inv.amount;
      trend.add(cumulative);
      final planName = (Get.locale?.languageCode == 'ar'
          ? (inv.investment?.nameAr ?? inv.investment?.nameEn)
          : (inv.investment?.nameEn ?? inv.investment?.nameAr))
          ?? '\$${inv.amount.toStringAsFixed(0)}';
      segments.add(
        AllocationSegment(
          label: planName,
          value: inv.amount,
          color: palette[i % palette.length],
        ),
      );
    }

    return KasbyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'total_portfolio_value'.tr,
          //   style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          // ),
          // const SizedBox(height: 4),
          // Text(
          //   '\$${(totalInvested + totalReturns).toStringAsFixed(2)}',
          //   style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          // ),
          //const SizedBox(height: KasbySpacing.lg),
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
