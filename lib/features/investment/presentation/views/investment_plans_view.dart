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

class InvestmentPlansView extends StatefulWidget {
  const InvestmentPlansView({super.key});

  @override
  State<InvestmentPlansView> createState() => _InvestmentPlansViewState();
}

class _InvestmentPlansViewState extends State<InvestmentPlansView> {
  final RxList<InvestmentPlanModel> plans = <InvestmentPlanModel>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
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
    } catch (e) {
      debugPrint('Error fetching plans: $e');
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('investment_plans'.tr),
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back_ios_new_rounded),
        //   onPressed: () => ShellController.to.handleBack(),
        // ),
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

          return ListView.separated(
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

              return InvestmentPlanCard(
                    id: plan.id,
                    title: plan.nameAr,
                    profit: '${plan.profitPercentage.toInt()}%',
                    rawProfitPercentage: plan.profitPercentage.toDouble(),
                    minAmount: '\$${plan.minAmount.toInt()}',
                    imagePath: _getPlanImage(plan.nameEn ?? plan.nameAr),
                    color: _planColor(plan.riskLevel),
                    amounts: amounts,
                  )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: index * 200),
                    duration: 600.ms,
                  )
                  .slideY(begin: 0.2, end: 0);
            },
          );
        }),
      ),
    );
  }
}
