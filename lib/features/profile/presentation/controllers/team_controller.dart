import 'dart:async';

import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class TeamController extends GetxController {
  static TeamController get to => Get.find<TeamController>();

  final isLoading = true.obs;
  final hasError = false.obs;
  final myReferralCode = ''.obs;
  final treeNodes = <Map<String, dynamic>>[].obs;
  final timelineItems = <Map<String, dynamic>>[].obs;
  final statistics = <String, dynamic>{}.obs;
  final analyticsData = <String, dynamic>{}.obs;

  final totalMembers = 0.obs;
  final activeMembers = 0.obs;
  final inactiveMembers = 0.obs;
  final newToday = 0.obs;

  StreamSubscription<List<Map<String, dynamic>>>? _activitySub;
  StreamSubscription<List<Map<String, dynamic>>>? _profilesSub;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    _listenRealtime();
  }

  @override
  void onClose() {
    _activitySub?.cancel();
    _profilesSub?.cancel();
    super.onClose();
  }

  void _listenRealtime() {
    if (!SupabaseService.isLoggedIn) return;
    final userId = SupabaseService.userId!;

    _activitySub = SupabaseService.client
        .from('referral_activity')
        .stream(primaryKey: ['id'])
        .eq('referrer_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .listen((_) => fetchTimeline());

    _profilesSub = SupabaseService.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('referred_by', userId)
        .listen((_) {
      fetchTeam();
      fetchStatistics();
    });
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      await Future.wait([
        fetchTeam(),
        fetchStatistics(),
        fetchTimeline(),
        fetchAnalytics(),
      ]);
    } catch (e) {
      hasError.value = true;
      SafeGetx.debugTrace(
        className: 'TeamController',
        method: 'refreshAll',
        feature: 'Team',
        status: 'ERROR',
        error: e,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchTeam() async {
    if (!SupabaseService.isLoggedIn) return;
    final result = await SupabaseService.client.rpc('get_my_team');
    if (result is! Map) return;
    final response = Map<String, dynamic>.from(result);
    if (response['success'] != true) {
      hasError.value = true;
      return;
    }
    myReferralCode.value = response['my_referral_code']?.toString() ?? '';
    totalMembers.value = response['total_members'] as int? ?? 0;
    activeMembers.value = response['active_members'] as int? ?? 0;
    inactiveMembers.value = response['inactive_members'] as int? ?? 0;
    newToday.value = response['new_today'] as int? ?? 0;
    treeNodes.assignAll(
      List<Map<String, dynamic>>.from(response['tree'] ?? []),
    );
  }

  Future<void> fetchStatistics() async {
    if (!SupabaseService.isLoggedIn) return;
    final result = await SupabaseService.client.rpc('get_team_statistics');
    if (result is Map) {
      statistics.assignAll(Map<String, dynamic>.from(result));
    }
  }

  Future<void> fetchTimeline() async {
    if (!SupabaseService.isLoggedIn) return;
    final result =
        await SupabaseService.client.rpc('get_referral_timeline', params: {
      'p_limit': 50,
    });
    if (result is Map && result['success'] == true) {
      timelineItems.assignAll(
        List<Map<String, dynamic>>.from(result['items'] ?? []),
      );
    }
  }

  Future<void> fetchAnalytics({int days = 30}) async {
    if (!SupabaseService.isLoggedIn) return;
    final result =
        await SupabaseService.client.rpc('get_referral_analytics', params: {
      'p_days': days,
    });
    if (result is Map) {
      analyticsData.assignAll(Map<String, dynamic>.from(result));
    }
  }
}
