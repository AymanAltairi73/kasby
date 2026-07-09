import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';

/// Reusable definition for a single coach-mark step in any feature tour.
class TourStepDefinition {
  const TourStepDefinition({
    required this.id,
    required this.tourId,
    required this.targetKey,
    required this.titleKey,
    required this.descriptionKey,
    this.preferredAlign,
    this.shape = ShapeLightFocus.Circle,
    this.focusRadius = 16,
    this.focusPadding = 8,
    this.beforeShow,
  });

  final String id;
  final TourId tourId;
  final GlobalKey targetKey;
  final String titleKey;
  final String descriptionKey;

  /// Hint for [TourPositionHelper]; may be overridden when space is tight.
  final ContentAlign? preferredAlign;
  final ShapeLightFocus shape;
  final double focusRadius;
  final double focusPadding;

  /// Runs before the step is shown (scroll, tab switch, etc.).
  final Future<void> Function()? beforeShow;
}
