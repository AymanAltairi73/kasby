import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/ksp_balance_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class DailyCheckInView extends StatefulWidget {
  const DailyCheckInView({super.key});

  @override
  State<DailyCheckInView> createState() => _DailyCheckInViewState();
}

class _DailyCheckInViewState extends State<DailyCheckInView> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;
  bool _isCheckingIn = false;
  int _currentStreak = 0;
  bool _canCheckIn = true;
  DateTime? _nextCheckInAt;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'DailyCheckInView',
      method: 'initState',
      feature: 'Home',
      status: 'INFO',
    );
    _fetchCheckInStatus();
    _fetchCheckInHistory();
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'DailyCheckInView',
      method: 'dispose',
      feature: 'Home',
      status: 'INFO',
    );
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Fetch check-in status from the SERVER (not local time).
  Future<void> _fetchCheckInStatus() async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await SupabaseService.client.rpc('get_check_in_status');
      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        final canCheckIn = response['can_check_in'] as bool? ?? true;
        final streak = response['current_streak'] as int? ?? 0;
        final nextCheckInStr = response['next_check_in_at'] as String?;

        setState(() {
          _canCheckIn = canCheckIn;
          _currentStreak = streak;
        });

        if (!canCheckIn && nextCheckInStr != null) {
          _nextCheckInAt = DateTime.parse(nextCheckInStr).toLocal();
          _startCountdown();
          // Schedule smart notifications only if check-in is NOT done yet
          // nextCheckInAt = when the CURRENT cooldown expires (user CAN do check-in again)
          // The notifications should fire BEFORE the next 24h window closes
          // i.e., 24h after _nextCheckInAt
          final windowClose = _nextCheckInAt!.add(const Duration(hours: 24));
          FCMService.to.scheduleCheckInReminders(windowClose);
        }
      }
      SafeGetx.debugTrace(
        className: 'DailyCheckInView',
        method: '_fetchCheckInStatus',
        feature: 'Home',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'canCheckIn': _canCheckIn, 'streak': _currentStreak},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'DailyCheckInView',
        method: '_fetchCheckInStatus',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _fetchCheckInHistory() async {
    final stopwatch = Stopwatch()..start();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from('daily_check_ins')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(14);

      final list = List<Map<String, dynamic>>.from(response as List);

      setState(() {
        _history = list;
      });
      SafeGetx.debugTrace(
        className: 'DailyCheckInView',
        method: '_fetchCheckInHistory',
        feature: 'Home',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'count': _history.length},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'DailyCheckInView',
        method: '_fetchCheckInHistory',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextCheckInAt == null || !mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final diff = _nextCheckInAt!.difference(now);

      if (diff.isNegative) {
        timer.cancel();
        setState(() {
          _canCheckIn = true;
        });
        return;
      }

      setState(() {});
    });
  }

  Future<void> _handleCheckIn() async {
    if (!_canCheckIn || _isCheckingIn) return;
    setState(() => _isCheckingIn = true);
    final stopwatch = Stopwatch()..start();

    try {
      final result = await SupabaseService.client.rpc('daily_check_in');
      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        _currentStreak = response['streak'] as int? ?? _currentStreak + 1;
        final nextStr = response['next_check_in_at'] as String?;

        setState(() {
          _canCheckIn = false;
        });

        if (nextStr != null) {
          _nextCheckInAt = DateTime.parse(nextStr).toLocal();
          _startCountdown();
        }

        // Cancel reminder notifications since user checked in
        FCMService.to.cancelCheckInNotifications();

        await HomeController.to.fetchKspBalance();
        if (Get.isRegistered<KspBalanceService>()) {
          await KspBalanceService.to.afterFinancialMutation(response);
        }

        HapticFeedback.heavyImpact();

        Get.snackbar(
          'check_in_success'.tr,
          'bonus_points_msg'.trParams({'count': '${response['points'] ?? 10}'}),
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
          icon: const Icon(Icons.celebration_rounded, color: Colors.white),
          margin: const EdgeInsets.all(15),
          borderRadius: 15,
        );

        _fetchCheckInHistory();
        SafeGetx.debugTrace(
          className: 'DailyCheckInView',
          method: '_handleCheckIn',
          feature: 'Home',
          status: 'SUCCESS',
          durationMs: stopwatch.elapsedMilliseconds,
          params: {'streak': _currentStreak, 'points': response['points']},
        );
      } else {
        final error = response['error'] ?? '';
        SafeGetx.debugTrace(
          className: 'DailyCheckInView',
          method: '_handleCheckIn',
          feature: 'Home',
          status: 'WARN',
          durationMs: stopwatch.elapsedMilliseconds,
          message: error.toString(),
        );
        if (error == 'already_checked_in') {
          // Update from server response
          final nextStr = response['next_check_in_at'] as String?;
          if (nextStr != null) {
            _nextCheckInAt = DateTime.parse(nextStr).toLocal();
            _startCountdown();
          }
          setState(() => _canCheckIn = false);

          Get.snackbar(
            'daily_check_in'.tr,
            'checkin_done_today'.tr,
            backgroundColor: AppColors.darkGold.withValues(alpha: 0.8),
            colorText: Colors.black,
            icon: const Icon(Icons.check_circle, color: Colors.black),
          );
        } else {
          Get.snackbar(
            'error'.tr,
            error,
            backgroundColor: AppColors.error.withValues(alpha: 0.7),
            colorText: Colors.white,
          );
        }
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'DailyCheckInView',
        method: '_handleCheckIn',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      Get.snackbar(
        'error'.tr,
        'checkin_error'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('daily_check_in'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.darkGold),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStreakCard(),
                        const SizedBox(height: 24),
                        // ─── COUNTDOWN / STATUS CARD ─────────────────
                        _buildStatusCard(),
                        const SizedBox(height: 32),
                        Text(
                          'activity_log'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn(
                          delay: const Duration(milliseconds: 300),
                        ),
                        const SizedBox(height: 16),
                        if (_history.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text(
                                'no_checkin_history'.tr,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _history.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildHistoryItem(_history[index], index);
                            },
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
          // ─── BOTTOM ACTION AREA ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : const Color(0x0C0F172A),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: _isCheckingIn
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.darkGold,
                      ),
                    )
                  : _canCheckIn
                  ? KasbyButton(
                      text: 'check_in_today'.tr,
                      onPressed: _handleCheckIn,
                      icon: Icons.check_circle_outline_rounded,
                    ).animate().shimmer(duration: const Duration(seconds: 2))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.softGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'checkin_done_today'.tr,
                              style: TextStyle(
                                color: AppColors.softGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        KasbyButton(
                          text: 'checkin_done_today'.tr,
                          onPressed: null,
                          color: isDark
                              ? const Color(0xFF232328)
                              : AppColors.surfaceSecondaryLight,
                        ),
                      ],
                    ),
            ),
          ).animate().slideY(begin: 1.0, end: 0.0),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_canCheckIn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.softGreen.withValues(alpha: 0.15),
              AppColors.softGreen.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: AppColors.softGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.celebration_rounded,
              color: AppColors.softGreen,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'checkin_ready'.tr,
                style: TextStyle(
                  color: AppColors.softGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
    }

    // Cooldown state with countdown
    return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.surfaceSecondaryLight,
            border: Border.all(
              color: isDark
                  ? AppColors.darkGold.withValues(alpha: 0.2)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.timer_outlined, color: AppColors.darkGold, size: 36)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: const Duration(seconds: 1),
                  ),
              const SizedBox(height: 16),
              Text(
                'checkin_done_today'.tr,
                style: TextStyle(
                  color: AppColors.darkGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: const Duration(milliseconds: 200))
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildStreakCard() {
    return KasbyCard(
      color: isDark ? AppColors.surface : AppColors.surfaceLight,
      child: Column(
        children: [
          Text(
            'current_streak'.tr,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'days'.trParams({'count': '$_currentStreak'}),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              7,
              (index) => _buildDayItem(index + 1, index < _currentStreak),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildDayItem(int day, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.darkGold
                : (isDark
                      ? AppColors.surface
                      : const Color(0xFFEDF2F7)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted
                  ? AppColors.darkGold
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.star_border,
            color: isCompleted
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white38 : AppColors.textMutedLight),
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'day_x'.trParams({'count': '$day'}),
          style: TextStyle(
            fontSize: 10,
            color: isCompleted ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    final pointsAwarded = item['points_awarded'] as int? ?? 0;
    final bool isCompleted = pointsAwarded > 0;
    final DateTime? date = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'].toString())
        : null;
    final String currentLocale = Get.locale?.languageCode ?? 'en';

    if (date == null) return const SizedBox.shrink();

    // Date Formatting
    final String dateStr = DateFormat('dd MMM', currentLocale).format(date);
    final String dayName = DateFormat('EEEE', currentLocale).format(date);
    final String timeStr = DateFormat.jm(currentLocale).format(date);

    // Check if it's today or yesterday
    String displayDate = '$dayName, $dateStr';
    if (isSameDay(date, DateTime.now())) {
      displayDate = 'today'.tr;
    } else if (isSameDay(
      date,
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      displayDate = 'yesterday'.tr;
    }

    return KasbyCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.softGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.softGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'daily_login_reward'.tr,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+$pointsAwarded ${'points'.tr}',
                      style: TextStyle(
                        color: AppColors.darkGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (isCompleted) ...[
                  Divider(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    height: 24,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'checkin_streak_label'.trParams({
                          'count': '${item['streak'] ?? 1}',
                        }),
                        style: TextStyle(
                          color: AppColors.softGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 300 + (index * 100)))
        .slideX();
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
