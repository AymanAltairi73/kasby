import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/home/presentation/widgets/home_app_bar.dart';
import 'package:kasby/features/home/presentation/widgets/home_balance_card.dart';
import 'package:kasby/features/home/presentation/widgets/home_kyc_banner.dart';
import 'package:kasby/features/home/presentation/widgets/home_portfolio_insights.dart';
import 'package:kasby/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:kasby/features/home/presentation/widgets/home_recent_transactions.dart';
import 'package:kasby/core/tour/tour_controller.dart';
import 'package:kasby/core/tour/tour_target_keys.dart';
import 'package:kasby/features/home/presentation/widgets/home_slider.dart';
// import 'package:kasby/core/widgets/investment_plan_card.dart';
// import 'package:kasby/core/utils/number_formatter.dart';
import 'package:kasby/routes/app_routes.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final homeController = HomeController.to;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'HomeView',
      method: 'initState',
      feature: 'Home',
      status: 'INFO',
      message: 'Tab mounted in MainShell',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await TourController.to.tryConsumePendingAutoHomeTour(context);
      if (!mounted) return;
      await TourController.to.tryStartAutoHomeTour(context);
    });
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'HomeView',
      method: 'dispose',
      feature: 'Home',
      status: 'INFO',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = KasbyMotion.enabled(context);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.darkGold,
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        onRefresh: () => homeController.refreshAll(),
        child: CustomScrollView(
          controller: TourTargetKeys.homeScroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const HomeAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyedSubtree(
                      key: TourTargetKeys.welcome,
                      child: SizedBox(
                        width: double.infinity,
                        height: 216,
                        child: HomeSlider(),
                      ),
                    )
                        .animate(autoPlay: motion)
                        .fadeIn(
                          duration: KasbyMotion.duration(
                            context,
                            const Duration(milliseconds: 600),
                          ),
                        )
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 24),
                    Obx(() {
                      final profile = homeController.profile.value;
                      if (profile != null && profile.kycStatus != 'verified') {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: HomeKycBanner(),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    HomeBalanceCard(
                      kspSectionKey: TourTargetKeys.kspRewards,
                      tourKey: TourTargetKeys.wallet,
                    )
                        .animate(autoPlay: motion)
                        .fadeIn(
                          delay: KasbyMotion.duration(
                            context,
                            const Duration(milliseconds: 400),
                          ),
                        )
                        .scale(begin: const Offset(0.95, 0.95)),
                    const SizedBox(height: 24),
                    KeyedSubtree(
                      key: TourTargetKeys.referralSummary,
                      child: const HomePortfolioInsights(),
                    ),
                    const SizedBox(height: 24),
                    // // ── Active Investment Card ──
                    // Obx(() {
                    //   final activeInvs = homeController.myInvestments
                    //       .where((inv) => inv.status == 'active')
                    //       .toList();
                    //   if (activeInvs.isEmpty) return const SizedBox.shrink();

                    //   final latestActive = activeInvs.first;
                    //   final isAr = Get.locale?.languageCode == 'ar';
                    //   final plan = latestActive.investment;
                    //   final nameAr = plan?.nameAr;
                    //   final nameEn = plan?.nameEn;
                    //   final String planName;
                    //   if (isAr == true) {
                    //     if (nameAr != null && nameAr.isNotEmpty) {
                    //       planName = nameAr;
                    //     } else if (nameEn != null && nameEn.isNotEmpty) {
                    //       planName = nameEn;
                    //     } else {
                    //       planName = 'خطة استثمارية';
                    //     }
                    //   } else {
                    //     if (nameEn != null && nameEn.isNotEmpty) {
                    //       planName = nameEn;
                    //     } else if (nameAr != null && nameAr.isNotEmpty) {
                    //       planName = nameAr;
                    //     } else {
                    //       planName = 'Investment Plan';
                    //     }
                    //   }

                    //   final planImageName = (nameEn ?? nameAr ?? '').toLowerCase();
                    //   String imagePath;
                    //   if (planImageName.contains('gold') || planImageName.contains('ذهب')) {
                    //     imagePath = 'assets/images/gold.png';
                    //   } else if (planImageName.contains('silver') || planImageName.contains('sliver') || planImageName.contains('فض')) {
                    //     imagePath = 'assets/images/sliver.png';
                    //   } else if (planImageName.contains('real') || planImageName.contains('estate') || planImageName.contains('عقار')) {
                    //     imagePath = 'assets/images/real_estate.png';
                    //   } else {
                    //     imagePath = 'assets/images/gold.png';
                    //   }

                    //   return Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       HomeSectionHeader(
                    //         title: 'active_investment'.tr,
                    //         onSeeAll: () {
                    //           if (Get.currentRoute != Routes.myInvestments) {
                    //             Get.toNamed(Routes.myInvestments);
                    //           }
                    //         },
                    //       ),
                    //       const SizedBox(height: 12),
                    //       InvestmentPlanCard(
                    //         id: plan?.id ?? latestActive.id,
                    //         title: planName,
                    //         profit: 'up_to_profit'.trParams({
                    //           'profit': KasbyNumberFormatter.formatProfitPercentage(
                    //             latestActive.profitPercentage,
                    //           ),
                    //         }),
                    //         minAmount: '\$${latestActive.amount.toStringAsFixed(0)}',
                    //         imagePath: imagePath,
                    //         color: AppColors.darkGold,
                    //       ),
                    //       const SizedBox(height: 24),
                    //     ],
                    //   )
                    //       .animate(autoPlay: motion)
                    //       .fadeIn(
                    //         delay: KasbyMotion.duration(
                    //           context,
                    //           const Duration(milliseconds: 700),
                    //         ),
                    //       )
                    //       .slideY(begin: 0.1, end: 0);
                    // }),
                    HomeQuickActions(
                      tourKey: TourTargetKeys.quickActions,
                      marketplaceKey: TourTargetKeys.marketplace,
                    )
                        .animate(autoPlay: motion)
                        .fadeIn(
                          delay: KasbyMotion.duration(
                            context,
                            const Duration(milliseconds: 800),
                          ),
                        ),
                    const SizedBox(height: 32),
                    HomeSectionHeader(
                      title: 'recent_transactions'.tr,
                      onSeeAll: () => Get.toNamed(Routes.allTransactions),
                    )
                        .animate(autoPlay: motion)
                        .fadeIn(
                          delay: KasbyMotion.duration(
                            context,
                            const Duration(milliseconds: 1000),
                          ),
                        ),
                    const SizedBox(height: 16),
                    HomeRecentTransactions(key: TourTargetKeys.transactions)
                        .animate(autoPlay: motion)
                        .fadeIn(
                          delay: KasbyMotion.duration(
                            context,
                            const Duration(milliseconds: 1100),
                          ),
                        )
                        .slideY(begin: 0.1, end: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
