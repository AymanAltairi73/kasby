import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';

/// Live password-strength indicator (audit item M9).
///
/// Listens to a [TextEditingController] and renders a 4-segment bar plus a
/// localized strength label. Purely presentational — does not enforce policy.
class PasswordStrengthMeter extends StatefulWidget {
  final TextEditingController controller;

  const PasswordStrengthMeter({super.key, required this.controller});

  @override
  State<PasswordStrengthMeter> createState() => _PasswordStrengthMeterState();
}

class _PasswordStrengthMeterState extends State<PasswordStrengthMeter> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  /// Returns a score 0..4.
  int get _score {
    final p = widget.controller.text;
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(p)) score++;
    return score.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.text.isEmpty) return const SizedBox.shrink();

    final score = _score;
    final (color, label) = switch (score) {
      <= 1 => (AppColors.error, 'password_weak'.tr),
      2 => (Colors.orange, 'password_fair'.tr),
      3 => (AppColors.darkGold, 'password_good'.tr),
      _ => (AppColors.softGreen, 'password_strong'.tr),
    };

    return Padding(
      padding: const EdgeInsets.only(top: KasbySpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              final active = i < score;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? KasbySpacing.xs : 0),
                  decoration: BoxDecoration(
                    color: active
                        ? color
                        : AppColors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: KasbySpacing.xs),
          Text(
            '${'password_strength'.tr}: $label',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
