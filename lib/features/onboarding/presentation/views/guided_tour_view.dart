import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/tour_step_model.dart';
import 'package:kasby/core/services/tour_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/routes/app_routes.dart';

class GuidedTourView extends StatefulWidget {
  const GuidedTourView({super.key});

  @override
  State<GuidedTourView> createState() => _GuidedTourViewState();
}

class _GuidedTourViewState extends State<GuidedTourView>
    with TickerProviderStateMixin {
  PageController? _pageController;
  int _currentPage = 0;
  bool _isLoading = true;

  static const _steps = <TourStepModel>[
    TourStepModel(
      titleKey: 'tour_dashboard_title',
      descriptionKey: 'tour_dashboard_desc',
      icon: Icons.dashboard_rounded,
      color: Color(0xFF3B82F6),
      route: Routes.home,
    ),
    TourStepModel(
      titleKey: 'tour_wallet_title',
      descriptionKey: 'tour_wallet_desc',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF10B981),
      route: Routes.wallet,
    ),
    TourStepModel(
      titleKey: 'tour_investments_title',
      descriptionKey: 'tour_investments_desc',
      icon: Icons.trending_up_rounded,
      color: Color(0xFFF59E0B),
      route: Routes.investmentPlans,
    ),
    TourStepModel(
      titleKey: 'tour_team_title',
      descriptionKey: 'tour_team_desc',
      icon: Icons.groups_rounded,
      color: Color(0xFF8B5CF6),
      route: Routes.myTeam,
    ),
    TourStepModel(
      titleKey: 'tour_referral_title',
      descriptionKey: 'tour_referral_desc',
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFEC4899),
    ),
    TourStepModel(
      titleKey: 'tour_notifications_title',
      descriptionKey: 'tour_notifications_desc',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFEF4444),
      route: Routes.notifications,
    ),
    TourStepModel(
      titleKey: 'tour_profile_title',
      descriptionKey: 'tour_profile_desc',
      icon: Icons.person_rounded,
      color: Color(0xFF06B6D4),
      route: Routes.profile,
    ),
  ];

  bool get _isLastPage => _currentPage == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _loadSavedStep();
  }

  Future<void> _loadSavedStep() async {
    final savedStep = await TourService.getLastStep();
    final initial = savedStep.clamp(0, _steps.length - 1);
    if (!mounted) return;
    setState(() {
      _currentPage = initial;
      _pageController = PageController(initialPage: initial);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    HapticFeedback.lightImpact();
    if (_isLastPage) {
      await _completeTour();
    } else {
      await TourService.saveLastStep(_currentPage + 1);
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _skipTour() async {
    HapticFeedback.selectionClick();
    await TourService.markSkipped();
    Get.offAllNamed(Routes.home);
  }

  Future<void> _completeTour() async {
    HapticFeedback.mediumImpact();
    await TourService.markCompleted();
    Get.offAllNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            Expanded(
              child: PageView.builder(
                controller: _pageController!,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  TourService.saveLastStep(index);
                },
                itemBuilder: (context, index) {
                  return _TourStepPage(
                    step: _steps[index],
                    stepIndex: index,
                    totalSteps: _steps.length,
                  );
                },
              ),
            ),
            _buildBottomNav(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KasbySpacing.lg,
        vertical: KasbySpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${'guided_tour'.tr}  ${_currentPage + 1}/${_steps.length}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!_isLastPage)
            TextButton(
              onPressed: _skipTour,
              child: Text(
                'skip'.tr,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KasbySpacing.xxl,
        KasbySpacing.lg,
        KasbySpacing.xxl,
        KasbySpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepIndicator(),
          const SizedBox(height: KasbySpacing.xl),
          KasbyButton(
            text: _isLastPage ? 'start_exploring'.tr : 'next_step'.tr,
            onPressed: _nextPage,
            icon: _isLastPage ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_steps.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? _steps[_currentPage].color
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

class _TourStepPage extends StatelessWidget {
  final TourStepModel step;
  final int stepIndex;
  final int totalSteps;

  const _TourStepPage({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KasbySpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          _buildIconArea(isDark),
          const SizedBox(height: KasbySpacing.huge),
          _buildTextContent(isDark),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildIconArea(bool isDark) {
    final iconBgColor = step.color.withValues(alpha: isDark ? 0.15 : 0.1);
    final ringColor = step.color.withValues(alpha: isDark ? 0.08 : 0.05);

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ringColor,
      ),
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconBgColor,
            boxShadow: [
              BoxShadow(
                color: step.color.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            step.icon,
            size: 64,
            color: step.color,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 400.ms),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildTextContent(bool isDark) {
    return Column(
      children: [
        Text(
          step.titleKey.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            height: 1.2,
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 200.ms),
        const SizedBox(height: KasbySpacing.lg),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: step.color,
          ),
        )
            .animate()
            .scaleX(
              begin: 0,
              end: 1,
              duration: 400.ms,
              delay: 350.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: KasbySpacing.lg),
        Text(
          step.descriptionKey.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 400.ms)
            .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 400.ms),
      ],
    );
  }
}
