import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import '../../domain/models/marketplace_order.dart';
import '../../domain/models/marketplace_order_timeline.dart';

class MarketplaceOrderTimelineWidget extends StatelessWidget {
  final MarketplaceOrder order;

  const MarketplaceOrderTimelineWidget({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale?.languageCode ?? 'en';
    final events = MarketplaceOrderTimeline.build(order);

    return Column(
      children: events.asMap().entries.map((entry) {
        final i = entry.key;
        final event = entry.value;
        final isLast = i == events.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: event.isCompleted || event.isCurrent
                        ? AppColors.darkGold
                        : Colors.grey.shade300,
                  ),
                  child: Icon(
                    event.isCompleted ? Icons.check : Icons.circle,
                    size: event.isCompleted ? 14 : 8,
                    color: event.isCompleted || event.isCurrent ? Colors.white : Colors.grey,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: event.isCompleted
                        ? AppColors.darkGold.withValues(alpha: 0.5)
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: KasbySpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: KasbySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.localizedMessage(locale),
                      style: TextStyle(
                        fontWeight: event.isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: event.isCurrent ? AppColors.darkGold : null,
                      ),
                    ),
                    if (event.isCompleted || event.isCurrent)
                      Text(
                        '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
