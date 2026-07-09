import 'package:flutter/material.dart';

import 'package:kasby/core/tour/tour_controller.dart';
import 'package:kasby/core/tour/tour_ids.dart';

/// Schedules a feature tour for pushed routes (not main-shell tabs).
class TourFeatureHost {
  TourFeatureHost._();

  static void scheduleForRoute(BuildContext context, TourId tourId) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      if (TourController.to.isRunning.value) return;
      await TourController.to.tryStartFeatureTour(context, tourId);
    });
  }

  @Deprecated('Use scheduleForRoute for pushed routes only.')
  static void schedule(BuildContext context, TourId tourId) =>
      scheduleForRoute(context, tourId);
}
