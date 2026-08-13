import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/number_formatter.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/services/currency_conversion_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/home/presentation/widgets/ksp_rewards_explainer.dart';
import 'package:kasby/routes/app_routes.dart';

class HomeBalanceCard extends StatelessWidget {
  const HomeBalanceCard({super.key, this.tourKey, this.kspSectionKey});

  final Key? tourKey;
  final Key? kspSectionKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motion = KasbyMotion.enabled(context);
    final currencyController = CurrencyController.to;
    final homeController = HomeController.to;

    return Stack(
      children: [
        Positioned(
          top: -20,
          right: -20,
          child: motion
              ? Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.darkGold.withValues(alpha: 0.15),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      duration: const Duration(seconds: 3),
                      begin: const Offset(1, 1),
                      end: const Offset(1.4, 1.4),
                    )
                    .blurXY(begin: 40, end: 80)
              : const SizedBox.shrink(),
        ),
        Positioned(
          bottom: -30,
          left: -10,
          child: motion
              ? Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.softGreen.withValues(alpha: 0.1),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      duration: const Duration(seconds: 4),
                      begin: const Offset(1, 1),
                      end: const Offset(1.3, 1.3),
                    )
                    .blurXY(begin: 30, end: 60)
              : const SizedBox.shrink(),
        ),
        Hero(
          tag: 'home_balance',
          child: KeyedSubtree(
            key: tourKey,
            child: KasbyCard(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : AppColors.surfaceLight,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.darkGold.withValues(alpha: 0.2),
                width: 1.5,
              ),
              hasShadow: true,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/ksp_coin.png',
                            width: 28,
                            height: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kasby',
                            style: TextStyle(
                              color: AppColors.darkGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.softGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Obx(
                          () => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                color: AppColors.softGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                KasbyNumberFormatter.formatProfitPercentage(
                                  homeController.profitPercentage,
                                  includeSign: true,
                                ),
                                style: TextStyle(
                                  color: AppColors.softGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate(autoPlay: motion).fadeIn().slideX(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'total_balance'.tr,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Obx(() {
                        final balance = currencyController.totalBalance.value;
                        final hidden = currencyController.isBalanceHidden.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                  hidden
                                      ? '••••••'
                                      : currencyController.formatToUSD(balance),
                                  style: Get.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    letterSpacing: -1,
                                  ),
                                )
                                .animate(autoPlay: motion)
                                .shimmer(
                                  duration: KasbyMotion.duration(
                                    context,
                                    const Duration(seconds: 3),
                                  ),
                                ),
                            if (!hidden) ...[
                              const SizedBox(height: 4),
                              Text(
                                '≈ ${CurrencyConversionService.formatKsp(CurrencyConversionService.usdToKsp(balance))} KSP',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Obx(() {
                                final effective =
                                    homeController.userPoints.value;
                                final reward = homeController.rewardKsp.value;
                                final walletPart =
                                    homeController.walletKsp.value;
                                return Container(
                                  key: kspSectionKey,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGold.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.darkGold.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/images/ksp_coin.png',
                                            width: 18,
                                            height: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${'ksp_balance'.tr}: ${currencyController.formatKspAmount(effective.toDouble())}',
                                            style: TextStyle(
                                              color: AppColors.darkGold,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyConversionService.getUsdEquivalentText(
                                          effective.toDouble(),
                                        ),
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ksp_effective_breakdown'.trParams({
                                          'wallet': walletPart.toString(),
                                          'reward': reward.toString(),
                                        }),
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ksp_rewards_hint'.tr,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    icon: Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: AppColors.darkGold,
                                    ),
                                    tooltip: 'ksp_explainer_title'.tr,
                                    onPressed: () =>
                                        KspRewardsExplainer.show(context),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Get.toNamed('/earnings-analytics'),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.show_chart_rounded,
                                    color: AppColors.textSecondary,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'my_daily_earnings'.tr,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textSecondary,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Obx(() {
                                final profit = homeController.dailyProfit;
                                final hidden =
                                    currencyController.isBalanceHidden.value;
                                return Column(
                                  children: [
                                    Text(
                                      hidden
                                          ? '••••'
                                          : currencyController.formatToUSD(
                                              profit,
                                            ),
                                      style: TextStyle(
                                        color: AppColors.softGreen,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    if (!hidden && profit > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        currencyController.formatKspFromUsd(
                                          profit,
                                        ),
                                        style: TextStyle(
                                          color: AppColors.darkGold,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Obx(
                              () => DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      currencyController.selectedCurrency.value,
                                  dropdownColor: isDark
                                      ? AppColors.surface
                                      : AppColors.surfaceLight,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.darkGold,
                                    size: 18,
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  items: currencyController.currencyData.keys
                                      .map((String key) {
                                        return DropdownMenuItem<String>(
                                          value: key,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                currencyController
                                                    .currencyData[key]!['flag'],
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                key,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      currencyController.changeCurrency(
                                        newValue,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Obx(
                              () =>
                                  Text(
                                        currencyController.formatAmount(
                                          currencyController.totalBalance.value,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      )
                                      .animate(
                                        autoPlay: motion,
                                        key: ValueKey(
                                          currencyController
                                              .selectedCurrency
                                              .value,
                                        ),
                                      )
                                      .scale(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    final investments = homeController.myInvestments;
                    if (investments.isEmpty) return const SizedBox.shrink();

                    double gold = 0;
                    double silver = 0;
                    double realEstate = 0;
                    double total = 0;

                    for (var inv in investments) {
                      final cat = inv.investment?.category ?? 'other';
                      if (cat == 'gold') {
                        gold += inv.amount;
                      } else if (cat == 'silver') {
                        silver += inv.amount;
                      } else if (cat == 'real_estate') {
                        realEstate += inv.amount;
                      } else {
                        realEstate += inv.amount;
                      }
                      total += inv.amount;
                    }

                    if (total == 0) return const SizedBox.shrink();

                    final goldPct = (gold / total * 100).round();
                    final silverPct = (silver / total * 100).round();
                    final realEstatePct = (100 - goldPct - silverPct).clamp(
                      0,
                      100,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'portfolio_distribution'.tr,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              children: [
                                if (gold > 0)
                                  Expanded(
                                    flex: goldPct,
                                    child: Container(color: AppColors.darkGold),
                                  ),
                                if (silver > 0)
                                  Expanded(
                                    flex: silverPct,
                                    child: Container(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                if (realEstate > 0)
                                  Expanded(
                                    flex: realEstatePct,
                                    child: Container(
                                      color: AppColors.softGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (gold > 0)
                              _BalanceLegendItem(
                                label: 'gold_sector'.trParams({
                                  'percent': '$goldPct',
                                }),
                                color: AppColors.darkGold,
                              ),
                            if (silver > 0 && gold > 0)
                              const SizedBox(width: 16),
                            if (silver > 0)
                              _BalanceLegendItem(
                                label: 'silver_sector'.trParams({
                                  'percent': '$silverPct',
                                }),
                                color: isDark
                                    ? Colors.grey[400]!
                                    : Colors.grey[600]!,
                              ),
                            if (realEstate > 0 && (gold > 0 || silver > 0))
                              const SizedBox(width: 16),
                            if (realEstate > 0)
                              _BalanceLegendItem(
                                label: 'real_estate_sector'.trParams({
                                  'percent': '$realEstatePct',
                                }),
                                color: AppColors.softGreen,
                              ),
                          ],
                        ),
                      ],
                    );
                  }),
                  Obx(() {
                    final canClaim = homeController.canClaimRewards.value;
                    final countdown = homeController.rewardCountdownText.value;

                    if (!canClaim &&
                        countdown.isEmpty &&
                        homeController.pendingRewards.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 24),
                        Divider(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          height: 1,
                        ),
                        const SizedBox(height: 20),
                        if (!canClaim)
                          Obx(() {
                            final currentCountdown =
                                homeController.rewardCountdownText.value;
                            final isCycleComplete =
                                currentCountdown == 'cycle_completed';
                            final isProcessing =
                                homeController.isProcessingUI.value;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isProcessing)
                                  Icon(
                                        Icons.sync_rounded,
                                        color: AppColors.softGreen,
                                        size: 16,
                                      )
                                      .animate(onPlay: (c) => c.repeat())
                                      .rotate(
                                        duration: const Duration(seconds: 2),
                                      )
                                else if (isCycleComplete)
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.softGreen,
                                    size: 16,
                                  )
                                else
                                  Icon(
                                        Icons.hourglass_bottom_rounded,
                                        color: AppColors.darkGold,
                                        size: 16,
                                      )
                                      .animate(onPlay: (c) => c.repeat())
                                      .rotate(
                                        duration: const Duration(seconds: 2),
                                      ),
                                const SizedBox(width: 8),
                                if (!isProcessing)
                                  GestureDetector(
                                    onTap: () {
                                      Get.toNamed(Routes.myInvestments);
                                    },
                                    child: Text(
                                      isCycleComplete
                                          ? 'cycle_completed_message'.tr
                                          : 'release_countdown'.tr,
                                      style: TextStyle(
                                        color: isCycleComplete
                                            ? AppColors.softGreen
                                            : AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: isCycleComplete
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                       // decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                if (!isCycleComplete)
                                  Text(
                                    currentCountdown,
                                    style: TextStyle(
                                      color: isProcessing
                                          ? AppColors.softGreen
                                          : AppColors.darkGold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                              ],
                            );
                          }).animate(autoPlay: motion).fadeIn(),
                        if (canClaim)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: KasbyButton(
                              text: 'claim_rewards'.tr,
                              onPressed: () => homeController.claimRewards(),
                              isLoading: homeController.isClaimingLoading.value,
                              color: AppColors.softGreen,
                              icon: Icons.auto_awesome_rounded,
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceLegendItem extends StatelessWidget {
  const _BalanceLegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
