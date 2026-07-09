import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum SlaLevel { normal, warning, overdue }

/// Formats pending-request wait times and SLA severity.
class SlaFormatter {
  static const int warningMinutes = 15;
  static const int overdueMinutes = 60;

  static Duration waitingDuration(DateTime createdAt) {
    return DateTime.now().difference(createdAt);
  }

  static SlaLevel levelFor(DateTime createdAt) {
    final minutes = waitingDuration(createdAt).inMinutes;
    if (minutes >= overdueMinutes) return SlaLevel.overdue;
    if (minutes >= warningMinutes) return SlaLevel.warning;
    return SlaLevel.normal;
  }

  static String waitingLabel(DateTime createdAt) {
    final d = waitingDuration(createdAt);
    if (d.inMinutes < 1) {
      return 'waiting_seconds'
          .tr
          .replaceAll('@n', '${d.inSeconds}');
    }
    if (d.inMinutes < 60) {
      return 'waiting_minutes'.tr.replaceAll('@n', '${d.inMinutes}');
    }
    if (d.inHours < 24) {
      return 'waiting_hours'.tr.replaceAll('@n', '${d.inHours}');
    }
    return 'waiting_days'.tr.replaceAll('@n', '${d.inDays}');
  }

  static Color colorFor(SlaLevel level) {
    switch (level) {
      case SlaLevel.normal:
        return Colors.green;
      case SlaLevel.warning:
        return Colors.orange;
      case SlaLevel.overdue:
        return Colors.red;
    }
  }
}
