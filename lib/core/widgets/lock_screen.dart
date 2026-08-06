import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'LockScreen',
      method: 'initState',
      feature: 'Core',
      status: 'INFO',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleAuth());
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'LockScreen',
      method: 'dispose',
      feature: 'Core',
      status: 'INFO',
    );
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);
    final stopwatch = Stopwatch()..start();

    try {
      final success = await SessionService.to.authenticate();

      if (success) {
        SessionService.to.unlock();
        SafeGetx.debugTrace(
          className: 'LockScreen',
          method: '_handleAuth',
          feature: 'Core',
          status: 'SUCCESS',
          durationMs: stopwatch.elapsedMilliseconds,
        );
        Get.back();
      } else {
        SafeGetx.debugTrace(
          className: 'LockScreen',
          method: '_handleAuth',
          feature: 'Core',
          status: 'WARN',
          message: 'Authentication failed',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LockScreen',
        method: '_handleAuth',
        feature: 'Core',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _showLogoutDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'confirm_logout'.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'logout_desc'.tr,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      onPressed: () => Get.back(),
                      child: Text(
                        'cancel'.tr,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Get.back();
                        AuthController.to.logout();
                      },
                      child: Text(
                        'logout'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = Get.isRegistered<HomeController>()
        ? HomeController.to.profile.value
        : null;

    final userName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : null;

    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.backgroundLight,
        body: Stack(
          children: [
            // Ambient Top Gold Glow Orb
            Positioned(
              top: -80,
              left: MediaQuery.of(context).size.width / 2 - 140,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.darkGold.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      AppColors.darkGold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom subtle accent orb
            Positioned(
              bottom: -100,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.darkGold.withValues(
                        alpha: isDark ? 0.08 : 0.05,
                      ),
                      AppColors.darkGold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content Area
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Top Security Badge Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppColors.darkGold.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.darkGold,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'kasby_secured_platform'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms).slideY(
                      begin: -0.2,
                      end: 0,
                    ),

                    const Spacer(),

                    // Profile / Branding Section
                    Column(
                      children: [
                        // User Avatar or glowing Kasby Logo Ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Glow Ring
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.darkGold.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 25,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 96,
                              height: 96,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.goldGradient,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : Colors.white,
                                ),
                                child:
                                    profile?.avatarUrl != null &&
                                            profile!.avatarUrl!.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                            child: Image.network(
                                              profile.avatarUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => Image.asset(
                                                    'assets/images/logo.png',
                                                    fit: BoxFit.contain,
                                                  ),
                                            ),
                                          )
                                        : Image.asset(
                                            'assets/images/logo.png',
                                            fit: BoxFit.contain,
                                          ),
                              ),
                            ),
                          ],
                        ).animate().scale(
                          duration: 700.ms,
                          curve: Curves.elasticOut,
                        ),

                        const SizedBox(height: 20),

                        // Welcome Back Title
                        Text(
                          userName != null
                              ? 'welcome_back_user'.trParams({'name': userName})
                              : 'welcome_back'.tr,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 6),

                        // Subtitle badge
                        Text(
                          'app_locked'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Glass Hero Security Card
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(28),
                      borderColor: AppColors.darkGold.withValues(alpha: 0.25),
                      opacity: isDark ? 0.08 : 0.4,
                      child: Column(
                        children: [
                          // Interactive Biometric Touch Pulse Circle
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _handleAuth();
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulse Aura Ring
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.darkGold.withValues(
                                      alpha: 0.08,
                                    ),
                                  ),
                                )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1.15, 1.15),
                                      duration: 1800.ms,
                                    )
                                    .fadeIn(),

                                // Biometric Touch Ring
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.darkGold.withValues(
                                      alpha: 0.15,
                                    ),
                                    border: Border.all(
                                      color: AppColors.darkGold.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.darkGold.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 15,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.fingerprint_rounded,
                                    size: 42,
                                    color: AppColors.darkGold,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().scale(delay: 400.ms),

                          const SizedBox(height: 16),

                          Text(
                            'biometric_unlock_prompt'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ).animate().fadeIn(delay: 450.ms),

                          const SizedBox(height: 24),

                          // Unlock Button
                          if (_isAuthenticating)
                            SizedBox(
                              height: 54,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.darkGold,
                                ),
                              ),
                            )
                          else
                            KasbyButton(
                              text: 'unlock_now'.tr,
                              onPressed: _handleAuth,
                              icon: Icons.fingerprint_rounded,
                            ).animate().fadeIn(delay: 500.ms),
                        ],
                      ),
                    ).animate().fadeIn(delay: 350.ms).slideY(
                      begin: 0.1,
                      end: 0,
                    ),

                    const Spacer(),

                    // Logout Button
                    TextButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      label: Text(
                        'logout'.tr,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms),

                    const SizedBox(height: 12),

                    // Security Encryption Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_clock_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'security_encryption_notice'.tr,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 650.ms),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
