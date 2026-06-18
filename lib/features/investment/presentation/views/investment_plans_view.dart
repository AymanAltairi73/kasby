import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/investment_plan_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
// import 'package:kasby/core/controllers/shell_controller.dart';
import 'package:kasby/core/widgets/empty_state_widget.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class InvestmentPlansView extends StatefulWidget {
  const InvestmentPlansView({super.key});

  @override
  State<InvestmentPlansView> createState() => _InvestmentPlansViewState();
}

class _InvestmentPlansViewState extends State<InvestmentPlansView> {
  final RxList<InvestmentPlanModel> plans = <InvestmentPlanModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString sortBy = 'roi'.obs;
  final RxString filterBy = 'all'.obs;

  List<InvestmentPlanModel> get _filteredPlans {
    final list = plans.toList();
    switch (filterBy.value) {
      case 'short':
        return list.where((p) => (p.durationDays ?? 0) > 0 && (p.durationDays ?? 0) < 30).toList();
      case 'medium':
        return list.where((p) => (p.durationDays ?? 0) >= 30 && (p.durationDays ?? 0) <= 90).toList();
      case 'long':
        return list.where((p) => (p.durationDays ?? 0) > 90).toList();
      case 'all':
      default:
        return list;
    }
  }

  List<InvestmentPlanModel> get _sortedPlans {
    final list = _filteredPlans;
    switch (sortBy.value) {
      case 'amount':
        list.sort((a, b) => a.minAmount.compareTo(b.minAmount));
        break;
      case 'duration':
        list.sort((a, b) => (a.durationDays ?? 0).compareTo(b.durationDays ?? 0));
        break;
      case 'roi':
      default:
        list.sort((a, b) => b.profitPercentage.compareTo(a.profitPercentage));
        break;
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'InvestmentPlansView',
      method: 'initState',
      feature: 'Investment',
      status: 'INFO',
    );
    _fetchPlans();
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'InvestmentPlansView',
      method: 'dispose',
      feature: 'Investment',
      status: 'INFO',
    );
    super.dispose();
  }

  Future<void> _fetchPlans() async {
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    hasError.value = false;
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
        className: 'InvestmentPlansView',
        method: '_fetchPlans',
        feature: 'Investment',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'count': plans.length},
      );
    } catch (e, stack) {
      hasError.value = true;
      SafeGetx.debugTrace(
        className: 'InvestmentPlansView',
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

  String _formatDuration(int? days) {
    if (days == null) return '30_months_2_5_years'.tr;
    if (days >= 365) {
      final years = days / 365.0;
      return years == years.roundToDouble()
          ? '${years.toInt()} ${'years'.tr}'
          : '${years.toStringAsFixed(1)} ${'years'.tr}';
    }
    final months = (days / 30).round();
    return '$months ${'months'.tr}';
  }

  String _formatProfit(double percentage) {
    return percentage == percentage.roundToDouble()
        ? '${percentage.toInt()}%'
        : '${percentage.toStringAsFixed(1)}%';
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('investment_plans'.tr),
      ),
      body: RefreshIndicator(
        color: AppColors.darkGold,
        onRefresh: _fetchPlans,
        child: Obx(() {
          if (isLoading.value) {
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (_, __) => KasbyShimmer.investmentPlanCard(isDark: isDark),
            );
          }

          if (hasError.value) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: ErrorStateWidget(onRetry: _fetchPlans),
              ),
            );
          }

          if (plans.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: EmptyStateWidget(
                  title: 'no_plans'.tr,
                  description: 'no_plans_desc'.tr,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            );
          }

          final sorted = _sortedPlans;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSortBar(isDark),
              const SizedBox(height: KasbySpacing.md),
              _buildFilterChips(isDark),
              const SizedBox(height: KasbySpacing.lg),
              ...sorted.asMap().entries.map((entry) {
                final index = entry.key;
                final plan = entry.value;
                final amounts = plan.availableAmounts
                        ?.map((e) => '\$${(e as num).toInt()}')
                        .toList() ??
                    [];

                final planTitle = Get.locale?.languageCode == 'ar'
                    ? plan.nameAr
                    : (plan.nameEn ?? plan.nameAr);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Semantics(
                    button: true,
                    label: planTitle,
                    child: InvestmentPlanCard(
                        id: plan.id,
                        title: planTitle,
                        profit: _formatProfit(plan.profitPercentage),
                        rawProfitPercentage: plan.profitPercentage.toDouble(),
                        minAmount: '\$${plan.minAmount.toInt()}',
                        imagePath: _getPlanImage(plan.nameEn ?? plan.nameAr),
                        color: _planColor(plan.riskLevel),
                        amounts: amounts,
                        duration: _formatDuration(plan.durationDays),
                      ),
                  ).animate(autoPlay: KasbyMotion.enabled(context))
                      .fadeIn(
                        delay: KasbyMotion.duration(context, Duration(milliseconds: index * 120)),
                        duration: KasbyMotion.duration(context, 500.ms),
                      )
                      .slideY(begin: 0.2, end: 0),
                );
              }),
              _buildRiskDisclosure(isDark),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSortBar(bool isDark) {
    final options = <String, String>{
      'roi': 'sort_roi'.tr,
      'amount': 'sort_amount'.tr,
      'duration': 'sort_duration'.tr,
    };
    return Row(
      children: [
        Icon(Icons.sort_rounded, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: KasbySpacing.sm),
        Text(
          '${'sort_by'.tr}:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: KasbySpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.entries.map((e) {
                final selected = sortBy.value == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: KasbySpacing.sm),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => sortBy.value = e.key,
                    selectedColor: AppColors.darkGold.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? AppColors.darkGold
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = <String, String>{
      'all': 'filter_all'.tr,
      'short': 'filter_short_duration'.tr,
      'medium': 'filter_medium_duration'.tr,
      'long': 'filter_long_duration'.tr,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((e) {
          final selected = filterBy.value == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: KasbySpacing.sm),
            child: FilterChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) => filterBy.value = e.key,
              selectedColor: AppColors.darkGold.withValues(alpha: 0.2),
              checkmarkColor: AppColors.darkGold,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? AppColors.darkGold : AppColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRiskDisclosure(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(KasbySpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.06),
        borderRadius: KasbyRadius.cardR,
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: KasbySpacing.sm),
          Expanded(
            child: Text(
              'risk_disclosure'.tr,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
