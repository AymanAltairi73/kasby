import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/locale_helper.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'OnboardingView',
      method: 'initState',
      feature: 'Onboarding',
      status: 'INFO',
    );
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'OnboardingView',
      method: 'dispose',
      feature: 'Onboarding',
      status: 'INFO',
    );
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<OnboardingData> onboardingPages = [
      OnboardingData(
        title: 'ob1_title'.tr,
        description: 'ob1_desc'.tr,
        icon: Icons.account_balance_wallet_rounded,
      ),
      OnboardingData(
        title: 'ob2_title'.tr,
        description: 'ob2_desc'.tr,
        icon: Icons.trending_up_rounded,
      ),
      OnboardingData(
        title: 'ob3_title'.tr,
        description: 'ob3_desc'.tr,
        icon: Icons.groups_rounded,
      ),
      // 4th slide — security messaging (audit M8)
      OnboardingData(
        title: 'security_matters_title'.tr,
        description: 'security_matters_desc'.tr,
        icon: Icons.shield_rounded,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: onboardingPages.length,
            itemBuilder: (context, index) {
              final data = onboardingPages[index];
              return Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(data.icon, size: 120, color: AppColors.darkGold),
                    const SizedBox(height: 60),
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      data.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          // Skip for returning installs (audit: add "Skip")
          Positioned(
            top: 50,
            left: 20,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'skip'.tr,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surface
                          : AppColors.surfaceLight)
                      .withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.darkGold.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: AppColors.darkGold,
                ),
              ),
              onPressed: () {
                if (Get.locale?.languageCode == 'ar') {
                  Get.updateLocale(const Locale('en', 'US'));
                  LocaleHelper.saveLanguageCode('en');
                } else {
                  Get.updateLocale(const Locale('ar', 'SA'));
                  LocaleHelper.saveLanguageCode('ar');
                }
              },
            ),
          ),
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    onboardingPages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.darkGold
                            : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.surface
                                : AppColors.textSecondary.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                KasbyButton(
                  text: _currentPage == onboardingPages.length - 1
                      ? 'start_now'.tr
                      : 'next'.tr,
                  onPressed: () {
                    if (_currentPage < onboardingPages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    } else {
                      _completeOnboarding();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final stopwatch = Stopwatch()..start();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      SafeGetx.debugTrace(
        className: 'OnboardingView',
        method: '_completeOnboarding',
        feature: 'Onboarding',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
      );
      Get.offAllNamed(Routes.login);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'OnboardingView',
        method: '_completeOnboarding',
        feature: 'Onboarding',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}
