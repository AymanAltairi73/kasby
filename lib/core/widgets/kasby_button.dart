import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';

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
          child: ElevatedButton(
            onPressed: null, // Handled by GestureDetector for custom animation
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  widget.color ??
                  (widget.isSecondary
                      ? Colors.transparent
                      : AppColors.darkGold),
              disabledBackgroundColor:
                  widget.color ??
                  (widget.isSecondary
                      ? Colors.transparent
                      : AppColors.darkGold),
              foregroundColor:
                  widget.textColor ??
                  (widget.isSecondary && widget.color == null
                      ? AppColors.darkGold
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white)),
              disabledForegroundColor:
                  widget.textColor ??
                  (widget.isSecondary && widget.color == null
                      ? AppColors.darkGold
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: widget.isSecondary && widget.color == null
                    ? BorderSide(color: AppColors.darkGold)
                    : BorderSide.none,
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
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (!motionEnabled) return core;
    return core.animate().fadeIn(duration: 400.ms);
  }
}
