import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/features/social/presentation/controllers/social_network_controller.dart';

class OnlineStatusIndicator extends StatelessWidget {
  const OnlineStatusIndicator({
    super.key,
    required this.userId,
    this.lastSeenAt,
    this.showLabel = true,
    this.avatarRadius = 26,
  });

  final String userId;
  final DateTime? lastSeenAt;
  final bool showLabel;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final controller = SocialNetworkController.to;
    return Obx(() {
      final online = controller.isUserOnline(userId);
      if (!showLabel) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: online ? AppColors.softGreen : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      }

      return Text(
        online ? 'online_now'.tr : '${'last_seen'.tr} ${DateHelper.lastSeenRelative(lastSeenAt)}',
        style: TextStyle(
          fontSize: 12,
          color: online ? AppColors.softGreen : AppColors.textSecondary,
        ),
      );
    });
  }
}

class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.userId,
    this.lastSeenAt,
    this.radius = 26,
  });

  final String name;
  final String? avatarUrl;
  final String? userId;
  final DateTime? lastSeenAt;
  final double radius;

  String _initials(String value) {
    final parts = value.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return value.isNotEmpty ? value[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
          backgroundImage:
              avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? Text(
                  _initials(name),
                  style: TextStyle(
                    color: AppColors.darkGold,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.6,
                  ),
                )
              : null,
        ),
        if (userId != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: OnlineStatusIndicator(
              userId: userId!,
              lastSeenAt: lastSeenAt,
              showLabel: false,
            ),
          ),
      ],
    );
  }
}
