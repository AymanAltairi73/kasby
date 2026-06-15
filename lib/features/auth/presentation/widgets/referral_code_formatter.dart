import 'package:flutter/services.dart';

/// Uppercases referral input and strips invalid characters while keeping
/// selection valid. Hyphens are allowed (K-AB12CD) — matching is normalized
/// server-side.
class ReferralCodeFormatter extends TextInputFormatter {
  const ReferralCodeFormatter();

  static const int maxLength = 16;
  static final RegExp _allowedChars = RegExp(r'[A-Za-z0-9-]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (var i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];
      if (_allowedChars.hasMatch(char)) {
        buffer.write(char.toUpperCase());
      }
    }

    final text = buffer.toString();
    final trimmed = text.length > maxLength ? text.substring(0, maxLength) : text;

    return TextEditingValue(
      text: trimmed,
      selection: _mapSelection(
        oldValue: oldValue,
        newValue: newValue,
        formattedText: trimmed,
      ),
      composing: TextRange.empty,
    );
  }

  static TextSelection _mapSelection({
    required TextEditingValue oldValue,
    required TextEditingValue newValue,
    required String formattedText,
  }) {
    final length = formattedText.length;
    if (length == 0) {
      return const TextSelection.collapsed(offset: 0);
    }

    final base = _mapOffset(newValue.text, formattedText, newValue.selection.baseOffset);
    final extent = _mapOffset(newValue.text, formattedText, newValue.selection.extentOffset);

    final clampedBase = base.clamp(0, length);
    final clampedExtent = extent.clamp(0, length);
    if (clampedBase == clampedExtent) {
      return TextSelection.collapsed(offset: clampedBase);
    }
    return TextSelection(baseOffset: clampedBase, extentOffset: clampedExtent);
  }

  static int _mapOffset(String rawText, String formattedText, int rawOffset) {
    if (rawOffset <= 0) return 0;

    final safeRawOffset = rawOffset.clamp(0, rawText.length);
    final prefix = rawText.substring(0, safeRawOffset);
    final buffer = StringBuffer();
    for (var i = 0; i < prefix.length; i++) {
      final char = prefix[i];
      if (_allowedChars.hasMatch(char)) {
        buffer.write(char.toUpperCase());
      }
    }
    var mapped = buffer.length;
    if (mapped > formattedText.length) {
      mapped = formattedText.length;
    }
    if (mapped == 0 && formattedText.isNotEmpty && safeRawOffset >= rawText.length) {
      return formattedText.length;
    }
    return mapped;
  }
}
