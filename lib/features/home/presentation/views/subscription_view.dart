import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/features/home/presentation/controllers/subscription_controller.dart';


class SubscriptionView extends StatefulWidget {
  const SubscriptionView({super.key});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> {
  final controller = Get.put(SubscriptionController());
  bool isYearly = true;
  int selectedPlanIndex = 1; // 0 for Free, 1 for Premium

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('premium_account'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow Effects
          Positioned(
            top: -100,
            right: -100,
            child:
                Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.darkGold.withValues(alpha: 0.15),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 1000.ms)
                    .scale(begin: const Offset(0.5, 0.5)),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Header Image/Icon Section
                _buildHeader(),
                const SizedBox(height: 30),

                // Selection Cards
                _buildPlanSelection(),
                const SizedBox(height: 30),

                if (selectedPlanIndex == 1) ...[
                  _buildToggle(),
                  const SizedBox(height: 30),
                  _buildBenefitsSection('premium_features'.tr, [
                    {
                      'icon': Icons.card_giftcard_rounded,
                      'title': 'exclusive_gift'.tr,
                      'desc': 'exclusive_gift_desc'.tr,
                    },
                    {
                      'icon': Icons.speed_rounded,
                      'title': 'priority_withdrawals'.tr,
                      'desc': 'priority_withdrawals_desc'.tr,
                    },
                    {
                      'icon': Icons.all_inclusive_rounded,
                      'title': 'unlimited_investments'.tr,
                      'desc': 'unlimited_investments_desc'.tr,
                    },
                  ]),
                ] else ...[
                  const SizedBox(height: 30),
                  _buildBenefitsSection('free_plan'.tr, [
                    {
                      'icon': Icons.schedule_rounded,
                      'title': 'limited_withdrawals'.tr,
                      'desc': 'limited_withdrawals_desc'.tr,
                    },
                    {
                      'icon': Icons.help_outline_rounded,
                      'title': 'basic_support'.tr,
                      'desc': 'basic_support_desc'.tr,
                    },
                    {
                      'icon': Icons.lock_outline_rounded,
                      'title': 'limited_investments'.tr,
                      'desc': 'limited_investments_desc'.tr,
                    },
                  ]),
                ],

                const SizedBox(height: 40),
                _buildPricingCard(),
                const SizedBox(height: 24),

                Text(
                  'terms_apply'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient.withOpacity(0.2),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                )
                .fadeOut(),
            Icon(
              Icons.stars_rounded,
              size: 80,
              color: AppColors.darkGold,
            ).animate().shimmer(
              duration: 2000.ms,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'premium_account'.tr,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'activate_desc'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleItem('monthly'.tr, !isYearly),
          _buildToggleItem('yearly'.tr, isYearly, badge: 'save_20'.tr),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isActive, {String? badge}) {
    return GestureDetector(
      onTap: () => setState(() => isYearly = label == 'yearly'.tr),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.darkGold : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.black.withValues(alpha: 0.2)
                      : AppColors.softGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? Colors.black : AppColors.softGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSelection() {
    return Row(
      children: [
        Expanded(
          child: _buildPlanCardItem(
            'free_plan'.tr,
            'price_free'.tr,
            0,
            AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPlanCardItem(
            'premium_account'.tr,
            isYearly ? 'price_year'.tr : 'price_month'.tr,
            1,
            AppColors.darkGold,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCardItem(
    String title,
    String price,
    int index,
    Color accentColor,
  ) {
    bool isSelected = selectedPlanIndex == index;
    return GestureDetector(
      onTap: () => setState(() => selectedPlanIndex = index),
      child: KasbyCard(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        color: isSelected
            ? accentColor.withValues(alpha: 0.1)
            : (isDark ? AppColors.surface : AppColors.surfaceLight),
        border: Border.all(
          color: isSelected
              ? accentColor
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05)),
          width: 2,
        ),
        child: Obx(() {
          final isActive = controller.activeSubscription['tier'] == (index == 0 ? 'free' : 'vip');
          return Column(
            children: [
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.softGreen, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.softGreen, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'active_plan'.tr,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.softGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? accentColor : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBenefitsSection(
    String title,
    List<Map<String, dynamic>> benefits,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ...List.generate(benefits.length, (index) {
          final benefit = benefits[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildBenefitItem(
              benefit['icon'],
              benefit['title'],
              benefit['desc'],
              index,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBenefitItem(
    IconData icon,
    String title,
    String desc,
    int index,
  ) {
    return KasbyCard(
          padding: const EdgeInsets.all(16),
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.darkGold, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (400 + (index * 100)).ms)
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildPricingCard() {
    return KasbyCard(
      color: isDark ? AppColors.surface : AppColors.surfaceLight,
      hasShadow: true,
      child: Column(
        children: [
          Text(
                selectedPlanIndex == 0
                    ? 'price_free'.tr
                    : (isYearly ? 'price_year'.tr : 'price_month'.tr),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.onSurface
                      : AppColors.onSurfaceLight,
                ),
              )
              .animate(target: isYearly ? 1 : 0)
              .shimmer(duration: const Duration(milliseconds: 1000)),
          const SizedBox(height: 8),
          Text(
            selectedPlanIndex == 0 ? 'free_plan_desc'.tr : 'activation_fee'.tr,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            selectedPlanIndex == 0
                ? 'free_plan_keywords'.tr
                : 'premium_plan_keywords'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color:
                  (selectedPlanIndex == 0
                          ? AppColors.textSecondary
                          : AppColors.darkGold)
                      .withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          Obx(
            () {
              final activeTier = controller.activeSubscription['tier'];
              final isActivePlan = (selectedPlanIndex == 0 && activeTier == 'free') || 
                                 (selectedPlanIndex == 1 && activeTier == 'vip');
              
              String buttonText = '';
              VoidCallback? onPressed;
              Color buttonColor = AppColors.primary;
              
              if (selectedPlanIndex == 0) {
                // Free Plan logic
                if (activeTier == 'free') {
                  buttonText = '${'active_plan'.tr}: ${controller.countdownText.value}';
                  onPressed = null;
                  buttonColor = controller.countdownColor.value;
                } else {
                  buttonText = 'activate_free_plan'.tr;
                  onPressed = () => controller.activateFreePlan();
                }
              } else {
                // VIP Plan logic
                final isCurrentYearly = controller.activeSubscription['is_yearly'] == true;
                final isSameFrequency = activeTier == 'vip' && isCurrentYearly == isYearly;

                if (isSameFrequency) {
                  buttonText = '${'active_plan'.tr}: ${controller.countdownText.value}';
                  onPressed = null;
                  buttonColor = controller.countdownColor.value;
                } else {
                  buttonText = 'activate_now'.tr;
                  onPressed = () => controller.buySubscription(isYearly: isYearly, tier: 'vip');
                }
              }

              return Column(
                children: [
                  KasbyButton(
                    text: buttonText,
                    isLoading: controller.isLoading.value,
                    onPressed: onPressed,
                    color: buttonColor,
                  ),
                  if (isActivePlan && controller.countdownText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: controller.remainingPercentage.value,
                        backgroundColor: controller.countdownColor.value.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(controller.countdownColor.value),
                        minHeight: 6,
                      ),
                    ).animate().fadeIn().shimmer(duration: const Duration(seconds: 3)),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    ).animate().scale(
      begin: const Offset(0.9, 0.9),
      duration: 400.ms,
      curve: Curves.easeOutBack,
    );
  }
}
