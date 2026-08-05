import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../services/tour_service.dart';
import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_readiness.dart';
import 'widgets/tour_coach_content.dart';

/// Minimal wrapper around [TutorialCoachMark] with a single active overlay.
class TourManager {
  TourManager._();

  static TutorialCoachMark? _activeCoachMark;

  static bool get hasActiveOverlay => _activeCoachMark?.isShowing ?? false;

  /// Removes any lingering coach-mark overlay without marking completion.
  static void dismissActive({bool invokeFinish = false}) {
    final mark = _activeCoachMark;
    _activeCoachMark = null;
    if (mark == null) return;
    if (invokeFinish) {
      mark.finish();
    } else {
      mark.removeOverlayEntry();
    }
  }

  /// Starts a tour when the first step target is ready. Returns false if not ready.
  static Future<bool> startTour({
    required BuildContext context,
    required List<TourStepDefinition> steps,
    required TourId tourId,
    void Function(int index)? onStepChanged,
    VoidCallback? onComplete,
    int startAtStep = 0,
  }) async {
    if (steps.isEmpty) return false;
    if (!context.mounted) return false;

    dismissActive();

    final safeStart = startAtStep.clamp(0, steps.length - 1);

    Future<void> prepareStep(int index) async {
      if (index < 0 || index >= steps.length) return;
      final step = steps[index];
      onStepChanged?.call(index);
      await step.beforeShow?.call();
      await TourTargetReadiness.waitFor(step.targetKey);
    }

    await prepareStep(safeStart);
    if (!context.mounted ||
        !TourTargetReadiness.isReady(steps[safeStart].targetKey)) {
      return false;
    }

    final targets = <TargetFocus>[];

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepIndex = i;

      targets.add(
        TargetFocus(
          identify: step.id,
          keyTarget: step.targetKey,
          shape: step.shape,
          radius: step.focusRadius,
          paddingFocus: step.focusPadding,
          enableTargetTab: false,
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
              ),
              padding: EdgeInsets.zero,
              builder: (ctx, controller) {
                final media = MediaQuery.of(ctx);
                return Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: media.padding.top + 56,
                      bottom: media.padding.bottom + 80,
                    ),
                    child: TourCoachContent(
                      stepIndex: stepIndex,
                      totalSteps: steps.length,
                      titleKey: step.titleKey,
                      descriptionKey: step.descriptionKey,
                      showPrevious: stepIndex > 0,
                      isLastStep: stepIndex == steps.length - 1,
                      onPrevious: () async {
                        if (stepIndex <= 0) return;
                        await prepareStep(stepIndex - 1);
                        if (TourTargetReadiness.isReady(
                          steps[stepIndex - 1].targetKey,
                        )) {
                          controller.previous();
                        }
                      },
                      onNext: () async {
                        await TourService.saveLastStep(tourId, stepIndex + 1);
                        if (stepIndex >= steps.length - 1) {
                          controller.next();
                          return;
                        }
                        await prepareStep(stepIndex + 1);
                        if (TourTargetReadiness.isReady(
                          steps[stepIndex + 1].targetKey,
                        )) {
                          controller.next();
                        }
                      },
                      onSkip: controller.skip,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    if (!context.mounted) return false;

    final coachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      pulseEnable: true,
      hideSkip: true,
      useSafeArea: true,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: const Duration(milliseconds: 350),
      pulseAnimationDuration: const Duration(milliseconds: 900),
      onClickTarget: (_) {},
      onClickOverlay: (_) {},
      onFinish: () {
        unawaited(TourService.markCompleted(tourId));
        _activeCoachMark = null;
        onComplete?.call();
      },
      onSkip: () {
        unawaited(TourService.markSkipped(tourId));
        _activeCoachMark = null;
        onComplete?.call();
        return true;
      },
    );

    _activeCoachMark = coachMark;
    coachMark.show(context: context);

    if (safeStart > 0) {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
      await completer.future;

      await TourTargetReadiness.waitFor(
        steps[safeStart].targetKey,
        maxFrames: 12,
      );
      try {
        coachMark.goTo(safeStart);
      } catch (e, stack) {
        debugPrint(
          '[TourManager] Error navigating to step $safeStart: $e\n$stack',
        );
      }
    }

    return true;
  }
}
