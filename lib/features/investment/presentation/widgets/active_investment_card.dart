import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/utils/number_formatter.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';

/// Premium Active Investment Card
/// Follows the visual reference design with rich metrics, circular investment counter,
/// crystal-clear investment imagery, real-data-driven performance records, and zero text clipping.
class ActiveInvestmentCard extends StatelessWidget {
  final UserInvestmentModel inv;
  final InvestmentPlanModel? plan;
  final String planName;
  final bool isActive;
  final bool isNotActive;
  final bool isDark;
  final bool isAr;
  final VoidCallback onRefresh;

  const ActiveInvestmentCard({
    super.key,
    required this.inv,
    required this.plan,
    required this.planName,
    required this.isActive,
    required this.isNotActive,
    required this.isDark,
    required this.isAr,
    required this.onRefresh,
  });

  // ── Palette Tokens ──
  Color get _cardBg => isDark ? const Color(0xFF0F0F14) : Colors.white;
  Color get _innerCardBg =>
      isDark ? const Color(0xFF171720) : const Color(0xFFF8FAFC);
  Color get _cardBorder => isDark
      ? AppColors.darkGold.withValues(alpha: 0.24)
      : AppColors.borderLight;
  Color get _innerBorder =>
      isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0);
  Color get _dividerColor =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
  Color get _goldColor => isDark ? AppColors.darkGold : const Color(0xFFB78628);
  Color get _textPrimary => isDark ? Colors.white : AppColors.textBodyLight;
  Color get _textSecondary =>
      isDark ? const Color(0xFFB0B3C0) : AppColors.textSecondaryLight;
  Color get _textMuted =>
      isDark ? const Color(0xFF75788A) : AppColors.textMutedLight;
  Color get _emeraldColor => const Color(0xFF22C55E);

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
    final String planDesc = isAr
        ? ((plan?.descriptionAr != null && plan!.descriptionAr.isNotEmpty)
              ? plan!.descriptionAr
              : 'safe_investment_stable_returns'.tr)
        : ((plan?.descriptionEn != null && plan!.descriptionEn!.isNotEmpty)
              ? plan!.descriptionEn!
              : 'safe_investment_stable_returns'.tr);

    // Single source of truth for timeline, duration and progress
    final timeline = inv.timelineState(isAr: isAr);
    final durationDisplay = timeline.durationDisplay;
    final durationSubtext = timeline.durationSubtext;

    final progressValue = timeline.progress;
    final progressPercent = timeline.progressPercent;

    final cyclePositionText = timeline.cyclePositionText;
    final cycleCompletedText = timeline.completedMonthsText;
    final cycleRemainingText = timeline.remainingMonthsText;
    final startElapsedText = timeline.startElapsedText;
    final endRemainingText = timeline.endRemainingText;

    final startDateStr = DateHelper.date(timeline.startDate);
    final endDateStr = DateHelper.date(timeline.endDate);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          if (isDark)
            BoxShadow(
              color: AppColors.darkGold.withValues(alpha: 0.04),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER (ACTIVE BADGE, TITLE, DESC, TAGS & BULLION ART) ──
              _buildHeader(planDesc),
              const SizedBox(height: 8),

              // ── 2. PRIMARY INVESTMENT METRICS (AMOUNT, MONTHLY RATE, DURATION) ──
              _buildPrimaryMetrics(durationDisplay, durationSubtext),
              const SizedBox(height: 7),

              // ── 3. EXPECTED RETURNS (MONTHLY & DAILY ESTIMATES) ──
              _buildExpectedReturns(),
              const SizedBox(height: 7),

              // ── 4. INVESTMENT DURATION & CIRCULAR PROGRESS COUNTER ──
              _buildProgressSection(
                progressValue: progressValue,
                progressPercent: progressPercent,
                cyclePositionText: cyclePositionText,
                cycleCompletedText: cycleCompletedText,
                cycleRemainingText: cycleRemainingText,
              ),
              const SizedBox(height: 7),

              // ── 5. PERFORMANCE SECTION (REAL DATA ONLY) ──
              // _buildPerformanceSection(),
              // const SizedBox(height: 7),

              // ── 6. START & END DATES ──
              _buildDatesSection(
                startDateStr: startDateStr,
                endDateStr: endDateStr,
                startElapsedText: startElapsedText,
                endRemainingText: endRemainingText,
              ),
              const SizedBox(height: 7),

              // ── 7. NEXT PAYOUT COUNTDOWN & WALLET AUTO-DEPOSIT FOOTER ──
              _buildPayoutFooter(),

              // ── 8. LIFECYCLE CONTROLS (IF WAITING CYCLE / AUTO-RESTART) ──
              _buildLifecycleActions(),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  // ─────────────────────────────────────────────────────────────
  // 1. HEADER SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(String planDesc) {
    final imageAsset = (plan?.imageUrl != null && plan!.imageUrl!.isNotEmpty)
        ? plan!.imageUrl!
        : _getPlanImage(plan?.nameEn ?? plan?.nameAr ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Pill
        _buildStatusPill(),
        const SizedBox(height: 6),

        // Investment Title (Never truncated)
        Text(
          planName,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
        if (planDesc.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            planDesc,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Full-Width Hero Investment Image across card width
        _buildInvestmentArtwork(imageAsset),
      ],
    );
  }

  Widget _buildStatusPill() {
    final Color badgeBg;
    final Color badgeBorder;
    final Color dotColor;
    final String badgeText;

    if (isActive) {
      badgeBg = isDark ? const Color(0xFF0D2B19) : const Color(0xFFE8F5E9);
      badgeBorder = isDark ? const Color(0xFF1B5E34) : const Color(0xFFC8E6C9);
      dotColor = _emeraldColor;
      badgeText = 'active'.tr;
    } else if (isNotActive) {
      badgeBg = isDark ? const Color(0xFF332612) : const Color(0xFFFFF8E1);
      badgeBorder = isDark ? const Color(0xFF735118) : const Color(0xFFFFECB3);
      dotColor = const Color(0xFFF59E0B);
      badgeText = 'not_active'.tr;
    } else {
      badgeBg = isDark ? const Color(0xFF1E2430) : const Color(0xFFECEFF1);
      badgeBorder = isDark ? const Color(0xFF374151) : const Color(0xFFCFD8DC);
      dotColor = const Color(0xFF94A3B8);
      badgeText = inv.status.tr;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            badgeText,
            style: TextStyle(
              color: dotColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentArtwork(String imageAsset) {
    final isNetwork = imageAsset.startsWith('http');

    return Container(
      width: double.infinity,
      height: 110,
      decoration: BoxDecoration(
        color: _innerCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient radial gold glow behind asset
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      AppColors.darkGold.withValues(
                        alpha: isDark ? 0.20 : 0.10,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // High-Res Large Investment Image across the card width
            Positioned.fill(
              child: isNetwork
                  ? Image.network(
                      imageAsset,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => Image.asset(
                        'assets/images/gold.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      imageAsset,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. PRIMARY METRICS SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildPrimaryMetrics(String durationDisplay, String? durationSubtext) {
    final amountFormatted =
        '\$${NumberFormat('#,##0.00', 'en_US').format(inv.amount)}';
    final profitRateFormatted = KasbyNumberFormatter.formatProfitPercentage(
      inv.profitPercentage,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: _innerCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _innerBorder, width: 1),
      ),
      child: Row(
        children: [
          // Metric 1: Investment Value
          Expanded(
            flex: 6,
            child: Row(
              children: [
                _buildCircleIcon(
                  Icons.account_balance_wallet_rounded,
                  size: 26,
                  iconSize: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'investment_value'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          amountFormatted,
                          style: TextStyle(
                            color: _goldColor,
                            fontSize: 14,
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),

          // Metric 2: Monthly Return
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _buildCircleIcon(
                  Icons.trending_up_rounded,
                  size: 26,
                  iconSize: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'monthly_return_rate'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          profitRateFormatted,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),

          // Metric 3: Duration
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _buildCircleIcon(
                  Icons.access_time_rounded,
                  size: 26,
                  iconSize: 13,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'investment_duration'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 9,
                          //fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          durationDisplay,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 9,
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (durationSubtext != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: isAr
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            durationSubtext,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 9.5,
                              //fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. EXPECTED RETURNS SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildExpectedReturns() {
    final monthlyProfitStr =
        '\$${NumberFormat('#,##0.00', 'en_US').format(inv.monthlyProfit)}';
    final dailyProfitStr = '\$${inv.dailyProfit.toStringAsFixed(2)}';
    final rateBadgeStr =
        KasbyNumberFormatter.formatProfitPercentage(inv.profitPercentage);

    return Row(
      children: [
        // Card A: Expected Monthly Return
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _innerCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _innerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildCircleIcon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      iconSize: 12,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'monthly_return'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          monthlyProfitStr,
                          style: TextStyle(
                            color: _emeraldColor,
                            fontSize: 14,
                           // fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: _emeraldColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        rateBadgeStr,
                        style: TextStyle(
                          color: _emeraldColor,
                          fontSize: 9.5,
                         // fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'monthly_payout_wallet_note'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 9.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Card B: Estimated Daily Return
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _innerCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _innerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildCircleIcon(
                      Icons.monetization_on_rounded,
                      size: 24,
                      iconSize: 12,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'daily_return'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                          //fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          dailyProfitStr,
                          style: TextStyle(
                            color: _emeraldColor,
                            fontSize: 13,
                           // fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: _emeraldColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        rateBadgeStr,
                        style: TextStyle(
                          color: _emeraldColor,
                          fontSize: 9.5,
                         // fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'based_on_monthly_return'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 9.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. INVESTMENT PROGRESS & CIRCULAR COUNTER
  // ─────────────────────────────────────────────────────────────
  Widget _buildProgressSection({
    required double progressValue,
    required int progressPercent,
    required String cyclePositionText,
    required String cycleCompletedText,
    required String cycleRemainingText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _innerCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _innerBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Progress Ring with Glowing Gold Arc
              // _InvestmentProgressRing(
              //   progress: progressValue,
              //   percent: progressPercent,
              //   goldColor: _goldColor,
              //   isDark: isDark,
              // ),
              //const SizedBox(width: 10),

              // Title, Milestone & Linear Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'investment_progress'.tr,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 12.5,
                           // fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildCycleActiveIndicator(),
                      ],
                    ),
                    const SizedBox(height: 3),
                  Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF4A4E69)
                          : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cycleRemainingText,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
                    // Text(
                    //   cyclePositionText,
                    //   style: TextStyle(
                    //     color: _textSecondary,
                    //     fontSize: 11,
                    //     fontWeight: FontWeight.w500,
                    //   ),
                    // ),
                     const SizedBox(height: 6),

                    // Custom Linear Bar with Gold Glow
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(_goldColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Milestone Legend Dots Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _goldColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cycleCompletedText,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Row(
              //   mainAxisSize: MainAxisSize.min,
              //   children: [
              //     Container(
              //       width: 6,
              //       height: 6,
              //       decoration: BoxDecoration(
              //         color: isDark
              //             ? const Color(0xFF4A4E69)
              //             : const Color(0xFF94A3B8),
              //         shape: BoxShape.circle,
              //       ),
              //     ),
              //     const SizedBox(width: 4),
              //     Text(
              //       cycleRemainingText,
              //       style: TextStyle(
              //         color: _textSecondary,
              //         fontSize: 10.5,
              //         fontWeight: FontWeight.w500,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCycleActiveIndicator() {
    final String label;
    final Color color;
    final Color bg;

    if (isActive && inv.isCycleActive) {
      label = 'active_profit_cycle'.tr;
      color = _emeraldColor;
      bg = isDark ? const Color(0xFF0F321E) : const Color(0xFFE8F5E9);
    } else if (inv.isCycleWaiting) {
      label = 'cycle_waiting_start'.tr;
      color = const Color(0xFFF59E0B);
      bg = isDark ? const Color(0xFF332510) : const Color(0xFFFFF8E1);
    } else {
      label = 'cycle_completed_badge'.tr;
      color = const Color(0xFF94A3B8);
      bg = isDark ? const Color(0xFF1E2530) : const Color(0xFFECEFF1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
             // fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. HISTORICAL PERFORMANCE SECTION (STRICT REAL DATA INTEGRITY)
  // ─────────────────────────────────────────────────────────────
  // ignore: unused_element
  Widget _buildPerformanceSection() {
    // Check for genuine completed payout transactions for this specific investment
    final allTxns = HomeController.to.allTransactions.isNotEmpty
        ? HomeController.to.allTransactions
        : HomeController.to.recentTransactions;

    final profitTxns =
        allTxns
            .where(
              (t) =>
                  t.referenceId == inv.id &&
                  (t.type == 'profit' || t.type == 'investment_return') &&
                  t.status == 'completed' &&
                  t.createdAt != null,
            )
            .toList()
          ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    final hasRealHistoricalData = profitTxns.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _innerCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _innerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildCircleIcon(
                    Icons.show_chart_rounded,
                    size: 26,
                    iconSize: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'chart_historical_performance'.tr,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                     // fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (inv.actualProfit != null && inv.actualProfit! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _emeraldColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+\$${inv.actualProfit!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _emeraldColor,
                      fontSize: 10.5,
                     // fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (hasRealHistoricalData)
            _buildRealPerformanceChart(profitTxns)
          else
            _buildHonestEmptyPerformanceCard(),
        ],
      ),
    );
  }

  Widget _buildRealPerformanceChart(List<TransactionModel> profitTxns) {
    // Build real sequential payout data
    final amounts = profitTxns.map((t) => t.amount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: CustomPaint(
            size: const Size(double.infinity, 44),
            painter: _RealPayoutSparklinePainter(
              values: amounts,
              lineColor: _goldColor,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateHelper.date(profitTxns.first.createdAt),
              style: TextStyle(color: _textMuted, fontSize: 9.5),
            ),
            Text(
              '${profitTxns.length} ${isAr ? 'دفعات محققة' : 'payouts'}',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              DateHelper.date(profitTxns.last.createdAt),
              style: TextStyle(color: _textMuted, fontSize: 9.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHonestEmptyPerformanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: _textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'chart_no_records_msg'.tr,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10.5,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. START & END DATES SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildDatesSection({
    required String startDateStr,
    required String endDateStr,
    required String startElapsedText,
    required String endRemainingText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _innerCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _innerBorder),
      ),
      child: Row(
        children: [
          // Start Date Card
          Expanded(
            child: Row(
              children: [
                _buildCircleIcon(
                  Icons.calendar_today_outlined,
                  size: 26,
                  iconSize: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'start_date_label'.tr,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          startDateStr,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 12,
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        startElapsedText,
                        style: TextStyle(color: _textMuted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(height: 30),

          // End Date Card
          Expanded(
            child: Row(
              children: [
                _buildCircleIcon(
                  Icons.event_available_outlined,
                  size: 26,
                  iconSize: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'end_date_label'.tr,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          endDateStr,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 12,
                           // fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        endRemainingText,
                        style: TextStyle(color: _textMuted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 7. NEXT PAYOUT COUNTDOWN & AUTO-DEPOSIT FOOTER
  // ─────────────────────────────────────────────────────────────
  Widget _buildPayoutFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _innerCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _innerBorder),
      ),
      child: Row(
        children: [
          // Next Payout Timer with Hours, Minutes, Seconds labels
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _buildCircleIcon(
                  Icons.timer_outlined,
                  size: 26,
                  iconSize: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'next_payout'.tr,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Obx(() {
                        String? raw =
                            HomeController.to.investmentCountdowns[inv.id];

                        if (raw == null || raw.isEmpty) {
                          if (inv.status != 'active' || inv.isCycleWaiting) {
                            raw = 'cycle_completed';
                          } else if (inv.effectiveNextPayout != null) {
                            final diff = inv.effectiveNextPayout!.difference(
                              DateTime.now(),
                            );
                            if (!diff.isNegative) {
                              final h = diff.inHours.toString().padLeft(2, '0');
                              final m = (diff.inMinutes % 60).toString().padLeft(
                                2,
                                '0',
                              );
                              final s = (diff.inSeconds % 60).toString().padLeft(
                                2,
                                '0',
                              );
                              raw = '$h:$m:$s';
                            } else {
                              raw = 'cycle_completed';
                            }
                          } else {
                            raw = 'cycle_completed';
                          }
                        }

                        if (raw == 'cycle_completed') {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _emeraldColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: _emeraldColor.withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'cycle_completed'.tr,
                                  style: TextStyle(
                                    color: _emeraldColor,
                                    fontSize: 10,
                                    //fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        final parts = raw.split(':');
                        final h = parts.isNotEmpty ? parts[0] : '--';
                        final m = parts.length > 1 ? parts[1] : '--';
                        final s = parts.length > 2 ? parts[2] : '--';

                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: isAr
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTimeSegment(s, 'countdown_seconds'.tr),
                              _buildTimeSeparator(),
                              _buildTimeSegment(m, 'countdown_minutes'.tr),
                              _buildTimeSeparator(),
                              _buildTimeSegment(h, 'countdown_hours'.tr),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(height: 30),

          // Auto-deposit to Kasby Wallet Note
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'auto_deposit_note'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 10.5,
                          //fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'to_your_kasby_wallet'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textSecondary, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _buildCircleIcon(
                  Icons.account_balance_wallet_outlined,
                  size: 26,
                  iconSize: 13,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSegment(String val, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: TextStyle(
            color: _goldColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        Text(label, style: TextStyle(color: _textMuted, fontSize: 8)),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          color: _goldColor.withValues(alpha: 0.6),
          fontSize: 13,
          //fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 8. LIFECYCLE CONTROLS
  // ─────────────────────────────────────────────────────────────
  Widget _buildLifecycleActions() {
    return Column(
      children: [
        // Cycle Restart Button (If Waiting)
        if (inv.isCycleWaiting) ...[
          const SizedBox(height: 7),
          Obx(() {
            final isStarting =
                HomeController.to.cycleRestartLoading[inv.id] == true;
            return SizedBox(
              width: double.infinity,
              child: KasbyButton(
                text: 'start_investment_cycle'.tr,
                isLoading: isStarting,
                onPressed: () async {
                  debugPrint(
                    '[PROFIT_CYCLE] User tapped start_investment_cycle for investment_id: ${inv.id}',
                  );
                  await HomeController.to.startNextCycle(inv.id);
                  onRefresh();
                },
              ),
            );
          }),
        ],

        // Auto-Restart Switch (If Subscribed)
        if (isActive && HomeController.to.isSubscribed.value) ...[
          const SizedBox(height: 7),
          Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 6),
          Obx(() {
            final isToggling =
                HomeController.to.autoRestartToggleLoading[inv.id] == true;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.autorenew_rounded,
                      size: 16,
                      color: AppColors.darkGold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'auto_restart'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                isToggling
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_goldColor),
                        ),
                      )
                    : Switch.adaptive(
                        value: inv.autoRestartEnabled,
                        activeTrackColor: AppColors.darkGold,
                        onChanged: (val) async {
                          await HomeController.to.toggleAutoRestart(
                            inv.id,
                            val,
                          );
                          onRefresh();
                        },
                      ),
              ],
            );
          }),
        ],

        // Completed Cycle Banner (if not active and completed/matured)
        if (!isActive &&
            (inv.status == 'completed' || inv.status == 'matured')) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.softGreen.withValues(
                alpha: isDark ? 0.08 : 0.06,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.softGreen.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.softGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'cycle_completed'.tr,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.softGreen
                          : const Color(0xFF107C41),
                    ),
                  ),
                ),
                if (inv.effectiveEndDate != null)
                  Text(
                    DateHelper.date(inv.effectiveEndDate),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: _textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // REUSABLE HELPER ATOMS
  // ─────────────────────────────────────────────────────────────
  Widget _buildCircleIcon(
    IconData icon, {
    double size = 26,
    double iconSize = 13,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkGold.withValues(alpha: isDark ? 0.14 : 0.09),
        border: Border.all(
          color: AppColors.darkGold.withValues(alpha: isDark ? 0.30 : 0.18),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(icon, color: _goldColor, size: iconSize),
      ),
    );
  }

  Widget _buildVerticalDivider({
    double height = 28,
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 4),
  }) {
    return Container(
      height: height,
      width: 1,
      margin: margin,
      color: _dividerColor,
    );
  }
}

/// Custom Circular Progress Ring widget with golden glow arc
class _InvestmentProgressRing extends StatelessWidget {
  final double progress;
  final int percent;
  final Color goldColor;
  final bool isDark;

  const _InvestmentProgressRing({
    required this.progress,
    required this.percent,
    required this.goldColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _RingArcPainter(
              progress: progress,
              goldColor: goldColor,
              isDark: isDark,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                'completed_label'.tr,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : AppColors.textSecondaryLight,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingArcPainter extends CustomPainter {
  final double progress;
  final Color goldColor;
  final bool isDark;

  _RingArcPainter({
    required this.progress,
    required this.goldColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    const strokeWidth = 4.5;

    // Background track
    final trackPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2E8F0)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    // Active progress arc with golden gradient and glow
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [const Color(0xFFE5C158), goldColor, const Color(0xFF946E20)],
        stops: const [0.0, 0.6, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RingArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

/// Custom sparkline painter for real payout amounts
class _RealPayoutSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final bool isDark;

  _RealPayoutSparklinePainter({
    required this.values,
    required this.lineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final points = <Offset>[];
    final stepX = size.width / (values.length == 1 ? 1 : (values.length - 1));

    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : i * stepX;
      final y =
          size.height - ((values[i] - minVal) / range * (size.height - 12) + 6);
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Gradient fill under the line
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: isDark ? 0.35 : 0.2),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Marker dots at each real payout point
    final dotPaint = Paint()..color = lineColor;
    final dotBorderPaint = Paint()
      ..color = isDark ? const Color(0xFF171720) : Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
      canvas.drawCircle(p, 3.5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RealPayoutSparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.isDark != isDark;
}
