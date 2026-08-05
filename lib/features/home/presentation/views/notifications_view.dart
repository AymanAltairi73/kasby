import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/localization/model_localization_extensions.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  // Local category filter (audit 3.7: information hierarchy).
  String _filter = 'all';

  static const Set<String> _financialEntities = {
    'transaction',
    'investment',
    'loan',
    'wallet',
    'deposit',
    'withdraw',
    'transfer',
    'ksp',
    'subscription',
  };
  static const Set<String> _socialEntities = {
    'friend',
    'friend_request',
    'chat',
    'message',
    'team',
    'referral',
  };

  String _categoryOf(NotificationModel n) {
    final e = (n.entityType ?? '').toLowerCase();
    if (_financialEntities.contains(e)) return 'financial';
    if (_socialEntities.contains(e)) return 'social';
    if (n.type == 'critical' || n.type == 'warning') return 'security';
    return 'system';
  }

  List<NotificationModel> _applyFilter(List<NotificationModel> all) {
    switch (_filter) {
      case 'unread':
        return all.where((n) => !n.isRead).toList();
      case 'all':
        return all;
      default:
        return all.where((n) => _categoryOf(n) == _filter).toList();
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'success':
        return AppColors.softGreen;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return AppColors.error;
      case 'info':
      default:
        return AppColors.darkGold;
    }
  }

  IconData _getTypeIcon(String type, bool isRead) {
    if (isRead) return Icons.notifications_none_rounded;
    switch (type) {
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'critical':
        return Icons.error_outline_rounded;
      case 'info':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeController = HomeController.to;

    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.safeBack(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'notification_settings'.tr,
            onPressed: () => Get.toNamed(Routes.notificationPreferences),
          ),
          Obx(() {
            if (homeController.unreadNotificationCount.value > 0) {
              return TextButton(
                onPressed: () => homeController.markAllAsRead(),
                child: Text(
                  'mark_all_read'.tr,
                  style: TextStyle(color: AppColors.darkGold),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => homeController.fetchNotifications(),
              color: AppColors.darkGold,
              child: Obx(() {
                if (homeController.isLoadingNotifications.value) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const KasbyShimmer.listItem(),
                  );
                }

                final notifications = _applyFilter(
                  homeController.notifications,
                );

                if (notifications.isEmpty) {
                  return _buildEmptyState(homeController);
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount:
                      notifications.length +
                      (homeController.notifications.length <
                              homeController.notificationTotalCount.value
                          ? 1
                          : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == notifications.length) {
                      homeController.loadMoreNotifications();
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final notification = notifications[index];
                    final isRead = notification.isRead;

                    return GestureDetector(
                      onTap: () {
                        if (!isRead) {
                          homeController.markNotificationRead(notification.id);
                        }
                        homeController.navigateFromNotification(notification);
                      },
                      child: KasbyCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    (isRead
                                            ? AppColors.textSecondary
                                            : _getTypeColor(notification.type))
                                        .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getTypeIcon(notification.type, isRead),
                                color: isRead
                                    ? AppColors.textSecondary
                                    : _getTypeColor(notification.type),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.localizedTitle,
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.localizedMessage,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (notification.sentAt != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      DateHelper.relative(notification.sentAt),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.darkGold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = <String, String>{
      'all': 'all'.tr,
      'unread': 'unread'.tr,
      'financial': 'financial'.tr,
      'security': 'security'.tr,
      'social': 'social'.tr,
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KasbySpacing.lg),
        children: filters.entries.map((e) {
          final selected = _filter == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: KasbySpacing.sm),
            child: ChoiceChip(
              label: Text(e.value),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.black : AppColors.textSecondary,
              ),
              selectedColor: AppColors.darkGold,
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: KasbyRadius.chipR),
              onSelected: (_) => setState(() => _filter = e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(HomeController homeController) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkGold.withValues(alpha: 0.08),
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: AppColors.darkGold.withValues(alpha: 0.5),
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 28),
              Text(
                'no_notifications'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              Text(
                'no_notifications_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => homeController.fetchNotifications(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('refresh'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGold,
                  side: BorderSide(
                    color: AppColors.darkGold.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
