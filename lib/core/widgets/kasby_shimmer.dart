import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class KasbyShimmer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? margin;
  final Widget? child;

  const KasbyShimmer({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.margin,
    this.child,
  });

  const KasbyShimmer.card({
    super.key,
    this.width = double.infinity,
    this.height = 160,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.margin,
    this.child,
  });

  const KasbyShimmer.listItem({
    super.key,
    this.width = double.infinity,
    this.height = 80,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.margin,
    this.child,
  });

  factory KasbyShimmer.investmentPlanCard({Key? key, bool isDark = false}) {
    return KasbyShimmer(
      key: key,
      width: double.infinity,
      height: 200,
      borderRadius: BorderRadius.circular(24),
      margin: const EdgeInsets.only(bottom: 20),
    );
  }

  factory KasbyShimmer.teamMemberItem({Key? key, bool isDark = false}) {
    return KasbyShimmer(
      key: key,
      width: double.infinity,
      height: 72,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const CircleAvatar(radius: 24, backgroundColor: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 14, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
                  Container(width: 80, height: 10, color: Colors.white),
                ],
              ),
            ),
            Container(width: 40, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
          ],
        ),
      ),
    );
  }

  factory KasbyShimmer.profileDetailItem({Key? key}) {
    return KasbyShimmer(
      key: key,
      width: double.infinity,
      height: 64,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 12),
    );
  }

  factory KasbyShimmer.transactionItem({Key? key, bool isDark = false}) {
    return KasbyShimmer( // we don't extend KasbyShimmer, we just return KasbyShimmer wrapping a custom layout
      key: key,
      width: double.infinity,
      height: 52,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 120, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
                  Container(width: 80, height: 12, color: Colors.white),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 60, height: 18, color: Colors.white, margin: const EdgeInsets.only(bottom: 6)),
                Container(width: 40, height: 10, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Smooth gray gradient colors as requested
    final baseColor = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark 
        ? Colors.white.withValues(alpha: 0.15) 
        : Colors.black.withValues(alpha: 0.1);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child ?? Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
