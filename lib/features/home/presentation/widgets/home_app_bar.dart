import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/shell_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/tour/tour_target_keys.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeController = HomeController.to;

    return SliverAppBar(
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.darkGold.withValues(alpha: isDark ? 0.1 : 0.05),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      title: Row(
        children: [
          Semantics(
            button: true,
            label: 'personal_info'.tr,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ShellController.to.setIndex(ShellController.tabProfile);
              },
              child: Hero(
                tag: 'profile_avatar',
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.darkGold.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark
                        ? AppColors.surface
                        : AppColors.surfaceLight,
                    child: Obx(() {
                      final profile = homeController.profile.value;
                      final imageUrl = profile?.avatarUrl;
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        return ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: 36,
                            height: 36,
                            memCacheWidth: 72,
                            placeholder: (_, __) => Icon(
                              Icons.person_rounded,
                              color: AppColors.darkGold,
                              size: 20,
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              color: AppColors.darkGold,
                            ),
                          ),
                        );
                      }
                      return Icon(
                        Icons.person_rounded,
                        color: AppColors.darkGold,
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => Text(
                    'hi_name'.trParams({
                      'name': homeController.profileName.isEmpty
                          ? ''
                          : homeController.profileName,
                    }),
                    style: Get.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.softGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Obx(
                        () => Text(
                          'enum_tier_${homeController.accountTier}'.tr,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.search_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.9),
          ),
          tooltip: 'global_search'.tr,
          onPressed: () => Get.toNamed(Routes.globalSearch),
        ),
        // ── Premium Notification Bell ──
        Obx(() {
          final count = homeController.unreadNotificationCount.value;
          final semanticLabel = count > 0
              ? 'notifications_x_unread'.trParams({'count': '$count'})
              : 'notifications_no_unread'.tr;
          return KeyedSubtree(
            key: TourTargetKeys.notifications,
            child: Semantics(
              button: true,
              label: semanticLabel,
              excludeSemantics: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppColors.darkGold.withValues(alpha: 0.12)
                            : AppColors.darkGold.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppColors.darkGold.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkGold.withValues(
                              alpha: isDark ? 0.15 : 0.08,
                            ),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.darkGold,
                        size: 20,
                      ),
                    ),
                    tooltip: 'notifications'.tr,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Get.toNamed(Routes.notifications);
                    },
                  ),
                  // ── Dynamic Unread Badge ──
                  if (count > 0)
                    Positioned(
                      right: count > 9 ? 2 : 5,
                      top: 5,
                      child: IgnorePointer(
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.elasticOut,
                          child: Container(
                            key: ValueKey<int>(count),
                            padding: EdgeInsets.symmetric(
                              horizontal: count > 9 ? 4 : 0,
                              vertical: 1,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFEF4444),
                                  Color(0xFFDC2626),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF0E0E12)
                                    : Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
      ],
    );
  }
}
