import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/models/spin_reward_model.dart';

/// Premium black & gold Kasby spin wheel — aligned with reference design.
class KasbySpinWheelPainter extends CustomPainter {
  KasbySpinWheelPainter({
    required this.rewards,
    this.highlightIndex,
    this.highlightPulse = 0,
  });

  final List<SpinReward> rewards;
  final int? highlightIndex;
  final double highlightPulse;

  static const Color _goldLight = Color(0xFFF5D77A);
  static const Color _goldMid = Color(0xFFC9A24D);
  static const Color _goldDark = Color(0xFF8B6914);
  static const Color _blackMatte = Color(0xFF0D0D0D);
  static const Color _blackDeep = Color(0xFF050505);

  @override
  void paint(Canvas canvas, Size size) {
    if (rewards.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final count = rewards.length;
    final sweep = (2 * math.pi) / count;
    const startAngle = -math.pi / 2;

    // Drop shadow under wheel disc
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center.translate(0, 6), radius - 4, shadowPaint);

    for (var i = 0; i < count; i++) {
      final isGold = i.isEven;
      final segmentStart = startAngle + i * sweep;
      final isHighlighted = highlightIndex == i;

      final segmentPaint = Paint()
        ..shader = isGold
            ? RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: isHighlighted
                    ? [
                        Color.lerp(
                          _goldLight,
                          Colors.white,
                          highlightPulse * 0.35,
                        )!,
                        _goldMid,
                        _goldDark,
                      ]
                    : [_goldLight, _goldMid, _goldDark],
                stops: const [0.15, 0.62, 1.0],
              ).createShader(rect)
            : RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: isHighlighted
                    ? [
                        Color.lerp(
                          _blackMatte,
                          _goldMid,
                          highlightPulse * 0.25,
                        )!,
                        _blackDeep,
                      ]
                    : [_blackMatte, _blackDeep],
              ).createShader(rect);

      canvas.drawArc(rect, segmentStart, sweep, true, segmentPaint);

      if (isGold) {
        final grainPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.045)
          ..strokeWidth = 0.55;
        for (var g = 0; g < 14; g++) {
          final t = g / 14;
          canvas.drawLine(
            Offset(
              center.dx + (radius * 0.18) * math.cos(segmentStart + sweep * t),
              center.dy + (radius * 0.18) * math.sin(segmentStart + sweep * t),
            ),
            Offset(
              center.dx + (radius * 0.93) * math.cos(segmentStart + sweep * t),
              center.dy + (radius * 0.93) * math.sin(segmentStart + sweep * t),
            ),
            grainPaint,
          );
        }
      }

      if (isHighlighted) {
        final glow = Paint()
          ..color = _goldMid.withValues(alpha: 0.22 + highlightPulse * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        canvas.drawArc(rect, segmentStart + 0.02, sweep - 0.04, true, glow);
      }

      final dividerPaint = Paint()
        ..color = _goldMid.withValues(alpha: 0.9)
        ..strokeWidth = 1.8;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(segmentStart),
          center.dy + radius * math.sin(segmentStart),
        ),
        dividerPaint,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(segmentStart + sweep / 2);

      _drawStud(canvas, radius);
      canvas.restore();
    }

    final innerRing = Paint()
      ..color = _goldMid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    canvas.drawCircle(center, radius - 2, innerRing);
  }

  void _drawStud(Canvas canvas, double radius) {
    final studCenter = Offset(0, -radius + 20);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(studCenter.translate(0, 1.5), 5.5, shadow);

    final studPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.45),
        radius: 0.95,
        colors: [Color(0xFFFFF0B3), Color(0xFFC9A24D), Color(0xFF7A5C12)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: studCenter, radius: 5.5));
    canvas.drawCircle(studCenter, 5.5, studPaint);
  }

  @override
  bool shouldRepaint(covariant KasbySpinWheelPainter oldDelegate) {
    if (highlightIndex != oldDelegate.highlightIndex ||
        highlightPulse != oldDelegate.highlightPulse ||
        rewards.length != oldDelegate.rewards.length) {
      return true;
    }
    for (var i = 0; i < rewards.length; i++) {
      final current = rewards[i];
      final previous = oldDelegate.rewards[i];
      if (current.label != previous.label ||
          current.points != previous.points ||
          current.iconName != previous.iconName) {
        return true;
      }
    }
    return false;
  }
}

/// Rotating segment labels rendered as widgets (avoids canvas clipping).
class KasbySpinWheelSegmentLabels extends StatelessWidget {
  const KasbySpinWheelSegmentLabels({
    super.key,
    required this.rewards,
    required this.diameter,
  });

  final List<SpinReward> rewards;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) return const SizedBox.shrink();

    final radius = diameter / 2;
    final sweep = (2 * math.pi) / rewards.length;
    const startAngle = -math.pi / 2;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < rewards.length; i++)
            _SegmentLabel(
              reward: rewards[i],
              angle: startAngle + i * sweep + sweep / 2,
              radius: radius,
              isGold: i.isEven,
            ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.reward,
    required this.angle,
    required this.radius,
    required this.isGold,
  });

  final SpinReward reward;
  final double angle;
  final double radius;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    final labelRadius = radius * 0.66;
    final x = radius + labelRadius * math.cos(angle);
    final y = radius + labelRadius * math.sin(angle);
    final textColor = isGold ? Colors.black : Colors.white;
    final label = reward.wheelSegmentText;

    return Positioned(
      left: x - 30,
      top: y - 16,
      width: 60,
      height: 32,
      child: Transform.rotate(
        angle: angle + math.pi / 2,
        child: Center(
          child: reward.isGift
              ? Icon(Icons.card_giftcard_rounded, color: textColor, size: 22)
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: label.length >= 3 ? 17 : 21,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: isGold
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.65),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Ambient gold glow behind the wheel.
class KasbySpinWheelAmbientGlow extends StatelessWidget {
  const KasbySpinWheelAmbientGlow({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.15,
      height: size * 1.15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFC9A24D).withValues(alpha: 0.22),
            const Color(0xFFC9A24D).withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.35, 0.65, 1.0],
        ),
      ),
    );
  }
}

/// Fixed outer gold rim with warm LED bulbs (marquee effect).
class KasbySpinWheelOuterRing extends StatelessWidget {
  const KasbySpinWheelOuterRing({
    super.key,
    required this.size,
    this.ledCount = 24,
  });

  final double size;
  final int ledCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFF5D77A),
                  Color(0xFFC9A24D),
                  Color(0xFF8B6914),
                ],
                stops: [0.52, 0.8, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC9A24D).withValues(alpha: 0.5),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          Container(
            width: size - size * 0.082,
            height: size - size * 0.082,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF0F172A),
            ),
          ),
          ...List.generate(ledCount, (i) {
            return Transform.rotate(
              angle: (2 * math.pi * i) / ledCount,
              child: Transform.translate(
                offset: Offset(0, -(size / 2) + size * 0.028),
                child: _LedBulb(index: i),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LedBulb extends StatelessWidget {
  const _LedBulb({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFF8E7),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFF8E7).withValues(alpha: 0.95),
                blurRadius: 10,
                spreadRadius: 1.5,
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(0.55, 0.55),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 900),
          delay: Duration(milliseconds: (index * 70) % 900),
        )
        .fade(
          begin: 0.45,
          end: 1.0,
          duration: const Duration(milliseconds: 900),
        );
  }
}

/// 3D gold triangular pointer at 12 o'clock.
class KasbySpinWheelPointer extends StatelessWidget {
  const KasbySpinWheelPointer({super.key, this.isAnimating = false});

  final bool isAnimating;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(38, 48), painter: _GoldPointerPainter());
  }
}

class _GoldPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, shadow);
    canvas.restore();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF5D77A), Color(0xFFC9A24D), Color(0xFF8B6914)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fill);

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width * 0.32, 2),
      Offset(size.width / 2, size.height - 8),
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Center hub with stylized Kasby "K" and lens-flare glint.
class KasbySpinWheelCenterHub extends StatelessWidget {
  const KasbySpinWheelCenterHub({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFFC9A24D), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: const Color(0xFFC9A24D).withValues(alpha: 0.3),
            blurRadius: 18,
          ),
        ],
      ),
      child: CustomPaint(painter: _KasbyKLogoPainter(), size: Size(size, size)),
    );
  }
}

class _KasbyKLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final kPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5D77A), Color(0xFFC9A24D), Color(0xFF8B6914)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.3));

    final scale = size.width / 78;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final path = Path()
      ..moveTo(-14, -18)
      ..lineTo(-14, 18)
      ..lineTo(-6, 18)
      ..lineTo(-6, 2)
      ..lineTo(8, 18)
      ..lineTo(18, 18)
      ..lineTo(-2, -2)
      ..lineTo(16, -18)
      ..lineTo(6, -18)
      ..lineTo(-6, -4)
      ..lineTo(-6, -18)
      ..close();

    canvas.drawPath(path, kPaint);

    final glint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(const Offset(-10, -12), 2.2, glint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Responsive wheel diameter based on screen width.
double kasbySpinWheelDiameter(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width.clamp(300.0, 520.0) * 0.88;
}
