import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.05,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                color ??
                (isDark
                    ? Colors.white.withValues(alpha: opacity)
                    : Colors.black.withValues(alpha: opacity)),
            borderRadius: borderRadius ?? BorderRadius.circular(24),
            border: Border.all(
              color:
                  borderColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
