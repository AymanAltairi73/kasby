import 'package:flutter/material.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class SpinReward {
  final String id;
  final String label;
  final int points;
  final String iconName;
  final String colorHex;
  final int weight;
  final bool isActive;

  SpinReward({
    required this.id,
    required this.label,
    required this.points,
    required this.iconName,
    required this.colorHex,
    required this.weight,
    required this.isActive,
  });

  factory SpinReward.fromJson(Map<String, dynamic> json) {
    try {
      return SpinReward(
        id: json['id']?.toString() ?? '',
        label: (json['label'] ?? '').toString(),
        points: (json['points'] as num?)?.toInt() ?? 0,
        iconName: json['icon']?.toString() ?? 'stars_rounded',
        colorHex: json['color']?.toString() ?? '#FFFFFF',
        weight: (json['weight'] as num?)?.toInt() ?? 1,
        isActive: json['is_active'] as bool? ?? true,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SpinReward',
        method: 'fromJson',
        feature: 'Core',
        status: 'ERROR',
        params: {'id': json['id']?.toString()},
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'points': points,
      'icon': iconName,
      'color': colorHex,
      'weight': weight,
      'is_active': isActive,
    };
  }

  /// Matches reference wheel: gift / bonus segment.
  bool get isGift {
    final l = label.toLowerCase().trim();
    return l == 'bonus' ||
        l == 'gift' ||
        l.contains('gift') ||
        iconName == 'card_giftcard_rounded';
  }

  /// Zero-point non-gift segment ("No Reward").
  bool get isNoReward => !isGift && (points == 0 || label == '0');

  /// Text painted on the wheel segment (numbers only, gift uses icon).
  String get wheelSegmentText {
    if (isGift) return '';
    if (isNoReward) return '0';
    final text = label.trim();
    if (text.isNotEmpty) return text;
    return points > 0 ? points.toString() : '0';
  }

  /// User-facing reward title after spin — uses granted points from server.
  String rewardTitle({required int grantedPoints}) {
    if (isGift) return 'gift_reward';
    if (grantedPoints <= 0 || isNoReward) return 'no_reward';
    return '$grantedPoints KSP';
  }

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.white;
  }

  IconData get icon {
    switch (iconName) {
      case 'stars_rounded':
        return Icons.stars_rounded;
      case 'monetization_on_rounded':
        return Icons.monetization_on_rounded;
      case 'diamond_rounded':
        return Icons.diamond_rounded;
      case 'auto_awesome_rounded':
        return Icons.auto_awesome_rounded;
      case 'sentiment_dissatisfied_rounded':
        return Icons.sentiment_dissatisfied_rounded;
      case 'card_giftcard_rounded':
        return Icons.card_giftcard_rounded;
      case 'bolt_rounded':
        return Icons.bolt_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  /// Canonical segment order matching reference design (clockwise from top-right).
  static const List<String> canonicalLabels = [
    '10',
    '25',
    '50',
    '100',
    '0',
    '5',
    '200',
    'gift',
  ];

  static int canonicalSortKey(SpinReward reward) {
    if (reward.isGift) return 7;
    final normalized = reward.label.trim();
    final idx = canonicalLabels.indexOf(normalized);
    if (idx >= 0) return idx;
    final byPoints = canonicalLabels.indexOf('${reward.points}');
    if (byPoints >= 0) return byPoints;
    return 99;
  }

  /// Ensures wheel segment order matches reference layout regardless of DB sort.
  static List<SpinReward> normalizeList(List<SpinReward> input) {
    if (input.isEmpty) return List<SpinReward>.from(defaultRewards);
    final sorted = List<SpinReward>.from(input)
      ..sort((a, b) => canonicalSortKey(a).compareTo(canonicalSortKey(b)));
    if (sorted.length >= 8) return sorted.take(8).toList();
    return List<SpinReward>.from(defaultRewards);
  }

  /// Validates that displayed segment values align with point grants.
  static String? validateIntegrity(List<SpinReward> rewards) {
    for (final r in rewards) {
      if (r.isGift) continue;
      if (r.isNoReward) continue;
      final parsed = int.tryParse(r.label.trim());
      if (parsed != null && parsed != r.points) {
        return 'Label ${r.label} != points ${r.points} (id: ${r.id})';
      }
    }
    return null;
  }

  static List<SpinReward> get defaultRewards => [
    SpinReward(
      id: 'default-1',
      label: '10',
      points: 10,
      iconName: 'stars_rounded',
      colorHex: '#C9A24D',
      weight: 1,
      isActive: true,
    ),
    SpinReward(
      id: 'default-2',
      label: '25',
      points: 25,
      iconName: 'stars_rounded',
      colorHex: '#0D0D0D',
      weight: 1,
      isActive: true,
    ),
    SpinReward(
      id: 'default-3',
      label: '50',
      points: 50,
      iconName: 'stars_rounded',
      colorHex: '#C9A24D',
      weight: 1,
      isActive: true,
    ),
    SpinReward(
      id: 'default-4',
      label: '100',
      points: 100,
      iconName: 'monetization_on_rounded',
      colorHex: '#0D0D0D',
      weight: 1,
      isActive: true,
    ),
    SpinReward(
      id: 'default-5',
      label: '0',
      points: 0,
      iconName: 'sentiment_dissatisfied_rounded',
      colorHex: '#C9A24D',
      weight: 1,
      isActive: true,
    ),
    SpinReward(
      id: 'default-6',
      label: '5',
      points: 5,
      iconName: 'stars_rounded',
      colorHex: '#0D0D0D',
      weight: 1,
      isActive: true,
    ),
    SpinReward(
      id: 'default-7',
      label: '200',
      points: 200,
      iconName: 'monetization_on_rounded',
      colorHex: '#C9A24D',
      weight: 1,
      isActive: true,
    ),
    SpinReward(
      id: 'default-8',
      label: 'gift',
      points: 500,
      iconName: 'card_giftcard_rounded',
      colorHex: '#0D0D0D',
      weight: 1,
      isActive: true,
    ),
  ];
}
