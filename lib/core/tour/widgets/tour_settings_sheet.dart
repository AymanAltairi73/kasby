import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/tour_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/tour/tour_controller.dart';
import 'package:kasby/core/tour/tour_ids.dart';

/// Settings sheet to replay or reset product tours.
class TourSettingsSheet extends StatelessWidget {
  const TourSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TourSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'tour_settings_title'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'tour_settings_desc'.tr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...TourId.values.map(
            (id) => ListTile(
              leading: Icon(Icons.play_lesson_outlined, color: AppColors.darkGold),
              title: Text(id.labelKey.tr),
              trailing: const Icon(Icons.replay_rounded, size: 20),
              onTap: () {
                Navigator.pop(context);
                TourController.to.dismissActiveTour();
                TourController.to.replayTour(context, id);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.restart_alt_rounded, color: AppColors.darkGold),
            title: Text('tour_reset_all'.tr),
            onTap: () async {
              await TourController.to.resetAllTours();
              await TourService.setPermanentlySkipped(false);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.block_rounded, color: AppColors.error),
            title: Text('tour_skip_forever'.tr),
            onTap: () async {
              await TourService.setPermanentlySkipped(true);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
