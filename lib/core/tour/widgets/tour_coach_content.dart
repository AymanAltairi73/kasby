import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';

/// Centered Material 3 coach-mark dialog with fade/scale transitions.
class TourCoachContent extends StatefulWidget {
  const TourCoachContent({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.titleKey,
    required this.descriptionKey,
    required this.showPrevious,
    required this.isLastStep,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
  });

  final int stepIndex;
  final int totalSteps;
  final String titleKey;
  final String descriptionKey;
  final bool showPrevious;
  final bool isLastStep;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<TourCoachContent> createState() => _TourCoachContentState();
}

class _TourCoachContentState extends State<TourCoachContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant TourCoachContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width > 600 ? 400.0 : width * 0.9;

    return Semantics(
      label: '${widget.titleKey.tr}. ${widget.descriptionKey.tr}',
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth.clamp(280, 420)),
            child: Material(
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              color: isDark ? AppColors.surface : Colors.white,
              surfaceTintColor: AppColors.darkGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KasbyRadius.card + 4),
                side: BorderSide(
                  color: AppColors.darkGold.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'tour_progress'.trParams({
                              'current': '${widget.stepIndex + 1}',
                              'total': '${widget.totalSteps}',
                            }),
                            style: TextStyle(
                              color: AppColors.darkGold,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onSkip,
                          child: Text('tour_skip'.tr),
                        ),
                      ],
                    ),
                    Text(
                      widget.titleKey.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.descriptionKey.tr,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (widget.showPrevious)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onPrevious,
                              child: Text('tour_previous'.tr),
                            ),
                          ),
                        if (widget.showPrevious) const SizedBox(width: 10),
                        Expanded(
                          flex: widget.showPrevious ? 1 : 2,
                          child: FilledButton(
                            onPressed: widget.onNext,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.darkGold,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(
                              widget.isLastStep
                                  ? 'tour_finish'.tr
                                  : 'tour_next'.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
