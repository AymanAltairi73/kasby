import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/spin_reward_model.dart';
import 'dart:async';

class SpinWheelView extends StatefulWidget {
  const SpinWheelView({super.key});

  @override
  State<SpinWheelView> createState() => _SpinWheelViewState();
}

class _SpinWheelViewState extends State<SpinWheelView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  int _selectedRewardIndex = 0;
  int _userPoints = 0;
  int _storedSpins = 0;
  bool _isLoadingRewards = false; // Set to false since we start with defaults
  List<SpinReward> _dbRewards = SpinReward.defaultRewards;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _lastFreeSpinAt;
  Timer? _countdownTimer;
  String _timeUntilNextSpin = '';
  bool _isFreeSpinAvailable = false;

  // Hardcoded rewards removed - now using _dbRewards

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCirc,
    );
    _fetchInitialData();
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
    await Future.wait([
      _fetchUserPoints(),
      _fetchRewards(),
      _fetchFreeSpinStatus(),
    ]);
    _startCountdownTimer();
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
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _dbRewards = (response as List)
              .map((r) => SpinReward.fromJson(r))
              .toList();
          _isLoadingRewards = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching rewards: $e');
      if (mounted) setState(() => _isLoadingRewards = false);
    }
  }

  Widget _buildTriesIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.darkGold, size: 20)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
          const SizedBox(width: 8),
          Text(
            _isFreeSpinAvailable
                ? 'free_spin_now'.tr
                : _storedSpins > 0
                ? 'use_stored_spin'.trParams({'count': _storedSpins.toString()})
                : 'next_free_spin'.trParams({'time': _timeUntilNextSpin}),
            style: TextStyle(
              color: AppColors.darkGold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUserPoints() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from('user_points')
          .select('current_balance')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _userPoints = (response['current_balance'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching points: $e');
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
    });

    try {
      // Call secure backend RPC
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

      final rewardData = response['reward'];
      final rewardId = rewardData['id'];

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
      final int randomRounds = 4 + math.Random().nextInt(3);

      // Calculate target turns based on the selected index
      // The wheel segments are (index / length) * 2pi
      // To align with the pointer at top (-pi/2), we need to offset
      final double segmentAngle = 1 / _dbRewards.length;
      final double endPoint = 1 - ((_selectedRewardIndex + 0.5) * segmentAngle);
      final double targetTurns = randomRounds + endPoint;

      _animation = Tween<double>(begin: 0, end: targetTurns).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc),
      );

      _startTicks(targetTurns);

      _controller.duration = const Duration(seconds: 5);
      await _controller.forward();

      _audioPlayer.stop();
      _showVictoryOverlay();

      // Update local state from backend response
      setState(() {
        _isSpinning = false;
        _userPoints = (response['new_balance'] as num?)?.toInt() ?? _userPoints;
        _storedSpins =
            (response['stored_spins'] as num?)?.toInt() ?? _storedSpins;
      });

      // Refresh cooldown
      _fetchFreeSpinStatus();
    } catch (e) {
      debugPrint('Spin error: $e');
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
          onPressed: () async {
            if (_userPoints >= cost) {
              Get.back();
              try {
                final response = await SupabaseService.client.rpc(
                  'buy_spins_bundle',
                  params: {'p_bundle_type': type},
                );
                if (response['success'] == true) {
                  setState(() {
                    _userPoints =
                        (response['new_balance'] as num?)?.toInt() ??
                        _userPoints;
                    _storedSpins =
                        (response['stored_spins'] as num?)?.toInt() ??
                        _storedSpins;
                  });
                  // Refresh data from server to ensure balance and spins are synced
                  _fetchInitialData();
                  Get.snackbar(
                    'success'.tr,
                    'bundle_purchased_successfully'.tr,
                    backgroundColor: AppColors.softGreen.withValues(alpha: 0.7),
                    colorText: Colors.white,
                  );
                } else {
                  Get.snackbar(
                    'error'.tr,
                    response['error']?.toString() ?? 'unknown_error'.tr,
                    backgroundColor: AppColors.error.withValues(alpha: 0.7),
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
                debugPrint('Buy bundle error: $e');
              }
            } else {
              Get.snackbar(
                'insufficient_points'.tr,
                'need_more_points'.tr,
                backgroundColor: AppColors.error.withValues(alpha: 0.7),
                colorText: Colors.white,
              );
            }
          },
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

  void _startTicks(double totalRotations) {
    final int segmentsPerRotation = _dbRewards.length;
    int totalTicks = (totalRotations * segmentsPerRotation).floor();
    int currentTick = 0;

    void triggerNextTick() {
      if (!_isSpinning || currentTick >= totalTicks) return;

      HapticFeedback.lightImpact();
      currentTick++;

      // Increase delay based on acceleration curve
      // As _controller.value goes from 0 to totalRotations
      // The delay should increase.
      // Delay calculation for 5s duration
      double progress = _controller.value;
      double nextDelay = 30 + (370 * progress); // Faster ticks for 5s

      Future.delayed(
        Duration(milliseconds: nextDelay.toInt()),
        triggerNextTick,
      );
    }

    triggerNextTick();
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
                'win_extra_rewards'.tr,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 24),
              Text(
                    '${reward.label == 'bonus' ? 'bonus'.tr : reward.label} ${'points'.tr}',
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
                onPressed: () => Get.back(),
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
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSpinning,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('spin_win'.tr),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _isSpinning ? null : () => Get.back(),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
            child: Column(
              children: [
                Text(
                  'feeling_lucky'.tr,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 12),
              Text(
                'spin_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 60),

              // The Miraculous Wheel
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow & Lights
                  Container(
                        width: 290,
                        height: 290,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            // BoxShadow(
                            //   color: AppColors.darkGold.withValues(alpha: 0.15),
                            //   blurRadius: 40,
                            //   spreadRadius: 10,
                            // ),
                          ],
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                        duration: const Duration(seconds: 2),
                      ),

                  // Rotating LEDs
                  ...List.generate(12, (index) {
                    return RotationTransition(
                      turns: AlwaysStoppedAnimation(index / 12),
                      child: Transform.translate(
                        offset: const Offset(0, -145),
                        child:
                            Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    //color: AppColors.darkGold,
                                    shape: BoxShape.circle,
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat())
                                .scale(
                                  duration: const Duration(seconds: 1),
                                  delay: (index * 100).ms,
                                  begin: const Offset(0.5, 0.5),
                                )
                                .tint(
                                  color: Colors.white,
                                  duration: const Duration(seconds: 1),
                                ),
                      ),
                    );
                  }),

                  // The Core Wheel
                  RotationTransition(
                    turns: _animation,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.darkGold, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: WheelPainter(rewards: _dbRewards),
                      ),
                    ),
                  ),
                  //SizedBox(height: 10),

                  // Center Pin
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surface
                          : AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      image: const DecorationImage(
                        image: AssetImage('assets/images/spin-wheel.jpg'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // The Pointer
                  Positioned(
                    top: -15,
                    child:
                        Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Colors.white,
                              size: 60,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            )
                            .animate(
                              onPlay: (c) => _isSpinning
                                  ? c.repeat(reverse: true)
                                  : c.stop(),
                            )
                            .moveY(begin: 0, end: 5, duration: 200.ms),
                  ),
                ],
              ),

              const SizedBox(height: 60),
              _buildTriesIndicator(),
              const SizedBox(height: 32),

              // WOW Primary Action Button
              Container(
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

              const SizedBox(height: 48),
              Text(
                'spin_disclaimer_text'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<SpinReward> rewards;

  WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    if (rewards.isEmpty) return;
    final double radius = size.width / 2;
    final Rect rect = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius,
    );

    final int count = rewards.length;
    final double angle = (2 * math.pi) / count;

    for (int i = 0; i < count; i++) {
      final reward = rewards[i];
      // Draw Segment
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: [
            i % 2 == 0
                ? AppColors.darkGold.withValues(alpha: 0.9)
                : AppColors.surface,
            i % 2 == 0
                ? AppColors.darkGold
                : AppColors.surface.withValues(alpha: 0.8),
          ],
        ).createShader(rect);

      canvas.drawArc(rect, i * angle - math.pi / 2, angle, true, paint);

      // Draw Icon/Label
      canvas.save();
      canvas.translate(radius, radius);
      canvas.rotate(i * angle + angle / 2);

      final String labelText = reward.label == 'bonus'
          ? 'bonus'.tr
          : reward.label;
      final bool isGift =
          reward.label == 'bonus' || labelText == 'هدية' || labelText == 'Gift';

      if (isGift) {
        final iconPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(Icons.card_giftcard_rounded.codePoint),
            style: TextStyle(
              fontSize: 22,
              fontFamily: Icons.card_giftcard_rounded.fontFamily,
              package: Icons.card_giftcard_rounded.fontPackage,
              color: i % 2 == 0 ? Colors.black : Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        iconPainter.paint(canvas, Offset(-iconPainter.width / 2, -radius + 45));
      } else {
        final textPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              color: i % 2 == 0 ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // Position text towards the edge
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -radius + 40));
      }

      // Draw tiny dot at segment edge
      final Paint dotPaint = Paint()
        ..color = i % 2 == 0
            ? Colors.black45
            : AppColors.darkGold.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(0, -radius + 15), 3, dotPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
