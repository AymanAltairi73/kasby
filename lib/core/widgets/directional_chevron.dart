import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// A chevron that automatically points in the correct direction for the active
/// text direction (audit item: `arrow_forward_ios` doesn't flip in RTL).
///
/// In LTR it points right (›), in RTL it points left (‹).
class DirectionalChevron extends StatelessWidget {
  final double size;
  final Color? color;

  const DirectionalChevron({super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
      size: size,
      color: color ?? AppColors.textSecondary,
    );
  }
}
