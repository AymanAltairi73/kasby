import 'package:flutter/material.dart';

class TourStepModel {
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final Color color;
  final String? route;

  const TourStepModel({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.color,
    this.route,
  });
}
