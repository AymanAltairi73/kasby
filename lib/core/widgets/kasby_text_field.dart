import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_typography.dart';
import 'package:flutter_animate/flutter_animate.dart';

class KasbyTextField extends StatefulWidget {
  final String? label;
  final String hint;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? passwordFieldSuffixIcon;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool readOnly;
  final bool enabled;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  const KasbyTextField({
    super.key,
    this.label,
    required this.hint,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.passwordFieldSuffixIcon,
    this.onChanged,
    this.validator,
    this.readOnly = false,
    this.enabled = true,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
    this.inputFormatters,
  });

  @override
  State<KasbyTextField> createState() => _KasbyTextFieldState();
}

class _KasbyTextFieldState extends State<KasbyTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  void didUpdateWidget(covariant KasbyTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPassword != widget.isPassword) {
      _obscureText = widget.isPassword;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: TextStyle(
                  fontFamily: KasbyTypography.fontFamily,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                  fontSize:
                      KasbyTypography.sp(ar: 14.0, en: 13.0, context: context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: widget.controller,
              obscureText: _obscureText,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
              onTap: widget.onTap,
              validator: widget.validator,
              readOnly: widget.readOnly,
              enabled: widget.enabled,
              autocorrect: widget.autocorrect,
              textCapitalization: widget.textCapitalization,
              style: TextStyle(
                fontFamily: KasbyTypography.fontFamily,
                fontSize:
                    KasbyTypography.sp(ar: 15.0, en: 14.0, context: context),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontFamily: KasbyTypography.fontFamily,
                  fontSize:
                      KasbyTypography.sp(ar: 14.0, en: 13.0, context: context),
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.isPassword
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.passwordFieldSuffixIcon != null) ...[
                            widget.passwordFieldSuffixIcon!,
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ],
                      )
                    : widget.suffixIcon,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.transparent
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.transparent
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.darkGold, width: 1.5),
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideX(begin: 0.05, end: 0);
  }
}
