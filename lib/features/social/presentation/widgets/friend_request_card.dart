import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/features/social/domain/models/friend_request_model.dart';
import 'package:kasby/features/social/presentation/controllers/social_network_controller.dart';
import 'package:kasby/features/social/presentation/widgets/social_avatar.dart';

class FriendRequestCard extends StatelessWidget {
  const FriendRequestCard({
    super.key,
    required this.request,
    this.animationIndex = 0,
  });

  final FriendRequestModel request;
  final int animationIndex;

  @override
  Widget build(BuildContext context) {
    final controller = SocialNetworkController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isProcessing = controller.processingIds.contains(
      request.isOutgoing ? request.userId : request.requestId,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
      padding: const EdgeInsets.all(KasbySpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: KasbyRadius.cardR,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SocialAvatar(
            name: request.fullName,
            avatarUrl: request.avatarUrl,
            userId: request.userId,
            lastSeenAt: request.lastSeenAt,
            radius: 24,
          ),
          const SizedBox(width: KasbySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.onSurfaceLight,
                  ),
                ),
                if (request.username != null)
                  Text('@${request.username}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                OnlineStatusIndicator(
                    userId: request.userId, lastSeenAt: request.lastSeenAt),
                if (request.mutualFriends > 0)
                  Text(
                    'mutual_friends_count'
                        .trParams({'count': '${request.mutualFriends}'}),
                    style: TextStyle(color: AppColors.darkGold, fontSize: 11),
                  ),
                if (request.createdAt != null)
                  Text(
                    '${'request_date'.tr}: ${DateHelper.relative(request.createdAt)}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (isProcessing)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkGold),
            )
          else if (request.isOutgoing)
            TextButton(
              onPressed: () => controller.cancelRequest(request),
              child: Text('cancel'.tr, style: TextStyle(color: AppColors.error, fontSize: 12)),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircleAction(
                  icon: Icons.check_rounded,
                  color: AppColors.softGreen,
                  onTap: () => controller.acceptRequest(request),
                ),
                const SizedBox(width: KasbySpacing.sm),
                _CircleAction(
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  onTap: () => controller.rejectRequest(request),
                ),
              ],
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * animationIndex),
          duration: KasbyMotion.fast,
        )
        .slideX(begin: 0.03, duration: KasbyMotion.fast);
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(KasbySpacing.sm),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
