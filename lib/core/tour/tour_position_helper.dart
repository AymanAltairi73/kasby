import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Resolves coach-mark content placement so tooltips never clip the status bar,
/// AppBar, or navigation bar on any screen size or orientation.
class TourPositionHelper {
  TourPositionHelper._();

  /// Estimated height of [TourCoachContent] including controls (conservative).
  static const double estimatedContentHeight = 300;

  static const double minEdgePadding = 12;

  static TourContentPlacement resolve(
    GlobalKey targetKey, {
    ContentAlign? preferred,
    BuildContext? context,
  }) {
    final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return TourContentPlacement(
        align: preferred ?? ContentAlign.bottom,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
    }

    final media = context != null
        ? MediaQuery.of(context)
        : MediaQueryData.fromView(
            WidgetsBinding.instance.platformDispatcher.views.first,
          );

    final screenSize = media.size;
    final safeTop = media.padding.top + minEdgePadding;
    final safeBottom = media.padding.bottom + minEdgePadding + 72;

    final targetTop = box.localToGlobal(Offset.zero).dy;
    final targetBottom = targetTop + box.size.height;
    final targetCenterY = targetTop + box.size.height / 2;

    final spaceAbove = targetTop - safeTop;
    final spaceBelow = screenSize.height - targetBottom - safeBottom;

    ContentAlign align;
    CustomTargetContentPosition? customPosition;

    final needsBelow = spaceBelow >= estimatedContentHeight * 0.65;
    final needsAbove = spaceAbove >= estimatedContentHeight * 0.65;

    if (preferred == ContentAlign.custom) {
      align = ContentAlign.custom;
    } else if (needsBelow && !needsAbove) {
      align = ContentAlign.bottom;
    } else if (needsAbove && !needsBelow) {
      align = ContentAlign.top;
    } else if (needsBelow && needsAbove) {
      // Both fit — prefer below for upper-half targets, above for lower-half.
      align = targetCenterY < screenSize.height * 0.45
          ? ContentAlign.bottom
          : ContentAlign.top;
    } else {
      // Tight layout (small phone / landscape): anchor card in safe center band.
      align = ContentAlign.custom;
      customPosition = CustomTargetContentPosition(
        top: safeTop,
        left: minEdgePadding,
        right: minEdgePadding,
        bottom: safeBottom,
      );
    }

    // Override bad preferred align when it would clip.
    if (preferred != null && align != ContentAlign.custom) {
      if (preferred == ContentAlign.top && spaceAbove < estimatedContentHeight * 0.4) {
        align = needsBelow ? ContentAlign.bottom : ContentAlign.custom;
      }
      if (preferred == ContentAlign.bottom && spaceBelow < estimatedContentHeight * 0.4) {
        align = needsAbove ? ContentAlign.top : ContentAlign.custom;
      }
    }

    if (align == ContentAlign.custom && customPosition == null) {
      customPosition = CustomTargetContentPosition(
        top: safeTop,
        left: minEdgePadding,
        right: minEdgePadding,
        bottom: safeBottom,
      );
    }

    return TourContentPlacement(
      align: align,
      customPosition: customPosition,
      padding: EdgeInsets.symmetric(
        horizontal: media.size.width > 600 ? 24 : 16,
        vertical: 10,
      ),
    );
  }
}

class TourContentPlacement {
  const TourContentPlacement({
    required this.align,
    this.customPosition,
    this.padding = const EdgeInsets.all(16),
  });

  final ContentAlign align;
  final CustomTargetContentPosition? customPosition;
  final EdgeInsets padding;
}
