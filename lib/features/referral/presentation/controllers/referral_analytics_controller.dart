import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class ReferralAnalyticsController extends GetxController {
  static ReferralAnalyticsController get to => Get.find();

  final teamMembers = <Map<String, dynamic>>[].obs;
  final referralEarnings = 0.0.obs;
  final dailyReferrals = 0.obs;
  final monthlyReferrals = 0.obs;
  final totalReferrals = 0.obs;
  final activeMembers = 0.obs;
  final inactiveMembers = 0.obs;
  final conversionRate = 0.0.obs;
  final earningsHistory = <double>[].obs;
  final teamGrowthHistory = <double>[].obs;
  final topReferrals = <Map<String, dynamic>>[].obs;
  final selectedPeriod = '30d'.obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  final _rawEarnings = <Map<String, dynamic>>[];

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  Future<void> fetchAll() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      await Future.wait([fetchTeamMembers(), fetchReferralEarnings()]);
      computeMetrics();
    } catch (e) {
      hasError.value = true;
      SafeGetx.debugTrace(
        className: 'ReferralAnalyticsController',
        method: 'fetchAll',
        feature: 'Referral',
        status: 'ERROR',
        error: e,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchTeamMembers() async {
    await SafeGetx.traceAsync(
      className: 'ReferralAnalyticsController',
      method: 'fetchTeamMembers',
      feature: 'Referral',
      operation: () async {
        if (!SupabaseService.isLoggedIn) return;

        try {
          final response = await SupabaseService.client.rpc('get_my_team');
          if (response is Map && response['success'] == true) {
            final members = List<Map<String, dynamic>>.from(
              response['tree'] ?? response['members'] ?? [],
            );
            teamMembers.assignAll(
              members.where((m) => (m['level'] as int? ?? 1) == 1),
            );
          }
        } catch (e) {
          SafeGetx.debugTrace(
            className: 'ReferralAnalyticsController',
            method: 'fetchTeamMembers',
            feature: 'Referral',
            status: 'ERROR',
            error: e,
          );
          teamMembers.clear();
        }
      },
    );
  }

  Future<void> fetchReferralEarnings() async {
    await SafeGetx.traceAsync(
      className: 'ReferralAnalyticsController',
      method: 'fetchReferralEarnings',
      feature: 'Referral',
      operation: () async {
        if (!SupabaseService.isLoggedIn) return;

        try {
          final earnings = await ReferralService.fetchMyReferralEarnings();
          referralEarnings.value =
              await ReferralService.fetchTotalReferralEarnings();

          double cumulative = 0.0;
          final history = <double>[];
          for (final row in earnings) {
            cumulative += (row['commission_amount'] as num?)?.toDouble() ?? 0.0;
            history.add(cumulative);
          }
          earningsHistory.assignAll(history);
          _rawEarnings.assignAll(earnings);
        } catch (_) {
          // Fall back to transactions query
          try {
            final userId = SupabaseService.userId!;
            final response = await SupabaseService.client
                .from('transactions')
                .select('amount, created_at')
                .eq('user_id', userId)
                .eq('type', 'reward')
                .order('created_at', ascending: true);

            final list = (response as List).cast<Map<String, dynamic>>();

            double total = 0.0;
            final history = <double>[];
            for (final row in list) {
              final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
              total += amount;
              history.add(total);
            }

            referralEarnings.value = total;
            earningsHistory.assignAll(history);
            _rawEarnings.clear();
          } catch (e) {
            SafeGetx.debugTrace(
              className: 'ReferralAnalyticsController',
              method: 'fetchReferralEarnings',
              feature: 'Referral',
              status: 'ERROR',
              error: e,
            );
            referralEarnings.value = 0.0;
            earningsHistory.clear();
            _rawEarnings.clear();
          }
        }
      },
    );
  }

  Duration _periodRange() {
    switch (selectedPeriod.value) {
      case '7d':
        return const Duration(days: 7);
      case '30d':
        return const Duration(days: 30);
      case '90d':
        return const Duration(days: 90);
      case '1y':
        return const Duration(days: 365);
      default:
        return const Duration(days: 30);
    }
  }

  void computeMetrics() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final cutoff = now.subtract(_periodRange());

    final periodMembers = teamMembers.where((m) {
      final createdAt = DateTime.tryParse(m['created_at'] ?? '');
      return createdAt != null && createdAt.isAfter(cutoff);
    }).toList();

    int daily = 0;
    int monthly = 0;
    int active = 0;
    int inactive = 0;
    final growthData = <double>[];

    for (int i = 0; i < periodMembers.length; i++) {
      final member = periodMembers[i];
      final createdAt = DateTime.tryParse(member['created_at'] ?? '');
      final status = member['status']?.toString().toLowerCase() ?? '';

      if (createdAt != null) {
        if (createdAt.isAfter(todayStart)) daily++;
        if (createdAt.isAfter(monthStart)) monthly++;
      }

      if (status == 'active') {
        active++;
      } else {
        inactive++;
      }

      growthData.add((i + 1).toDouble());
    }

    dailyReferrals.value = daily;
    monthlyReferrals.value = monthly;
    totalReferrals.value = periodMembers.length;
    activeMembers.value = active;
    inactiveMembers.value = inactive;
    teamGrowthHistory.assignAll(growthData);

    if (periodMembers.isNotEmpty) {
      conversionRate.value = (active / periodMembers.length) * 100;
    } else {
      conversionRate.value = 0.0;
    }

    // Filter earnings by period
    if (_rawEarnings.isNotEmpty) {
      double periodTotal = 0.0;
      final history = <double>[];
      for (final row in _rawEarnings) {
        final createdAt = DateTime.tryParse(row['created_at'] ?? '');
        if (createdAt != null && createdAt.isAfter(cutoff)) {
          periodTotal += (row['commission_amount'] as num?)?.toDouble() ?? 0.0;
          history.add(periodTotal);
        }
      }
      referralEarnings.value = periodTotal;
      earningsHistory.assignAll(history);
    }

    _buildTopReferrals(periodMembers);
  }

  void _buildTopReferrals(List<Map<String, dynamic>> members) {
    final sorted = List<Map<String, dynamic>>.from(members);
    sorted.sort((a, b) {
      final aStatus = a['status']?.toString().toLowerCase() == 'active' ? 1 : 0;
      final bStatus = b['status']?.toString().toLowerCase() == 'active' ? 1 : 0;
      return bStatus.compareTo(aStatus);
    });
    topReferrals.assignAll(sorted.take(5).toList());
  }

  void changePeriod(String period) {
    selectedPeriod.value = period;
    computeMetrics();
  }
}
