import 'package:flutter/material.dart';

class SearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final String? route;
  final dynamic arguments;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    this.route,
    this.arguments,
  });
}

class SearchResults {
  final List<SearchResultItem> items;
  final int totalCount;
  final Map<String, int> categoryCounts;

  const SearchResults({
    required this.items,
    required this.totalCount,
    required this.categoryCounts,
  });

  static const empty = SearchResults(
    items: [],
    totalCount: 0,
    categoryCounts: {},
  );
}
