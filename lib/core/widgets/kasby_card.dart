import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class KasbyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double? borderRadius;
  final bool hasShadow;
  final BoxBorder? border;

  const KasbyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.borderRadius,
    this.hasShadow = false,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
          margin: margin,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gradient == null
                ? (color ??
                      (isDark
                          ? AppColors.surface.withValues(alpha: 0.8)
                          : AppColors.surfaceLight))
                : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius ?? 20),
            border:
                border ??
                Border.all(
                  color: isDark
                      ? AppColors.onSurface.withValues(alpha: 0.08)
                      : AppColors.borderLight,
                  width: 1,
                ),
            boxShadow: hasShadow
                ? [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : const Color(0x0C0F172A),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: child,
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }
}
