import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';

class KycGuideGeometry {
  final ui.Rect ovalRect;
  final ui.Size imageSize;

  const KycGuideGeometry({required this.ovalRect, required this.imageSize});

  static KycGuideGeometry forSize(ui.Size size) {
    final shortest = math.min(size.width, size.height);
    final ovalWidth = shortest * 0.68;
    final ovalHeight = shortest * 0.88;
    final left = (size.width - ovalWidth) / 2;
    final top = (size.height - ovalHeight) / 2.05;
    return KycGuideGeometry(
      imageSize: size,
      ovalRect: ui.Rect.fromLTWH(left, top, ovalWidth, ovalHeight),
    );
  }
}

/// Static oval framing guide — visual only, no face detection.
class KycFaceGuidePainter extends CustomPainter {
  final KycGuideGeometry geometry;
  final bool showSuccess;
  final double pulse;

  KycFaceGuidePainter({
    required this.geometry,
    this.showSuccess = false,
    this.pulse = 0.35,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final oval = Path()..addOval(geometry.ovalRect);
    final mask = Path.combine(PathOperation.difference, full, oval);
    canvas.drawPath(mask, overlay);

    final borderColor =
        showSuccess ? AppColors.softGreen : AppColors.darkGold;
    final stroke = showSuccess ? 5.0 : 3 + (pulse * 1.5);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = borderColor.withValues(
        alpha: showSuccess ? 1 : 0.85 + pulse * 0.15,
      );
    canvas.drawOval(geometry.ovalRect, border);

    if (showSuccess) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = AppColors.softGreen.withValues(alpha: 0.25);
      canvas.drawOval(geometry.ovalRect.inflate(6), glow);
    }

    final tickPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    final center = geometry.ovalRect.center;
    canvas.drawLine(
      Offset(center.dx, geometry.ovalRect.top + 12),
      Offset(center.dx, geometry.ovalRect.top + 36),
      tickPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 18, center.dy),
      Offset(center.dx + 18, center.dy),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant KycFaceGuidePainter oldDelegate) {
    return oldDelegate.showSuccess != showSuccess ||
        oldDelegate.pulse != pulse ||
        oldDelegate.geometry.ovalRect != geometry.ovalRect;
  }
}
