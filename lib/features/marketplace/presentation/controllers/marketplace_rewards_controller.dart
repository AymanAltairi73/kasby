import 'package:get/get.dart';
import '../../domain/models/marketplace_reward.dart';
import '../../domain/models/marketplace_notification.dart';
import '../../domain/repositories/marketplace_repository.dart';

class MarketplaceRewardsController extends GetxController {
  final MarketplaceRepository _repo;

  MarketplaceRewardsController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final rewards = <MarketplaceReward>[].obs;
  final isLoading = true.obs;
  final claimingId = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadRewards();
  }

  Future<void> loadRewards() async {
    isLoading.value = true;
    try {
      rewards.value = await _repo.getRewards();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> claim(String rewardId) async {
    claimingId.value = rewardId;
    try {
      final updated = await _repo.claimReward(rewardId);
      final idx = rewards.indexWhere((r) => r.id == rewardId);
      if (idx >= 0) rewards[idx] = updated;
    } finally {
      claimingId.value = null;
    }
  }
}

class MarketplaceNotificationsController extends GetxController {
  final MarketplaceRepository _repo;

  MarketplaceNotificationsController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final notifications = <MarketplaceNotification>[].obs;
  final isLoading = true.obs;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      notifications.value = await _repo.getNotifications();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markRead(String id) async {
    await _repo.markNotificationRead(id);
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      notifications[idx] = notifications[idx].copyWith(isRead: true);
    }
  }
}
