import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/features/social/domain/models/friend_model.dart';
import 'package:kasby/features/social/presentation/controllers/social_network_controller.dart';
import 'package:kasby/features/social/presentation/widgets/social_avatar.dart';

/// WhatsApp/Telegram-inspired compact friend list tile.
class FriendCard extends StatelessWidget {
  const FriendCard({super.key, required this.friend, this.animationIndex = 0});

  final FriendModel friend;
  final int animationIndex;

  @override
  Widget build(BuildContext context) {
    final controller = SocialNetworkController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
          color: isDark ? AppColors.surface : Colors.white,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          borderRadius: KasbyRadius.cardR,
          child: InkWell(
            onTap: () => controller.openChat(friend),
            borderRadius: KasbyRadius.cardR,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KasbySpacing.md,
                vertical: KasbySpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                borderRadius: KasbyRadius.cardR,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SocialAvatar(
                    name: friend.fullName,
                    avatarUrl: friend.avatarUrl,
                    userId: friend.id,
                    lastSeenAt: friend.lastSeenAt,
                    radius: 24,
                  ),
                  const SizedBox(width: KasbySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark
                                ? Colors.white
                                : AppColors.onSurfaceLight,
                          ),
                        ),
                        if (friend.username != null)
                          Text(
                            '@${friend.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 2),
                        OnlineStatusIndicator(
                          userId: friend.id,
                          lastSeenAt: friend.lastSeenAt,
                        ),
                        if (friend.friendsSince != null)
                          Text(
                            '${'friends_since'.tr}: ${DateHelper.date(friend.friendsSince)}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _QuickActions(friend: friend, controller: controller),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 35 * animationIndex),
          duration: KasbyMotion.fast,
        )
        .slideX(begin: 0.03, duration: KasbyMotion.fast);
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.friend, required this.controller});

  final FriendModel friend;
  final SocialNetworkController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconAction(
          icon: Icons.chat_bubble_rounded,
          tooltip: 'chat'.tr,
          color: AppColors.darkGold,
          onTap: () => controller.openChat(friend),
        ),
        _IconAction(
          icon: Icons.swap_horiz_rounded,
          tooltip: 'transfer'.tr,
          color: AppColors.softGreen,
          onTap: () => controller.transferToFriend(friend),
        ),
        _IconAction(
          icon: Icons.more_vert_rounded,
          tooltip: 'more'.tr,
          color: AppColors.textSecondary,
          onTap: () => _showMenu(context),
        ),
      ],
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: KasbyRadius.sheetR),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.person_remove_rounded,
                color: AppColors.error,
              ),
              title: Text('remove_friend'.tr),
              onTap: () {
                Navigator.pop(context);
                controller.removeFriend(friend);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: color),
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
