import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// Cached profile avatar with placeholder, initials fallback, and optional online dot.
class KasbyProfileAvatar extends StatelessWidget {
  const KasbyProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 28,
    this.isOnline,
    this.showOnlineIndicator = false,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final bool? isOnline;
  final bool showOnlineIndicator;

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  Widget _placeholderContent() {
    final initials = _initials(name);
    if (initials != '?') {
      return Text(
        initials,
        style: TextStyle(
          color: AppColors.darkGold,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.58,
        ),
      );
    }
    return Icon(
      Icons.person_rounded,
      color: AppColors.darkGold,
      size: radius * 1.05,
    );
  }

  Widget _avatarBody() {
    final url = imageUrl?.trim();
    final diameter = radius * 2;

    if (url == null || url.isEmpty) {
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.darkGold.withValues(alpha: 0.22),
              AppColors.darkGold.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: AppColors.darkGold.withValues(alpha: 0.3),
          ),
        ),
        child: Center(child: _placeholderContent()),
      );
    }

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.darkGold.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: diameter,
        height: diameter,
        placeholder: (_, __) => Container(
          color: AppColors.darkGold.withValues(alpha: 0.08),
          child: Center(
            child: SizedBox(
              width: radius * 0.7,
              height: radius * 0.7,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.darkGold.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.darkGold.withValues(alpha: 0.12),
          child: Center(child: _placeholderContent()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _avatarBody(),
        if (showOnlineIndicator && isOnline != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isOnline! ? AppColors.softGreen : AppColors.textSecondary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
