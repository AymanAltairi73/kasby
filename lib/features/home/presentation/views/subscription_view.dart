import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/features/home/presentation/controllers/subscription_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class SubscriptionView extends StatefulWidget {
  const SubscriptionView({super.key});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> {
  final controller = Get.put(SubscriptionController());
  bool isYearly = true;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'SubscriptionView',
      method: 'initState',
      feature: 'Home',
      status: 'INFO',
    );
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'SubscriptionView',
      method: 'dispose',
      feature: 'Home',
      status: 'INFO',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'subscriptions'.tr,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
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
                        color: AppColors.darkGold.withValues(alpha: 0.12),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 1000.ms)
                    .scale(begin: const Offset(0.5, 0.5)),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.darkGold.withValues(alpha: 0.06),
              ),
            ).animate().fadeIn(duration: 1200.ms, delay: 300.ms),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Header Image/Icon Section
                _buildHeader(),
                const SizedBox(height: 28),

                _buildToggle(),
                const SizedBox(height: 28),

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

                const SizedBox(height: 36),
                _buildPricingCard(),
                const SizedBox(height: 20),

                Text(
                  'terms_apply'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
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
              size: 72,
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
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'activate_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleItem('monthly'.tr, !isYearly),
          _buildToggleItem('yearly'.tr, isYearly, badge: 'save_20'.tr),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildToggleItem(String label, bool isActive, {String? badge}) {
    return GestureDetector(
      onTap: () => setState(() => isYearly = isActive ? isYearly : !isYearly),
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
                fontSize: 14,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.black.withValues(alpha: 0.2)
                      : AppColors.softGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
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

  Widget _buildBenefitsSection(
    String title,
    List<Map<String, dynamic>> benefits,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(benefits.length, (index) {
          final benefit = benefits[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
    final accent = AppColors.darkGold;

    return KasbyCard(
          padding: const EdgeInsets.all(16),
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: KasbyRadius.cardR,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
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
      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
      hasShadow: true,
      border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.2)),
      child: Column(
        children: [
          Text(
                isYearly ? 'price_year'.tr : 'price_month'.tr,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? AppColors.onSurface
                      : AppColors.onSurfaceLight,
                ),
              )
              .animate(target: isYearly ? 1 : 0)
              .shimmer(duration: const Duration(milliseconds: 1000)),
          const SizedBox(height: 8),
          Text(
            'activation_fee'.tr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'premium_plan_keywords'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.darkGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Obx(() {
            final activeTier = controller.activeSubscription['tier'];
            final isCurrentYearly =
                controller.activeSubscription['is_yearly'] == true;
            final isSameFrequency =
                activeTier == 'vip' && isCurrentYearly == isYearly;

            String buttonText = '';
            VoidCallback? onPressed;
            Color buttonColor = AppColors.primary;

            if (isSameFrequency) {
              buttonText =
                  '${'active_plan'.tr}: ${controller.countdownText.value}';
              onPressed = null;
              buttonColor = controller.countdownColor.value;
            } else {
              buttonText = 'activate_now'.tr;
              onPressed = () =>
                  controller.buySubscription(isYearly: isYearly, tier: 'vip');
            }

            return Column(
              children: [
                KasbyButton(
                  text: buttonText,
                  isLoading: controller.isLoading.value,
                  onPressed: onPressed,
                  color: buttonColor,
                ),
                if (activeTier == 'vip' &&
                    controller.countdownText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: controller.remainingPercentage.value,
                      backgroundColor: controller.countdownColor.value
                          .withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        controller.countdownColor.value,
                      ),
                      minHeight: 6,
                    ),
                  ).animate().fadeIn().shimmer(
                    duration: const Duration(seconds: 3),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    ).animate().scale(
      begin: const Offset(0.9, 0.9),
      duration: 400.ms,
      curve: Curves.easeOutBack,
    );
  }
}
