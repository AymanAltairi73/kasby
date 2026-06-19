import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';

/// Multi-digit OTP input with paste, focus advance, and auto-submit.
class AuthOtpInput extends StatefulWidget {
  const AuthOtpInput({
    super.key,
    required this.length,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.enableSmsAutofill = false,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool enableSmsAutofill;

  @override
  AuthOtpInputState createState() => AuthOtpInputState();
}

class AuthOtpInputState extends State<AuthOtpInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _initFields(widget.length);
    if (widget.enableSmsAutofill && widget.length > 0) {
      _focusNodes.first.requestFocus();
    }
  }

  @override
  void didUpdateWidget(AuthOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.length != widget.length) {
      _disposeFields();
      _initFields(widget.length);
    }
  }

  void _initFields(int length) {
    _controllers = List.generate(length, (_) => TextEditingController());
    _focusNodes = List.generate(length, (_) => FocusNode());
  }

  void _disposeFields() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
  }

  @override
  void dispose() {
    _disposeFields();
    super.dispose();
  }

  String get code => _controllers.map((c) => c.text).join();

  /// Programmatically fill OTP (e.g. FCM auto-fill).
  void fillCode(String raw) {
    final digits = AuthOtpConfig.normalize(raw);
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    _notifyChanged();
    if (AuthOtpConfig.isComplete(digits, widget.length)) {
      widget.onCompleted(digits.substring(0, widget.length));
    } else if (digits.isNotEmpty) {
      final focusIndex = digits.length.clamp(0, widget.length - 1);
      _focusNodes[focusIndex].requestFocus();
    }
    setState(() {});
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    _notifyChanged();
    setState(() {});
  }

  void _notifyChanged() => widget.onChanged?.call(code);

  void _applyInput(int index, String value) {
    if (value.length > 1) {
      fillCode(value);
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    _notifyChanged();
    final joined = code;
    if (AuthOtpConfig.isComplete(joined, widget.length)) {
      widget.onCompleted(AuthOtpConfig.normalize(joined));
    }
    setState(() {});
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      fillCode(text);
    }
  }

  double _boxWidth(int length) {
    if (length <= 6) return 46;
    if (length == 7) return 42;
    if (length == 8) return 38;
    return 34;
  }

  double _fontSize(int length) {
    if (length <= 6) return 22;
    if (length <= 8) return 18;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxWidth = _boxWidth(widget.length);
    final fontSize = _fontSize(widget.length);

    return Column(
      children: [
        if (widget.enableSmsAutofill)
          SizedBox(
            height: 0,
            width: 0,
            child: TextField(
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (value.length >= widget.length) {
                  fillCode(value);
                }
              },
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(widget.length, (index) {
            return SizedBox(
              width: boxWidth,
              height: 58,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                enabled: widget.enabled,
                autofocus: index == 0,
                autofillHints: widget.enableSmsAutofill && index == 0
                    ? const [AutofillHints.oneTimeCode]
                    : null,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onChanged: (value) => _applyInput(index, value),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.darkGold, width: 2),
                  ),
                  enabledBorder: _controllers[index].text.isNotEmpty
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.darkGold.withValues(alpha: 0.5),
                          ),
                        )
                      : null,
                ),
              ),
            );
          }),
        ),
        if (widget.enabled) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _pasteFromClipboard,
            icon: Icon(Icons.content_paste_rounded,
                size: 18, color: AppColors.darkGold),
            label: Text(
              'paste_code'.tr,
              style: TextStyle(
                color: AppColors.darkGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
