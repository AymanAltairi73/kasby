import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';

/// A dependency-free sparkline used for portfolio / P&L trend visualization.
///
/// Intentionally lightweight (CustomPaint) to avoid adding a charting package
/// and to keep rebuilds cheap. Respects reduced-motion via [animate].
class KasbySparkline extends StatelessWidget {
  final List<double> data;
  final Color? lineColor;
  final double height;
  final double strokeWidth;
  final bool fill;

  const KasbySparkline({
    super.key,
    required this.data,
    this.lineColor,
    this.height = 56,
    this.strokeWidth = 2.5,
    this.fill = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = lineColor ?? AppColors.darkGold;
    if (data.length < 2) {
      return SizedBox(height: height);
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: color,
          strokeWidth: strokeWidth,
          fill: fill,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;
  final bool fill;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minV = data.reduce((a, b) => a < b ? a : b);
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
    final dx = size.width / (data.length - 1);

    Offset pointAt(int i) {
      final x = dx * i;
      final norm = (data[i] - minV) / range;
      final y = size.height - (norm * (size.height - strokeWidth)) -
          strokeWidth / 2;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < data.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size);
      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

// ─── WATERFALL CHART ──────────────────────────────────────────

class WaterfallStep {
  final String label;
  final double value;
  final bool isTotal;
  final Color? color;

  const WaterfallStep({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.color,
  });
}

class KasbyWaterfallChart extends StatelessWidget {
  final List<WaterfallStep> steps;
  final double height;

  const KasbyWaterfallChart({
    super.key,
    required this.steps,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaterfallPainter(
          steps: steps,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  final List<WaterfallStep> steps;
  final TextDirection textDirection;

  _WaterfallPainter({required this.steps, required this.textDirection});

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;

    final n = steps.length;
    final barPadding = 6.0;
    final barWidth = (size.width - barPadding * (n + 1)) / n;
    final labelHeight = 28.0;
    final chartHeight = size.height - labelHeight;

    double maxVal = 0;
    double runningBase = 0;
    final List<_BarRect> bars = [];

    for (final step in steps) {
      double top, bottom;
      if (step.isTotal) {
        top = 0;
        bottom = step.value.abs();
        runningBase = step.value;
      } else {
        if (step.value >= 0) {
          top = runningBase;
          bottom = runningBase + step.value;
          runningBase = bottom;
        } else {
          bottom = runningBase;
          top = runningBase + step.value;
          runningBase = top;
        }
      }
      bars.add(_BarRect(top: top, bottom: bottom));
      if (bottom.abs() > maxVal) maxVal = bottom.abs();
      if (top.abs() > maxVal) maxVal = top.abs();
    }
    if (maxVal == 0) maxVal = 1;

    final scale = (chartHeight - 8) / maxVal;

    final connectorPaint = Paint()
      ..color = const Color(0x44888888)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < n; i++) {
      final step = steps[i];
      final bar = bars[i];
      final x = barPadding + i * (barWidth + barPadding);
      final yTop = chartHeight - bar.bottom * scale;
      final yBottom = chartHeight - bar.top * scale;

      Color barColor;
      if (step.color != null) {
        barColor = step.color!;
      } else if (step.isTotal) {
        barColor = AppColors.darkGold;
      } else if (step.value >= 0) {
        barColor = AppColors.softGreen;
      } else {
        barColor = AppColors.error;
      }

      final barPaint = Paint()..color = barColor;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, yTop.clamp(0, chartHeight), x + barWidth, yBottom.clamp(0, chartHeight)),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);

      // Value label on bar
      final valText = _formatValue(step.value);
      final valSpan = TextSpan(
        text: valText,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: barColor,
        ),
      );
      final valPainter = TextPainter(
        text: valSpan,
        textDirection: textDirection,
      )..layout(maxWidth: barWidth + barPadding * 2);
      valPainter.paint(
        canvas,
        Offset(x + (barWidth - valPainter.width) / 2, yTop - valPainter.height - 2),
      );

      // Bottom label
      final labelSpan = TextSpan(
        text: step.label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w500,
          color: Color(0xFF999999),
        ),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: barWidth + barPadding);
      labelPainter.paint(
        canvas,
        Offset(x + (barWidth - labelPainter.width) / 2, chartHeight + 4),
      );

      // Connector line to next bar
      if (i < n - 1 && !steps[i + 1].isTotal) {
        final connectorY = chartHeight - bar.bottom * scale;
        canvas.drawLine(
          Offset(x + barWidth, connectorY),
          Offset(x + barWidth + barPadding, connectorY),
          connectorPaint,
        );
      }
    }
  }

  String _formatValue(double v) {
    final abs = v.abs();
    if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter oldDelegate) =>
      oldDelegate.steps != steps;
}

class _BarRect {
  final double top;
  final double bottom;
  const _BarRect({required this.top, required this.bottom});
}

/// A single segment for [KasbyAllocationBar].
class AllocationSegment {
  final String label;
  final double value;
  final Color color;

  const AllocationSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Horizontal stacked asset-allocation bar with a legend.
class KasbyAllocationBar extends StatelessWidget {
  final List<AllocationSegment> segments;
  final double barHeight;

  const KasbyAllocationBar({
    super.key,
    required this.segments,
    this.barHeight = 14,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: KasbyRadius.chipR,
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: [
                for (final seg in segments)
                  Expanded(
                    flex: ((seg.value / total) * 1000).round().clamp(1, 1000),
                    child: Container(color: seg.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KasbySpacing.md),
        Wrap(
          spacing: KasbySpacing.lg,
          runSpacing: KasbySpacing.sm,
          children: [
            for (final seg in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: seg.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: KasbySpacing.sm),
                  Text(
                    '${seg.label}  ${((seg.value / total) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
