import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Enterprise Earnings Analytics Model
/// Server-authoritative earnings data from get_earnings_analytics RPC
class EarningsAnalyticsModel {
  final bool success;
  final String? error;
  final Summary? summary;
  final Statistics? statistics;
  final List<BreakdownItem> breakdown;
  final ChartData? chartData;
  final List<TimelineItem> timeline;

  const EarningsAnalyticsModel({
    required this.success,
    this.error,
    this.summary,
    this.statistics,
    this.breakdown = const [],
    this.chartData,
    this.timeline = const [],
  });

  factory EarningsAnalyticsModel.fromJson(Map<String, dynamic> json) {
    try {
      return EarningsAnalyticsModel(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
        summary: json['summary'] != null
            ? Summary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
        statistics: json['statistics'] != null
            ? Statistics.fromJson(json['statistics'] as Map<String, dynamic>)
            : null,
        breakdown:
            (json['breakdown'] as List?)
                ?.map(
                  (item) =>
                      BreakdownItem.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            [],
        chartData: json['chart_data'] != null
            ? ChartData.fromJson(json['chart_data'] as Map<String, dynamic>)
            : null,
        timeline:
            (json['timeline'] as List?)
                ?.map(
                  (item) => TimelineItem.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            [],
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'EarningsAnalyticsModel',
        method: 'fromJson',
        feature: 'Core',
        status: 'ERROR',
        params: {'success': json['success']?.toString()},
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'error': error,
      'summary': summary?.toJson(),
      'statistics': statistics?.toJson(),
      'breakdown': breakdown.map((item) => item.toJson()).toList(),
      'chart_data': chartData?.toJson(),
      'timeline': timeline.map((item) => item.toJson()).toList(),
    };
  }
}

class Summary {
  final double totalEarningsUsd;
  final int totalEarningsKsp;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String period;

  const Summary({
    required this.totalEarningsUsd,
    required this.totalEarningsKsp,
    required this.periodStart,
    required this.periodEnd,
    required this.period,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      totalEarningsUsd: (json['total_earnings_usd'] as num?)?.toDouble() ?? 0.0,
      totalEarningsKsp: (json['total_earnings_ksp'] as num?)?.toInt() ?? 0,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      period: json['period'] as String? ?? 'today',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_earnings_usd': totalEarningsUsd,
      'total_earnings_ksp': totalEarningsKsp,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'period': period,
    };
  }
}

class Statistics {
  final double totalEarningsUsd;
  final int totalEarningsKsp;
  final double todayEarningsUsd;
  final int todayEarningsKsp;
  final double last24hEarningsUsd;
  final int last24hEarningsKsp;
  final double highestDailyEarningsUsd;
  final DateTime? highestEarningsDate;
  final double averageDailyEarningsUsd;
  final int daysInPeriod;

  const Statistics({
    required this.totalEarningsUsd,
    required this.totalEarningsKsp,
    required this.todayEarningsUsd,
    required this.todayEarningsKsp,
    required this.last24hEarningsUsd,
    required this.last24hEarningsKsp,
    required this.highestDailyEarningsUsd,
    this.highestEarningsDate,
    required this.averageDailyEarningsUsd,
    required this.daysInPeriod,
  });

  factory Statistics.fromJson(Map<String, dynamic> json) {
    return Statistics(
      totalEarningsUsd: (json['total_earnings_usd'] as num?)?.toDouble() ?? 0.0,
      totalEarningsKsp: (json['total_earnings_ksp'] as num?)?.toInt() ?? 0,
      todayEarningsUsd: (json['today_earnings_usd'] as num?)?.toDouble() ?? 0.0,
      todayEarningsKsp: (json['today_earnings_ksp'] as num?)?.toInt() ?? 0,
      last24hEarningsUsd:
          (json['last_24h_earnings_usd'] as num?)?.toDouble() ?? 0.0,
      last24hEarningsKsp: (json['last_24h_earnings_ksp'] as num?)?.toInt() ?? 0,
      highestDailyEarningsUsd:
          (json['highest_daily_earnings_usd'] as num?)?.toDouble() ?? 0.0,
      highestEarningsDate: json['highest_earnings_date'] != null
          ? DateTime.parse(json['highest_earnings_date'] as String)
          : null,
      averageDailyEarningsUsd:
          (json['average_daily_earnings_usd'] as num?)?.toDouble() ?? 0.0,
      daysInPeriod: (json['days_in_period'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_earnings_usd': totalEarningsUsd,
      'total_earnings_ksp': totalEarningsKsp,
      'today_earnings_usd': todayEarningsUsd,
      'today_earnings_ksp': todayEarningsKsp,
      'last_24h_earnings_usd': last24hEarningsUsd,
      'last_24h_earnings_ksp': last24hEarningsKsp,
      'highest_daily_earnings_usd': highestDailyEarningsUsd,
      'highest_earnings_date': highestEarningsDate?.toIso8601String(),
      'average_daily_earnings_usd': averageDailyEarningsUsd,
      'days_in_period': daysInPeriod,
    };
  }
}

class BreakdownItem {
  final String
  source; // Stable key: investments, lucky_wheel, referral_rewards, etc.
  final double amountUsd;
  final int? amountKsp;
  final double percentage;

  const BreakdownItem({
    required this.source,
    required this.amountUsd,
    this.amountKsp,
    required this.percentage,
  });

  factory BreakdownItem.fromJson(Map<String, dynamic> json) {
    return BreakdownItem(
      source: json['source'] as String,
      amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0.0,
      amountKsp: (json['amount_ksp'] as num?)?.toInt(),
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'amount_usd': amountUsd,
      'amount_ksp': amountKsp,
      'percentage': percentage,
    };
  }

  /// Get localized source name
  String getLocalizedSource() {
    switch (source) {
      case 'investments':
        return 'investments'.tr;
      case 'lucky_wheel':
        return 'lucky_wheel'.tr;
      case 'referral_rewards':
        return 'referral_rewards'.tr;
      case 'registration_bonuses':
        return 'registration_bonuses'.tr;
      case 'other_rewards':
        return 'other_rewards'.tr;
      case 'investment_returns':
        return 'investment_returns'.tr;
      default:
        return source;
    }
  }

  /// Get total USD equivalent (including KSP conversion)
  double getTotalUsdEquivalent() {
    if (amountKsp != null && amountKsp! > 0) {
      // KSP conversion: 1 KSP = 0.001 USD
      return amountUsd + (amountKsp! * 0.001);
    }
    return amountUsd;
  }
}

class ChartData {
  final List<TrendChartItem> trendChart;

  const ChartData({required this.trendChart});

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      trendChart:
          (json['trend_chart'] as List?)
              ?.map(
                (item) => TrendChartItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'trend_chart': trendChart.map((item) => item.toJson()).toList()};
  }
}

class TrendChartItem {
  final DateTime date;
  final double amountUsd;

  const TrendChartItem({required this.date, required this.amountUsd});

  factory TrendChartItem.fromJson(Map<String, dynamic> json) {
    return TrendChartItem(
      date: DateTime.parse(json['date'] as String),
      amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'amount_usd': amountUsd};
  }
}

class TimelineItem {
  final String id;
  final String source;
  final double amountUsd;
  final int? amountKsp;
  final String description;
  final DateTime createdAt;

  const TimelineItem({
    required this.id,
    required this.source,
    required this.amountUsd,
    this.amountKsp,
    required this.description,
    required this.createdAt,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      id: json['id'] as String,
      source: json['source'] as String,
      amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0.0,
      amountKsp: (json['amount_ksp'] as num?)?.toInt(),
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'amount_usd': amountUsd,
      'amount_ksp': amountKsp,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get localized source name
  String getLocalizedSource() {
    switch (source) {
      case 'investments':
        return 'investments'.tr;
      case 'lucky_wheel':
        return 'lucky_wheel'.tr;
      case 'referral_rewards':
        return 'referral_rewards'.tr;
      case 'registration_bonuses':
        return 'registration_bonuses'.tr;
      case 'other_rewards':
        return 'other_rewards'.tr;
      case 'investment_returns':
        return 'investment_returns'.tr;
      default:
        return source;
    }
  }

  /// Get total USD equivalent (including KSP conversion)
  double getTotalUsdEquivalent() {
    if (amountKsp != null && amountKsp! > 0) {
      // KSP conversion: 1 KSP = 0.001 USD
      return amountUsd + (amountKsp! * 0.001);
    }
    return amountUsd;
  }
}
