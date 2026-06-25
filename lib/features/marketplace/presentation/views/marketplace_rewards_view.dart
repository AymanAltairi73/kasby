import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import '../../domain/models/marketplace_reward.dart';
import '../controllers/marketplace_rewards_controller.dart';

class MarketplaceRewardsView extends StatelessWidget {
  const MarketplaceRewardsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MarketplaceRewardsController());
    final locale = Get.locale?.languageCode ?? 'en';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('marketplace_rewards'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return ListView.builder(
            padding: const EdgeInsets.all(KasbySpacing.md),
            itemCount: 4,
            itemBuilder: (_, __) => KasbyShimmer.listItem(height: 100),
          );
        }
        return RefreshIndicator(
          color: AppColors.darkGold,
          onRefresh: controller.loadRewards,
          child: ListView.builder(
            padding: const EdgeInsets.all(KasbySpacing.md),
            itemCount: controller.rewards.length,
            itemBuilder: (_, i) {
              final reward = controller.rewards[i];
              return _RewardCard(
                reward: reward,
                locale: locale,
                isClaiming: controller.claimingId.value == reward.id,
                onClaim: reward.isClaimed || !reward.isAvailable
                    ? null
                    : () => controller.claim(reward.id),
              );
            },
          ),
        );
      }),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final MarketplaceReward reward;
  final String locale;
  final bool isClaiming;
  final VoidCallback? onClaim;

  const _RewardCard({
    required this.reward,
    required this.locale,
    required this.isClaiming,
    this.onClaim,
  });

  IconData _iconFor(MarketplaceRewardType type) {
    switch (type) {
      case MarketplaceRewardType.daily:
        return Icons.calendar_today_rounded;
      case MarketplaceRewardType.promotional:
        return Icons.card_giftcard_rounded;
      case MarketplaceRewardType.marketplaceBonus:
        return Icons.storefront_rounded;
      case MarketplaceRewardType.ksp:
        return Icons.diamond_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: KasbySpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(KasbySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
                  child: Icon(_iconFor(reward.type), color: AppColors.darkGold),
                ),
                const SizedBox(width: KasbySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.localizedTitle(locale),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        reward.localizedDescription(locale),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reward.kspAmount != null || reward.walletAmount != null) ...[
              const SizedBox(height: KasbySpacing.sm),
              Text(
                reward.kspAmount != null
                    ? '+${reward.kspAmount!.toStringAsFixed(0)} KSP'
                    : '+\$${reward.walletAmount!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.darkGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
            const SizedBox(height: KasbySpacing.md),
            KasbyButton(
              text: reward.isClaimed
                  ? 'marketplace_claimed'.tr
                  : 'marketplace_claim'.tr,
              width: double.infinity,
              isLoading: isClaiming,
              isSecondary: reward.isClaimed,
              onPressed: onClaim,
            ),
          ],
        ),
      ),
    );
  }
}
