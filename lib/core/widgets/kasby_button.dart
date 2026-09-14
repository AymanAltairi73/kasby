import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/theme/kasby_typography.dart';

class KasbyButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isLoading;
  final double? width;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  const KasbyButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isSecondary = false,
    this.isLoading = false,
    this.width,
    this.icon,
    this.color,
    this.textColor,
  });

  @override
  State<KasbyButton> createState() => _KasbyButtonState();
}

class _KasbyButtonState extends State<KasbyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final motionEnabled = KasbyMotion.enabled(context);
    final core = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        if (widget.onPressed != null && !widget.isLoading) {
          HapticFeedback.lightImpact();
          widget.onPressed!();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width ?? double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow:
                !widget.isSecondary &&
                    !widget.isLoading &&
                    widget.onPressed != null
                ? [
                    BoxShadow(
                      color: AppColors.darkGold.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final isEnabled = widget.onPressed != null && !widget.isLoading;

              Color effectiveBgColor;
              if (widget.color != null) {
                effectiveBgColor = widget.color!;
              } else if (widget.isSecondary) {
                effectiveBgColor = Colors.transparent;
              } else if (!isEnabled) {
                effectiveBgColor = isDark
                    ? const Color(0xFF232328)
                    : AppColors.surfaceSecondaryLight;
              } else {
                effectiveBgColor = AppColors.darkGold;
              }

              Color effectiveFgColor;
              if (widget.textColor != null) {
                effectiveFgColor = widget.textColor!;
              } else if (!isEnabled) {
                effectiveFgColor = isDark
                    ? const Color(0xFF6B7280)
                    : AppColors.textMutedLight;
              } else if (widget.isSecondary) {
                effectiveFgColor = AppColors.darkGold;
              } else {
                effectiveFgColor = Colors.black;
              }

              BorderSide effectiveBorder;
              if (widget.isSecondary && widget.color == null) {
                effectiveBorder = BorderSide(
                  color: isEnabled
                      ? AppColors.darkGold
                      : (isDark ? const Color(0xFF374151) : AppColors.borderLight),
                );
              } else {
                effectiveBorder = BorderSide.none;
              }

              return ElevatedButton(
                onPressed: null, // Handled by GestureDetector for custom animation
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectiveBgColor,
                  disabledBackgroundColor: effectiveBgColor,
                  foregroundColor: effectiveFgColor,
                  disabledForegroundColor: effectiveFgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: effectiveBorder,
                  ),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                ),
                child: widget.isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: effectiveFgColor,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 20),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: KasbyTypography.fontFamily,
                                fontSize: KasbyTypography.button(context),
                                letterSpacing:
                                    KasbyTypography.isEnglish(context) ? 0.2 : 0.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
    if (!motionEnabled) return core;
    return core.animate().fadeIn(duration: 400.ms);
  }
}
