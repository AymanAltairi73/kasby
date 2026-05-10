import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kasby/core/theme/app_colors.dart';

class SlideToConfirm extends StatefulWidget {
  final String text;
  final VoidCallback onConfirm;
  final Color? color;

  const SlideToConfirm({
    super.key,
    required this.text,
    required this.onConfirm,
    this.color,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dragPosition = 0;
  final double _buttonSize = 56;
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxDrag = constraints.maxWidth - _buttonSize;
          return Container(
            height: _buttonSize,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(_buttonSize / 2),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  left: _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_isConfirmed) return;
                      setState(() {
                        _dragPosition += details.delta.dx;
                        if (_dragPosition < 0) _dragPosition = 0;
                        if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_isConfirmed) return;
                      if (_dragPosition >= maxDrag * 0.9) {
                        setState(() {
                          _dragPosition = maxDrag;
                          _isConfirmed = true;
                        });
                        HapticFeedback.mediumImpact();
                        widget.onConfirm();
                      } else {
                        setState(() {
                          _dragPosition = 0;
                        });
                      }
                    },
                    child: Container(
                      height: _buttonSize,
                      width: _buttonSize,
                      decoration: BoxDecoration(
                        color: widget.color ?? AppColors.darkGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.color ?? AppColors.darkGold)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
