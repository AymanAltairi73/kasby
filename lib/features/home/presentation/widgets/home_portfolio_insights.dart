import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/mini_charts.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';

class HomePortfolioInsights extends StatelessWidget {
  const HomePortfolioInsights({super.key});

  static const _periods = ['7D', '30D', '90D'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeController = HomeController.to;
    final currencyController = CurrencyController.to;

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              final data = homeController.portfolioSparklineData;
              if (data.length < 2) return const SizedBox.shrink();

              final growth = homeController.portfolioGrowthPercent;
              final isPositive = growth >= 0;
              final growthColor = isPositive
                  ? AppColors.softGreen
                  : AppColors.error;

              return KasbyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'portfolio_growth'.tr,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: _periods.map((period) {
                            final selected =
                                homeController.portfolioPeriod.value == period;
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: GestureDetector(
                                onTap: () =>
                                    homeController.portfolioPeriod.value =
                                        period,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.darkGold.withValues(
                                            alpha: 0.15,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.darkGold.withValues(
                                              alpha: 0.4,
                                            )
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.08,
                                                  )),
                                    ),
                                  ),
                                  child: Text(
                                    'period_${period.toLowerCase()}'.tr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: selected
                                          ? AppColors.darkGold
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isPositive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: growthColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? '+' : ''}${growth.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: growthColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    KasbySparkline(
                      data: data,
                      height: 64,
                      lineColor: isPositive
                          ? AppColors.softGreen
                          : AppColors.error,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Obx(() {
              final invested = currencyController.investedBalance.value;
              final available = currencyController.totalBalance.value;
              final total = invested + available;
              if (total <= 0) return const SizedBox.shrink();

              final progress = (invested / total).clamp(0.0, 1.0);
              final pct = (progress * 100).round();

              return KasbyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'total_invested'.tr,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            color: AppColors.darkGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.darkGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'invested_balance'.tr,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'total_balance'.tr,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Obx(() {
              final insightKey = homeController.financialInsightKey;
              return KasbyCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.darkGold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppColors.darkGold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'financial_insights'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insightKey.tr,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLight,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        )
        .animate(autoPlay: KasbyMotion.enabled(context))
        .fadeIn(
          delay: KasbyMotion.duration(
            context,
            const Duration(milliseconds: 900),
          ),
        );
  }
}
