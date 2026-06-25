import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import '../../domain/models/marketplace_notification.dart';
import '../controllers/marketplace_rewards_controller.dart';

class MarketplaceNotificationsView extends StatelessWidget {
  const MarketplaceNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MarketplaceNotificationsController());
    final locale = Get.locale?.languageCode ?? 'en';
    final dateFmt = DateFormat.MMMd().add_Hm();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('marketplace_notifications'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return ListView.builder(
            padding: const EdgeInsets.all(KasbySpacing.md),
            itemCount: 5,
            itemBuilder: (_, __) => KasbyShimmer.listItem(height: 72),
          );
        }
        return RefreshIndicator(
          color: AppColors.darkGold,
          onRefresh: controller.loadNotifications,
          child: ListView.builder(
            padding: const EdgeInsets.all(KasbySpacing.md),
            itemCount: controller.notifications.length,
            itemBuilder: (_, i) {
              final n = controller.notifications[i];
              return _NotificationTile(
                notification: n,
                locale: locale,
                dateFmt: dateFmt,
                onTap: () => controller.markRead(n.id),
              );
            },
          ),
        );
      }),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final MarketplaceNotification notification;
  final String locale;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.locale,
    required this.dateFmt,
    required this.onTap,
  });

  IconData _iconFor(MarketplaceNotificationType type) {
    switch (type) {
      case MarketplaceNotificationType.orderCompleted:
        return Icons.check_circle_outline;
      case MarketplaceNotificationType.newProduct:
        return Icons.new_releases_outlined;
      case MarketplaceNotificationType.discountAvailable:
        return Icons.local_offer_outlined;
      case MarketplaceNotificationType.rewardEarned:
        return Icons.emoji_events_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
      color: notification.isRead
          ? null
          : AppColors.darkGold.withValues(alpha: 0.05),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
          child: Icon(_iconFor(notification.type), color: AppColors.darkGold),
        ),
        title: Text(
          notification.localizedTitle(locale),
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.localizedBody(locale)),
            const SizedBox(height: 4),
            Text(
              dateFmt.format(notification.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
