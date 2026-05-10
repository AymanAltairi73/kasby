import 'package:flutter/material.dart';

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
    return SpinReward(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      points: json['points'] ?? 0,
      iconName: json['icon'] ?? 'stars_rounded',
      colorHex: json['color'] ?? '#FFFFFF',
      weight: json['weight'] ?? 1,
      isActive: json['is_active'] ?? true,
    );
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

  static List<SpinReward> get defaultRewards => [
    SpinReward(id: '1', label: '10', points: 10, iconName: 'stars_rounded', colorHex: '#FFC107', weight: 1, isActive: true),
    SpinReward(id: '2', label: '50', points: 50, iconName: 'stars_rounded', colorHex: '#FFC107', weight: 1, isActive: true),
    SpinReward(id: '3', label: '100', points: 100, iconName: 'monetization_on_rounded', colorHex: '#FFC107', weight: 1, isActive: true),
    SpinReward(id: '4', label: '250', points: 250, iconName: 'monetization_on_rounded', colorHex: '#FFC107', weight: 1, isActive: true),
    SpinReward(id: '5', label: '500', points: 500, iconName: 'diamond_rounded', colorHex: '#FFC107', weight: 1, isActive: true),
    SpinReward(id: '6', label: 'bonus', points: 1000, iconName: 'card_giftcard_rounded', colorHex: '#FFC107', weight: 1, isActive: true),
  ];
}
