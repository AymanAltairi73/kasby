import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/features/social/domain/models/social_dashboard_stats.dart';

class SocialDashboardHeader extends StatelessWidget {
  const SocialDashboardHeader({super.key, required this.stats});

  final SocialDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;

    Widget statTile(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: KasbySpacing.md,
            horizontal: KasbySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : Colors.white,
            borderRadius: KasbyRadius.cardR,
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: KasbySpacing.xs),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final rows = [
      [
        statTile(
          'total_friends'.tr,
          '${stats.totalFriends}',
          Icons.people_rounded,
          AppColors.darkGold,
        ),
        statTile(
          'online_friends'.tr,
          '${stats.onlineFriends}',
          Icons.circle,
          AppColors.softGreen,
        ),
        if (columns == 3)
          statTile(
            'pending_requests'.tr,
            '${stats.pendingIncoming}',
            Icons.inbox_rounded,
            AppColors.error,
          ),
      ],
      if (columns == 2) ...[
        [
          statTile(
            'pending_requests'.tr,
            '${stats.pendingIncoming}',
            Icons.inbox_rounded,
            AppColors.error,
          ),
          statTile(
            'sent_requests'.tr,
            '${stats.pendingOutgoing}',
            Icons.outbox_rounded,
            Colors.orange,
          ),
        ],
      ],
      [
        statTile(
          'new_friends_today'.tr,
          '${stats.newFriendsToday}',
          Icons.person_add_alt_1_rounded,
          Colors.blue,
        ),
        statTile(
          'messages_today'.tr,
          '${stats.messagesToday}',
          Icons.chat_rounded,
          Colors.purple,
        ),
        if (columns == 3)
          statTile(
            'sent_requests'.tr,
            '${stats.pendingOutgoing}',
            Icons.outbox_rounded,
            Colors.orange,
          ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'social_dashboard'.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
        const SizedBox(height: KasbySpacing.sm),
        for (final row in rows) ...[
          Row(
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: KasbySpacing.sm),
                row[i],
              ],
            ],
          ),
          const SizedBox(height: KasbySpacing.sm),
        ],
      ],
    );
  }
}
