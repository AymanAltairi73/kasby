import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/tour/tour_feature_host.dart';
import 'package:kasby/core/tour/tour_ids.dart';
import 'package:kasby/core/tour/tour_target_keys.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kasby/core/services/ksp_balance_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/spin_reward_model.dart';
import 'dart:async';
import '../widgets/kasby_spin_wheel.dart';

class SpinWheelView extends StatefulWidget {
  const SpinWheelView({super.key});

  @override
  State<SpinWheelView> createState() => _SpinWheelViewState();
}

class _SpinWheelViewState extends State<SpinWheelView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late ConfettiController _confettiController;
  bool _isSpinning = false;
  int _selectedRewardIndex = 0;
  int _lastGrantedPoints = 0;
  int _storedSpins = 0;
  List<SpinReward> _dbRewards = SpinReward.defaultRewards;
  bool _showWinHighlight = false;
  double _highlightPulse = 0;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _lastFreeSpinAt;
  Timer? _countdownTimer;
  Timer? _highlightTimer;
  Timer? _tickTimer;
  String _timeUntilNextSpin = '';
  bool _isFreeSpinAvailable = false;

  // Hardcoded rewards removed - now using _dbRewards

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'SpinWheelView',
      method: 'initState',
      feature: 'Home',
      status: 'INFO',
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCirc,
    );
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _fetchInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TourFeatureHost.scheduleForRoute(context, TourId.luckyWheel);
    });
  }

  void _updateFreeSpinStatus() {
    if (_lastFreeSpinAt == null) {
      _isFreeSpinAvailable = true;
      _timeUntilNextSpin = '';
      return;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastFreeSpinAt!);
    if (difference.inHours >= 24) {
      _isFreeSpinAvailable = true;
      _timeUntilNextSpin = '';
    } else {
      _isFreeSpinAvailable = false;
      final remaining = const Duration(hours: 24) - difference;
      _timeUntilNextSpin = _formatDuration(remaining);
    }
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateFreeSpinStatus();
    });
  }

  Future<void> _fetchInitialData() async {
    final stopwatch = Stopwatch()..start();
    await Future.wait([
      KspBalanceService.to.refresh(),
      HomeController.to.fetchKspBalance(),
      _fetchRewards(),
      _fetchFreeSpinStatus(),
    ]);
    _startCountdownTimer();
    SafeGetx.debugTrace(
      className: 'SpinWheelView',
      method: '_fetchInitialData',
      feature: 'Home',
      status: 'SUCCESS',
      durationMs: stopwatch.elapsedMilliseconds,
      params: {
        'rewards': _dbRewards.length,
        'points': KspBalanceService.to.balance,
        'storedSpins': _storedSpins,
      },
    );
  }

  Future<void> _fetchFreeSpinStatus() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from('profiles')
          .select('last_free_spin_at, stored_spins')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        if (response['last_free_spin_at'] != null) {
          _lastFreeSpinAt = DateTime.parse(response['last_free_spin_at']);
        }
        _storedSpins = (response['stored_spins'] as num?)?.toInt() ?? 0;
      } else {
        // If never spun, set to long ago so free spin is available
        _lastFreeSpinAt = DateTime.now().subtract(const Duration(hours: 25));
      }
      _updateFreeSpinStatus();
    } catch (e) {
      debugPrint('Error fetching free spin status: $e');
    }
  }

  Future<void> _fetchRewards() async {
    try {
      final response = await SupabaseService.client
          .from('spin_wheel_rewards')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .order('id', ascending: true);

      if (mounted) {
        final fetched = (response as List)
            .map((r) => SpinReward.fromJson(r as Map<String, dynamic>))
            .toList();
        final normalized = SpinReward.normalizeList(fetched);
        final integrityError = SpinReward.validateIntegrity(normalized);
        if (integrityError != null) {
          debugPrint('Spin reward integrity warning: $integrityError');
        }
        setState(() {
          _dbRewards = normalized;
        });
      }
    } catch (e) {
      debugPrint('Error fetching rewards: $e');
      if (mounted) setState(() {});
    }
  }

  Widget _buildKspBalanceChip(int balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/ksp_coin.png', width: 18, height: 18),
          const SizedBox(width: 8),
          Text(
            '${'ksp_balance'.tr}: $balance KSP',
            style: const TextStyle(
              color: Color(0xFFC9A24D),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriesIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A24D).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9A24D).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFC9A24D), size: 20)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
          const SizedBox(width: 8),
          Text(
            _isFreeSpinAvailable
                ? 'free_spin_now'.tr
                : _storedSpins > 0
                ? 'use_stored_spin'.trParams({'count': _storedSpins.toString()})
                : 'next_free_spin'.trParams({'time': _timeUntilNextSpin}),
            style: const TextStyle(
              color: Color(0xFFC9A24D),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseBundle(String type, int cost) async {
    final balance = await KspBalanceService.to.refresh();
    await HomeController.to.fetchKspBalance();
    if (balance < cost) {
      Get.snackbar(
        'insufficient_points'.tr,
        'need_more_points'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    SafeGetx.dismissOverlayIfOpen();
    try {
      final response = await KspBalanceService.to.buySpinsBundle(type);
      if (response['success'] == true) {
        setState(() {
          _storedSpins =
              (response['stored_spins'] as num?)?.toInt() ?? _storedSpins;
        });
        await _fetchFreeSpinStatus();
        await KspBalanceService.to.afterFinancialMutation(
          Map<String, dynamic>.from(response),
        );
        if (Get.isRegistered<HomeController>()) {
          await HomeController.to.fetchKspBalance();
        }
        SafeGetx.debugTrace(
          className: 'SpinWheelView',
          method: '_purchaseBundle',
          feature: 'Home',
          status: 'SUCCESS',
          params: {'bundleType': type, 'storedSpins': _storedSpins},
        );
        Get.snackbar(
          'success'.tr,
          'bundle_purchased_successfully'.tr,
          backgroundColor: AppColors.softGreen.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'error'.tr,
          KspBalanceService.mapRpcError(response['error']?.toString()),
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SpinWheelView',
        method: '_purchaseBundle',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  void _handleSpinButtonPress() {
    if (_isSpinning || _dbRewards.isEmpty) return;

    if (_isFreeSpinAvailable || _storedSpins > 0) {
      _spin();
    } else {
      _showBuySpinsDialog();
    }
  }

  void _spin() async {
    if (_isSpinning || _dbRewards.isEmpty) return;

    setState(() {
      _isSpinning = true;
      _showWinHighlight = false;
      _highlightPulse = 0;
    });
    _highlightTimer?.cancel();
    final stopwatch = Stopwatch()..start();

    try {
      final response = await SupabaseService.client.rpc('spin_wheel');

      if (response['success'] == false) {
        setState(() => _isSpinning = false);
        Get.snackbar(
          'error'.tr,
          response['error']?.toString() ?? 'unknown_error'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
        return;
      }

      final rewardData = response['reward'] as Map<String, dynamic>;
      final rewardId = rewardData['id']?.toString();
      _lastGrantedPoints = (rewardData['points'] as num?)?.toInt() ?? 0;

      // Find the index of the reward in our list to stop the wheel correctly
      _selectedRewardIndex = _dbRewards.indexWhere((r) => r.id == rewardId);

      if (_selectedRewardIndex == -1) {
        // Fallback if reward not in list (shouldn't happen)
        _selectedRewardIndex = 0;
      }

      HapticFeedback.mediumImpact();

      // Play spin sound
      try {
        await _audioPlayer.play(AssetSource('sounds/spin_wheel.mp3'));
      } catch (e) {
        debugPrint('Spin sound not found: $e');
      }

      _controller.reset();
      final int randomRounds = 5 + math.Random().nextInt(2);

      final double segmentAngle = 1 / _dbRewards.length;
      final double endPoint = 1 - ((_selectedRewardIndex + 0.5) * segmentAngle);
      final double targetTurns = randomRounds + endPoint;

      _controller.duration = const Duration(milliseconds: 5800);
      _animation = Tween<double>(begin: 0, end: targetTurns).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Cubic(0.08, 0.0, 0.12, 1.0),
        ),
      );

      _startSpinTicks();

      await _controller.forward();

      _audioPlayer.stop();

      setState(() {
        _isSpinning = false;
        _showWinHighlight = true;
        _storedSpins =
            (response['stored_spins'] as num?)?.toInt() ?? _storedSpins;
      });

      unawaited(KspBalanceService.to.afterFinancialMutation(
        response is Map ? Map<String, dynamic>.from(response) : null,
      ));

      _startWinHighlightPulse();
      if (_lastGrantedPoints > 0) {
        _confettiController.play();
      }
      _showVictoryOverlay();

      _fetchFreeSpinStatus();
      SafeGetx.debugTrace(
        className: 'SpinWheelView',
        method: '_spin',
        feature: 'Home',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'rewardIndex': _selectedRewardIndex},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SpinWheelView',
        method: '_spin',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      setState(() => _isSpinning = false);
      Get.snackbar(
        'error'.tr,
        e.toString(),
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
    }
  }

  void _showBuySpinsDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.darkGold.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: AppColors.darkGold, size: 64),
              const SizedBox(height: 16),
              Text(
                'buy_spins'.tr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'spins_cost_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Obx(
                () => _buildKspBalanceChip(HomeController.to.userPoints.value),
              ),
              const SizedBox(height: 16),
              _buildBundleOption(
                'single',
                'one_spin'.tr,
                100,
                isBestValue: false,
              ),
              const SizedBox(height: 12),
              _buildBundleOption(
                'triple',
                'three_spins'.tr,
                300,
                isBestValue: false,
              ),
              const SizedBox(height: 12),
              _buildBundleOption(
                'septuple',
                'seven_spins'.tr,
                500,
                isBestValue: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBundleOption(
    String type,
    String title,
    int cost, {
    required bool isBestValue,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        KasbyButton(
          text: '$title ($cost ${'points'.tr})',
          onPressed: () => _purchaseBundle(type, cost),
        ),
        if (isBestValue)
          Positioned(
            top: -10,
            right: -10,
            child:
                Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'HOT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                    ),
          ),
      ],
    );
  }

  void _startSpinTicks() {
    _tickTimer?.cancel();
    var lastBoundary = -1;

    _tickTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!_controller.isAnimating) {
        timer.cancel();
        return;
      }

      final boundary = (_animation.value * _dbRewards.length).floor();
      if (boundary != lastBoundary) {
        lastBoundary = boundary;
        HapticFeedback.selectionClick();
      }
    });
  }

  void _startWinHighlightPulse() {
    _highlightTimer?.cancel();
    var tick = 0;
    _highlightTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      tick++;
      setState(() {
        _highlightPulse = (math.sin(tick * 0.18) + 1) / 2;
      });
      if (tick > 120) {
        timer.cancel();
      }
    });
  }

  String _victoryRewardText(SpinReward reward) {
    if (reward.isGift) {
      return 'gift_reward'.tr;
    }
    if (_lastGrantedPoints <= 0 || reward.isNoReward) {
      return 'no_reward'.tr;
    }
    return '$_lastGrantedPoints KSP';
  }

  String _victorySubtitle(SpinReward reward) {
    if (reward.isGift && _lastGrantedPoints > 0) {
      return 'gift_reward_points'.trParams({
        'count': _lastGrantedPoints.toString(),
      });
    }
    if (_lastGrantedPoints <= 0) {
      return 'try_again_soon'.tr;
    }
    return 'win_extra_rewards'.tr;
  }

  void _showVictoryOverlay() {
    final reward = _dbRewards[_selectedRewardIndex];
    HapticFeedback.heavyImpact();
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.surface : AppColors.surfaceLight)
                .withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.darkGold.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkGold.withValues(alpha: 0.1),
                ),
                child: Icon(reward.icon, size: 80, color: AppColors.darkGold),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'congratulations'.tr,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              Text(
                _victorySubtitle(reward),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 24),
              Text(
                    _victoryRewardText(reward),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkGold,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  )
                  .animate()
                  .scale(delay: 600.ms)
                  .shimmer(duration: const Duration(seconds: 2)),
              const SizedBox(height: 40),
              KasbyButton(
                text: 'ok'.tr,
                onPressed: () {
                  setState(() {
                    _showWinHighlight = false;
                    _highlightPulse = 0;
                  });
                  _highlightTimer?.cancel();
                  Get.back(closeOverlays: false);
                },
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ).animate().scale(duration: 400.ms),
      barrierColor: Colors.black87,
    );
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'SpinWheelView',
      method: 'dispose',
      feature: 'Home',
      status: 'INFO',
    );
    _countdownTimer?.cancel();
    _highlightTimer?.cancel();
    _tickTimer?.cancel();
    _confettiController.dispose();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSpinning,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            'spin_win'.tr,
            style: const TextStyle(color: Color(0xFFC9A24D), fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFFC9A24D)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _isSpinning ? null : () => Get.safeBack(),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
            child: Column(
              children: [
                Text(
                  'feeling_lucky'.tr,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC9A24D),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 7),
              Text(
                'spin_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 16,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              Obx(
                () => KeyedSubtree(
                  key: TourTargetKeys.spinHistory,
                  child: _buildKspBalanceChip(HomeController.to.userPoints.value),
                ),
              ),
              const SizedBox(height: 40),

              Builder(
                builder: (context) {
                  final wheelSize = kasbySpinWheelDiameter(context);
                  final innerSize = wheelSize * 0.882;
                  final hubSize = wheelSize * 0.229;
                  return KeyedSubtree(
                    key: TourTargetKeys.spinWheel,
                    child: SizedBox(
                    width: wheelSize,
                    height: wheelSize + 20,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        KasbySpinWheelAmbientGlow(size: wheelSize),
                        KasbySpinWheelOuterRing(size: wheelSize, ledCount: 24),
                        RotationTransition(
                          turns: _animation,
                          child: SizedBox(
                            width: innerSize,
                            height: innerSize,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: Size(innerSize, innerSize),
                                  painter: KasbySpinWheelPainter(
                                    rewards: _dbRewards,
                                    highlightIndex: _showWinHighlight
                                        ? _selectedRewardIndex
                                        : null,
                                    highlightPulse: _highlightPulse,
                                  ),
                                ),
                                KasbySpinWheelSegmentLabels(
                                  rewards: _dbRewards,
                                  diameter: innerSize,
                                ),
                              ],
                            ),
                          ),
                        ),
                        KasbySpinWheelCenterHub(size: hubSize),
                        Positioned(
                          top: wheelSize * 0.018,
                          child: KasbySpinWheelPointer(isAnimating: _isSpinning)
                              .animate(
                                onPlay: (c) => _isSpinning
                                    ? c.repeat(reverse: true)
                                    : c.stop(),
                              )
                              .moveY(begin: 0, end: 4, duration: 180.ms),
                        ),
                      ],
                    ),
                  ),
                  );
                },
              ),

              const SizedBox(height: 20),
              KeyedSubtree(
                key: TourTargetKeys.spinFreeSpin,
                child: _buildTriesIndicator(),
              ),
              const SizedBox(height: 20),

              // WOW Primary Action Button
              KeyedSubtree(
                key: TourTargetKeys.spinBuy,
                child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        if (!_isSpinning)
                          BoxShadow(
                            color: _isFreeSpinAvailable
                                ? Colors.green.withValues(alpha: 0.4)
                                : _storedSpins > 0
                                ? AppColors.darkGold.withValues(alpha: 0.4)
                                : Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSpinning ? null : _handleSpinButtonPress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFreeSpinAvailable
                            ? Colors.green.shade600
                            : _storedSpins > 0
                            ? AppColors.darkGold
                            : AppColors.darkGold.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: _isSpinning
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isFreeSpinAvailable
                                      ? Icons.card_giftcard_rounded
                                      : _storedSpins > 0
                                      ? Icons.auto_awesome_rounded
                                      : Icons.shopping_cart_rounded,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isFreeSpinAvailable
                                      ? 'free_spin_now'.tr
                                      : _storedSpins > 0
                                      ? 'spin_now'.tr
                                      : 'buy_spins'.tr,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              )
                  .animate(
                    onPlay: (c) =>
                        _isFreeSpinAvailable ||
                            (_storedSpins > 0 && !_isSpinning)
                        ? c.repeat(reverse: true)
                        : c.stop(),
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                    duration: 800.ms,
                    curve: Curves.easeInOut,
                  ),

              const SizedBox(height: 30),
              Text(
                'spin_disclaimer_text'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
        ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.04,
                numberOfParticles: 18,
                maxBlastForce: 18,
                minBlastForce: 6,
                gravity: 0.18,
                shouldLoop: false,
                colors: const [
                  Color(0xFFF5D77A),
                  Color(0xFFC9A24D),
                  Color(0xFF8B6914),
                  Color(0xFFFFF8E7),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
