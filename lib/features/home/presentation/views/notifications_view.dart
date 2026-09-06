import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/theme/kasby_typography.dart';
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
                    final category = _categoryOf(notification);
                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return GestureDetector(
                      onTap: () {
                        if (!isRead) {
                          homeController.markNotificationRead(notification.id);
                        }
                        homeController.navigateFromNotification(notification);
                      },
                      child: KasbyCard(
                        padding: const EdgeInsets.all(16),
                        borderRadius: KasbyRadius.card,
                        hasShadow: true,
                        border: Border.all(
                          color: !isRead
                              ? AppColors.darkGold.withValues(alpha: 0.4)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.borderLight),
                        ),
                        child: Container(
                          decoration: !isRead
                              ? BoxDecoration(
                                  borderRadius: KasbyRadius.cardR,
                                  color: AppColors.darkGold.withValues(
                                    alpha: isDark ? 0.05 : 0.03,
                                  ),
                                )
                              : null,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (isRead
                                              ? AppColors.textSecondary
                                              : _getTypeColor(notification.type))
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getTypeIcon(notification.type, isRead),
                                      color: isRead
                                          ? AppColors.textSecondary
                                          : _getTypeColor(notification.type),
                                      size: 22,
                                    ),
                                  ),
                                  if (!isRead)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: AppColors.darkGold,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? AppColors.surface
                                                : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notification.localizedTitle,
                                            style: TextStyle(
                                              fontSize: KasbyTypography.sp(ar: 15.0, en: 14.0, context: context),
                                              fontWeight: isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.onSurfaceLight,
                                            ),
                                          ),
                                        ),
                                        _buildTypeBadge(notification.type, category),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notification.localizedMessage,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.75)
                                            : AppColors.textSecondaryLight,
                                        fontSize: KasbyTypography.sp(ar: 13.0, en: 12.0, context: context),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (notification.sentAt != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateHelper.relative(notification.sentAt),
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: KasbyTypography.sp(ar: 11.0, en: 10.0, context: context),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (notification.entityType != null &&
                                            notification.entityType!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.darkGold.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _getLocalizedEntityLabel(notification.entityType!),
                                              style: TextStyle(
                                                fontSize: KasbyTypography.badge(context),
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.darkGold,
                                              ),
                                            ),
                                          ),
                                        if (notification.deepLink != null &&
                                            notification.deepLink!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.softGreen.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'action_view'.tr,
                                                  style: TextStyle(
                                                    fontSize: KasbyTypography.badge(context),
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.softGreen,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                Icon(
                                                  Icons.arrow_forward_ios_rounded,
                                                  size: 9,
                                                  color: AppColors.softGreen,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  String _getLocalizedEntityLabel(String entityType) {
    final key = entityType.toLowerCase().trim();
    switch (key) {
      case 'transaction':
        return 'transaction'.tr;
      case 'investment':
        return 'investment'.tr;
      case 'loan':
        return 'loan'.tr;
      case 'wallet':
        return 'wallet'.tr;
      case 'deposit':
        return 'deposit'.tr;
      case 'withdraw':
      case 'withdrawal':
        return 'withdraw'.tr;
      case 'transfer':
        return 'transfer'.tr;
      case 'ksp':
        return 'ksp'.tr;
      case 'subscription':
        return 'subscription'.tr;
      case 'friend':
      case 'friend_request':
        return 'friend'.tr;
      case 'chat':
      case 'message':
        return 'chat'.tr;
      case 'team':
        return 'team'.tr;
      case 'referral':
        return 'referral'.tr;
      default:
        return key.tr;
    }
  }

  Widget _buildTypeBadge(String type, String category) {
    Color badgeColor = _getTypeColor(type);
    String label = category.tr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: KasbyTypography.badge(context),
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = <String, String>{
      'all': 'filter_all'.tr,
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
                fontSize: KasbyTypography.sp(ar: 13.0, en: 12.0, context: context),
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
                  gradient: LinearGradient(
                    colors: [
                      AppColors.darkGold.withValues(alpha: 0.15),
                      AppColors.darkGold.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkGold.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 64,
                  color: AppColors.darkGold,
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 28),
              Text(
                'no_notifications'.tr,
                style: TextStyle(
                  fontSize: KasbyTypography.sectionHeader(context),
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              Text(
                'no_notifications_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: KasbyTypography.body(context),
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
                    color: AppColors.darkGold.withValues(alpha: 0.4),
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
