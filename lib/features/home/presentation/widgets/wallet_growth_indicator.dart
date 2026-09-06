import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

class WalletGrowthIndicator extends StatelessWidget {
  final double totalBalance;
  final double profitBalance;
  final double investedBalance;
  final bool compact;

  const WalletGrowthIndicator({
    super.key,
    required this.totalBalance,
    required this.profitBalance,
    required this.investedBalance,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Principal calculation based strictly on real balances
    final double principal = investedBalance > 0
        ? investedBalance
        : (totalBalance - profitBalance);

    final bool hasValidPrincipal = principal > 0;
    final bool hasProfit = profitBalance != 0;
    final bool canCalculateGrowth = hasValidPrincipal && hasProfit;

    if (!canCalculateGrowth) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: compact ? 12 : 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                compact ? 'no_growth_data_compact'.tr : 'no_growth_data'.tr,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    final double growthRate = (profitBalance / principal) * 100;
    final bool isPositive = growthRate >= 0;
    final Color badgeColor = isPositive
        ? const Color(0xFF22C55E) // AppColors.softGreen
        : const Color(0xFFEF4444);

    final Color badgeBg = badgeColor.withValues(alpha: isDark ? 0.15 : 0.1);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: growthRate),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final String sign = animatedValue > 0 ? '+' : '';
        final String formattedValue =
            '$sign${animatedValue.toStringAsFixed(2)}%';

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 3 : 6,
          ),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: compact ? 12 : 16,
                color: badgeColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  formattedValue,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'wallet_growth'.tr,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: badgeColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).scale(
          duration: 400.ms,
          begin: const Offset(0.9, 0.9),
          curve: Curves.easeOutBack,
        );
  }
}
