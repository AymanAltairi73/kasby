import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Locale-aware date/time formatting.
///
/// Replaces ad-hoc `day/month/year` string building with `intl` `DateFormat`
/// so dates render correctly in both Arabic and English (audit item H7).
class DateHelper {
  DateHelper._();

  static String get _localeTag =>
      (Get.locale?.languageCode ?? 'ar') == 'ar' ? 'ar' : 'en';

  /// Builds a [DateFormat] for the active locale, falling back to the default
  /// locale if locale symbol data has not been initialized.
  static String _format(DateTime value, DateFormat Function(String?) builder) {
    final local = value.toLocal();
    try {
      return builder(_localeTag).format(local);
    } catch (_) {
      return builder(null).format(local);
    }
  }

  /// e.g. "Jun 16, 2026" / "١٦ يونيو ٢٠٢٦"
  static String date(DateTime? value) {
    if (value == null) return '--';
    return _format(value, (l) => DateFormat.yMMMd(l));
  }

  /// e.g. "Jun 16, 2026 · 5:56 PM"
  static String dateTime(DateTime? value) {
    if (value == null) return '--';
    final d = value.toLocal();
    return '${date(d)} · ${time(d)}';
  }

  /// e.g. "5:56 PM"
  static String time(DateTime? value) {
    if (value == null) return '--';
    return _format(value, (l) => DateFormat.jm(l));
  }

  /// Short relative label for activity feeds (Today / Yesterday / date).
  static String relative(DateTime? value) {
    if (value == null) return '--';
    final now = DateTime.now();
    final local = value.toLocal();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(local.year, local.month, local.day))
        .inDays;
    if (diff == 0) return 'today'.tr;
    if (diff == 1) return 'yesterday'.tr;
    return date(local);
  }
}
