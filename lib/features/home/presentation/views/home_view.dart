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
import 'package:kasby/features/home/presentation/widgets/home_slider.dart';
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const HomeAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HomeSlider()
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
                    const HomeBalanceCard()
                        .animate(autoPlay: motion)
                        .fadeIn(
                          delay: KasbyMotion.duration(
                            context,
                            const Duration(milliseconds: 400),
                          ),
                        )
                        .scale(begin: const Offset(0.95, 0.95)),
                    const SizedBox(height: 24),
                    const HomePortfolioInsights(),
                    const SizedBox(height: 24),
                    const HomeQuickActions()
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
                    const HomeRecentTransactions()
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
