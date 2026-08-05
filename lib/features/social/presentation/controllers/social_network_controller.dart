import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/presence_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/social/domain/models/friend_model.dart';
import 'package:kasby/features/social/domain/models/friend_request_model.dart';
import 'package:kasby/features/social/domain/models/social_dashboard_stats.dart';
import 'package:kasby/features/social/domain/models/social_user_model.dart';
import 'package:kasby/features/social/domain/repositories/social_repository.dart';
import 'package:kasby/routes/app_routes.dart';

class SocialNetworkController extends GetxController {
  static SocialNetworkController get to => Get.find<SocialNetworkController>();

  final SocialRepository _repo = SocialRepository();

  final incomingRequests = <FriendRequestModel>[].obs;
  final outgoingRequests = <FriendRequestModel>[].obs;
  final friends = <FriendModel>[].obs;
  final suggestions = <SocialUserModel>[].obs;
  final searchResults = <SocialUserModel>[].obs;
  final dashboardStats = const SocialDashboardStats().obs;

  final isLoading = true.obs;
  final isSearching = false.obs;
  final searchQuery = ''.obs;
  final processingIds = <String>{}.obs;
  final sentRequestIds = <String>{}.obs;

  StreamSubscription<List<Map<String, dynamic>>>? _requestsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _friendshipsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    _listenRealtime();
    if (Get.isRegistered<PresenceService>()) {
      ever(
        Get.find<PresenceService>().onlineUsers,
        (_) => _updateOnlineCount(),
      );
    }
  }

  @override
  void onClose() {
    _requestsSub?.cancel();
    _friendshipsSub?.cancel();
    _notificationsSub?.cancel();
    super.onClose();
  }

  void _listenRealtime() {
    if (!SupabaseService.isLoggedIn) return;
    final userId = SupabaseService.userId!;

    _requestsSub = SupabaseService.client
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .listen((_) => _refreshRequestsAndStats());

    _friendshipsSub = SupabaseService.client
        .from('friendships')
        .stream(primaryKey: ['id'])
        .listen((_) => _refreshFriendsAndStats());

    _notificationsSub = SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => fetchDashboardStats());
  }

  Future<void> _refreshRequestsAndStats() async {
    await Future.wait([
      fetchIncomingRequests(),
      fetchOutgoingRequests(),
      fetchDashboardStats(),
    ]);
  }

  Future<void> _refreshFriendsAndStats() async {
    await Future.wait([
      fetchFriends(),
      fetchSuggestions(),
      fetchDashboardStats(),
    ]);
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchIncomingRequests(),
        fetchOutgoingRequests(),
        fetchFriends(),
        fetchSuggestions(),
        fetchDashboardStats(),
      ]);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SocialNetworkController',
        method: 'refreshAll',
        feature: 'Social',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchIncomingRequests() async {
    incomingRequests.assignAll(await _repo.getIncomingRequests());
    _syncSentIdsFromOutgoing();
  }

  Future<void> fetchOutgoingRequests() async {
    outgoingRequests.assignAll(await _repo.getOutgoingRequests());
    _syncSentIdsFromOutgoing();
  }

  void _syncSentIdsFromOutgoing() {
    sentRequestIds
      ..clear()
      ..addAll(outgoingRequests.map((r) => r.userId));
  }

  Future<void> fetchFriends() async {
    friends.assignAll(await _repo.getFriends());
    _updateOnlineCount();
  }

  Future<void> fetchSuggestions() async {
    suggestions.assignAll(await _repo.getSuggestions());
  }

  Future<void> fetchDashboardStats() async {
    final stats = await _repo.getDashboardStats();
    dashboardStats.value = stats.copyWith(onlineFriends: _countOnlineFriends());
  }

  void _updateOnlineCount() {
    dashboardStats.value = dashboardStats.value.copyWith(
      onlineFriends: _countOnlineFriends(),
    );
  }

  int _countOnlineFriends() {
    if (!Get.isRegistered<PresenceService>()) return 0;
    final presence = Get.find<PresenceService>();
    return friends.where((f) => presence.isUserOnline(f.id)).length;
  }

  bool isUserOnline(String userId) {
    if (!Get.isRegistered<PresenceService>()) return false;
    return Get.find<PresenceService>().isUserOnline(userId);
  }

  Future<void> searchUsers(String query) async {
    searchQuery.value = query;
    if (query.trim().length < 2) {
      searchResults.clear();
      return;
    }
    isSearching.value = true;
    try {
      final result = await _repo.searchUsers(query: query.trim());
      searchResults.assignAll(result.users);
    } finally {
      isSearching.value = false;
    }
  }

  String mapError(String? code) {
    switch (code) {
      case 'rate_limit_exceeded':
      case 'abuse_rate_limit':
        return 'abuse_rate_limit_friend'.tr;
      case 'request_too_fast':
        return 'request_too_fast'.tr;
      case 'request_already_pending':
        return 'request_already_pending'.tr;
      case 'already_friends':
        return 'already_friends'.tr;
      case 'cannot_add_self':
        return 'cannot_add_self'.tr;
      case 'must_be_friends_to_chat':
        return 'error_not_friends_yet'.tr;
      case 'account_restricted':
        return 'account_restricted'.tr;
      default:
        return code ?? 'error'.tr;
    }
  }

  Future<void> sendFriendRequest(String receiverId) async {
    if (sentRequestIds.contains(receiverId)) return;
    sentRequestIds.add(receiverId);

    try {
      final response = await _repo.sendFriendRequest(receiverId);
      if (response['success'] == true) {
        HapticFeedback.lightImpact();
        AppSnack.success('success'.tr, 'friend_request_sent'.tr);

        if (response['auto_accepted'] == true) {
          await _refreshFriendsAndStats();
          suggestions.removeWhere((s) => s.id == receiverId);
          searchResults.removeWhere((s) => s.id == receiverId);
        } else {
          await fetchOutgoingRequests();
          final idx = suggestions.indexWhere((s) => s.id == receiverId);
          if (idx != -1) {
            suggestions[idx] = suggestions[idx].copyWith(requestSent: true);
          }
        }
      } else {
        sentRequestIds.remove(receiverId);
        AppSnack.error('error'.tr, mapError(response['error']?.toString()));
      }
    } catch (e) {
      sentRequestIds.remove(receiverId);
      SafeGetx.debugTrace(
        className: 'SocialNetworkController',
        method: 'sendFriendRequest',
        feature: 'Social',
        status: 'ERROR',
        error: e,
      );
    }
  }

  Future<void> acceptRequest(FriendRequestModel request) async {
    if (processingIds.contains(request.requestId)) return;
    processingIds.add(request.requestId);
    try {
      final response = await _repo.acceptRequest(request.requestId);
      if (response['success'] == true) {
        HapticFeedback.mediumImpact();
        incomingRequests.removeWhere((r) => r.requestId == request.requestId);
        await fetchFriends();
        await fetchDashboardStats();
        AppSnack.success('success'.tr, 'request_accepted'.tr);
      }
    } finally {
      processingIds.remove(request.requestId);
    }
  }

  Future<void> rejectRequest(FriendRequestModel request) async {
    if (processingIds.contains(request.requestId)) return;
    processingIds.add(request.requestId);
    try {
      final response = await _repo.rejectRequest(request.requestId);
      if (response['success'] == true) {
        incomingRequests.removeWhere((r) => r.requestId == request.requestId);
        await fetchDashboardStats();
        HapticFeedback.lightImpact();
        AppSnack.info('success'.tr, 'request_rejected'.tr);
      }
    } finally {
      processingIds.remove(request.requestId);
    }
  }

  Future<void> cancelRequest(FriendRequestModel request) async {
    if (processingIds.contains(request.userId)) return;
    processingIds.add(request.userId);
    try {
      final response = await _repo.cancelRequest(request.userId);
      if (response['success'] == true) {
        sentRequestIds.remove(request.userId);
        outgoingRequests.removeWhere((r) => r.userId == request.userId);
        await fetchDashboardStats();
        HapticFeedback.lightImpact();
        AppSnack.info('success'.tr, 'request_cancelled'.tr);
      }
    } finally {
      processingIds.remove(request.userId);
    }
  }

  Future<void> removeFriend(FriendModel friend) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('remove_friend'.tr),
        content: Text('confirm_remove_friend'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.safeBack(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.safeBack(result: true),
            child: Text(
              'remove_friend'.tr,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    processingIds.add(friend.id);
    try {
      final response = await _repo.removeFriend(friend.id);
      if (response['success'] == true) {
        friends.removeWhere((f) => f.id == friend.id);
        await fetchSuggestions();
        await fetchDashboardStats();
        HapticFeedback.mediumImpact();
        AppSnack.info('success'.tr, 'friend_removed'.tr);
      }
    } finally {
      processingIds.remove(friend.id);
    }
  }

  Future<void> openChat(FriendModel friend) async {
    final response = await _repo.startSocialChat(friend.id);
    if (response['success'] == true) {
      Get.toNamed(
        Routes.socialChat,
        arguments: {
          'friendId': friend.id,
          'friendName': friend.fullName,
          'conversation_id': response['conversation_id'],
        },
      );
    } else {
      AppSnack.error('error'.tr, mapError(response['error']?.toString()));
    }
  }

  Future<void> transferToFriend(FriendModel friend) async {
    Get.toNamed(
      Routes.transfer,
      arguments: {'receiver_id': friend.username ?? friend.id},
    );
  }
}
