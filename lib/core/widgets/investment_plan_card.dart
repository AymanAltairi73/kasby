import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InvestmentPlanCard extends StatefulWidget {
  final String? id;
  final String title;
  final String profit;
  final String minAmount;
  final String imagePath;
  final Color color;
  final List<String>? amounts;
  final double? rawProfitPercentage;
  final int? durationDays;
  final String? duration;
  final String? riskLevel;

  const InvestmentPlanCard({
    super.key,
    this.id,
    required this.title,
    required this.profit,
    required this.minAmount,
    required this.imagePath,
    required this.color,
    this.amounts,
    this.rawProfitPercentage,
    this.durationDays,
    this.duration,
    this.riskLevel,
  });

  @override
  State<InvestmentPlanCard> createState() => _InvestmentPlanCardState();
}

class _InvestmentPlanCardState extends State<InvestmentPlanCard> {
  late String selectedAmount;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    selectedAmount = widget.minAmount;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        SafeGetx.debugTrace(
          className: 'InvestmentPlanCard',
          method: 'onTap',
          feature: 'Investment',
          status: 'INFO',
          params: {'planId': widget.id, 'title': widget.title},
        );
        Get.toNamed(
          Routes.investmentDetails,
          arguments: {
            'id': widget.id,
            'title': widget.title.tr,
            'profit': widget.profit,
            'profit_percentage': widget.rawProfitPercentage,
            'duration_days': widget.durationDays,
            'minAmount': widget.minAmount,
            'color': widget.color,
            'amounts': widget.amounts,
          },
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Glow
          Positioned(
            right: -20,
            top: -20,
            child:
                Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(alpha: 0.15),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      duration: const Duration(seconds: 3),
                      begin: const Offset(1, 1),
                      end: const Offset(1.2, 1.2),
                    )
                    .blurXY(begin: 30, end: 60),
          ),

          KasbyCard(
                padding: EdgeInsets.zero,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : AppColors.surfaceLight,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.darkGold.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                child: SingleChildScrollView(
                  physics:
                      const NeverScrollableScrollPhysics(), // Don't block parent scrolling
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Image.asset(
                          widget.imagePath,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title.tr,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: widget.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Spacer(),
                                Text(
                                  'invest_now'.tr,
                                  style: TextStyle(
                                    color: widget.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(
                duration: const Duration(seconds: 4),
                color: Colors.white.withValues(alpha: 0.05),
              ),
        ],
      ),
    );
  }
}
