import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class FeeEntry {
  final String id;
  final String label;
  final String category;
  final double percentage;
  final double fixedAmount;
  final bool isActive;

  const FeeEntry({
    required this.id,
    required this.label,
    required this.category,
    this.percentage = 0,
    this.fixedAmount = 0,
    this.isActive = true,
  });

  double calculate(double amount) {
    if (!isActive) return 0;
    return (amount * percentage / 100) + fixedAmount;
  }

  factory FeeEntry.fromJson(Map<String, dynamic> json) {
    return FeeEntry(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? '',
      category: json['category']?.toString().toLowerCase() ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      fixedAmount: (json['fixed_amount'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class LimitEntry {
  final String id;
  final String label;
  final String category;
  final String tier;
  final double value;
  final bool isUnlimited;

  const LimitEntry({
    required this.id,
    required this.label,
    required this.category,
    required this.tier,
    this.value = 0,
    this.isUnlimited = false,
  });

  factory LimitEntry.fromJson(Map<String, dynamic> json) {
    return LimitEntry(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? '',
      category: json['category']?.toString().toLowerCase() ?? '',
      tier: json['tier']?.toString().toLowerCase() ?? 'normal',
      value: double.tryParse(json['value']?.toString() ?? '0') ?? 0,
      isUnlimited: json['is_unlimited'] ?? false,
    );
  }
}

class FeeService {
  FeeService._();

  static List<FeeEntry> _fees = [];
  static List<LimitEntry> _limits = [];
  static DateTime? _lastFetch;

  static Future<void> load({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastFetch != null &&
        now.difference(_lastFetch!).inMinutes < 10) {
      return;
    }
    try {
      final feesRes = await SupabaseService.client
          .from('fees')
          .select()
          .eq('is_active', true);
      _fees = (feesRes as List).map((e) => FeeEntry.fromJson(e)).toList();

      final limitsRes =
          await SupabaseService.client.from('transaction_limits').select();
      _limits =
          (limitsRes as List).map((e) => LimitEntry.fromJson(e)).toList();

      _lastFetch = now;
      SafeGetx.debugTrace(
        className: 'FeeService',
        method: 'load',
        feature: 'Core',
        status: 'SUCCESS',
        params: {'fees': _fees.length, 'limits': _limits.length},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FeeService',
        method: 'load',
        feature: 'Core',
        status: 'FAILED',
        error: e,
        stackTrace: stack,
      );
    }
  }

  static List<FeeEntry> feesFor(String category) =>
      _fees.where((f) => f.category == category && f.isActive).toList();

  static double totalFee(String category, double amount) {
    final applicable = feesFor(category);
    if (applicable.isEmpty) return 0;
    double total = 0;
    for (final fee in applicable) {
      total += fee.calculate(amount);
    }
    return total;
  }

  /// Human-readable fee lines for UI (percentage + fixed parts).
  static List<String> feeDescriptionLines(String category, double amount) {
    final lines = <String>[];
    for (final fee in feesFor(category)) {
      final value = fee.calculate(amount);
      if (value <= 0) continue;
      final parts = <String>[];
      if (fee.percentage > 0) {
        parts.add('${fee.percentage.toStringAsFixed(fee.percentage % 1 == 0 ? 0 : 2)}%');
      }
      if (fee.fixedAmount > 0) {
        parts.add('\$${fee.fixedAmount.toStringAsFixed(2)}');
      }
      final rateLabel = parts.isEmpty ? '' : ' (${parts.join(' + ')})';
      final label = fee.label.isNotEmpty ? fee.label : category;
      lines.add('$label$rateLabel: \$${value.toStringAsFixed(2)}');
    }
    return lines;
  }

  static String feeRateLabel(String category) {
    final applicable = feesFor(category);
    if (applicable.isEmpty) return '';
    final parts = <String>[];
    for (final fee in applicable) {
      if (fee.percentage > 0) {
        parts.add('${fee.percentage.toStringAsFixed(fee.percentage % 1 == 0 ? 0 : 2)}%');
      }
      if (fee.fixedAmount > 0) {
        parts.add('\$${fee.fixedAmount.toStringAsFixed(2)}');
      }
    }
    return parts.join(' + ');
  }

  static double? minLimit(String category, {String tier = 'normal'}) {
    final match = _limits.where((l) =>
        l.category == category &&
        l.tier == tier &&
        l.label.contains('الأدنى'));
    if (match.isEmpty) return null;
    return match.first.isUnlimited ? null : match.first.value;
  }

  static double? maxLimit(String category, {String tier = 'normal'}) {
    final match = _limits.where((l) =>
        l.category == category &&
        l.tier == tier &&
        l.label.contains('الأقصى'));
    if (match.isEmpty) return null;
    return match.first.isUnlimited ? null : match.first.value;
  }

  static String? validateAmount(
    double amount,
    String category, {
    String tier = 'normal',
  }) {
    final min = minLimit(category, tier: tier);
    final max = maxLimit(category, tier: tier);
    if (min != null && amount < min) {
      return 'الحد الأدنى لهذه العملية هو \$${min.toStringAsFixed(0)}';
    }
    if (max != null && max > 0 && amount > max) {
      return 'الحد الأقصى لهذه العملية هو \$${max.toStringAsFixed(0)}';
    }
    return null;
  }
}
