import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Premium Logo Circle
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkGold.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.darkGold.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
              
              const SizedBox(height: 48),
              
              Text(
                'app_locked'.tr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 12),
              
              Text(
                'lock_screen_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 300.ms),
              
              const SizedBox(height: 80),
              
              if (_isAuthenticating)
                CircularProgressIndicator(color: AppColors.darkGold)
              else
                KasbyButton(
                  text: 'unlock_now'.tr,
                  onPressed: _handleAuth,
                  icon: Icons.fingerprint_rounded,
                ).animate().scale(delay: 500.ms),
              
              const SizedBox(height: 24),
              
              TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Get.defaultDialog(
                    title: 'confirm_logout'.tr,
                    middleText: 'logout_desc'.tr,
                    textConfirm: 'logout'.tr,
                    confirmTextColor: Colors.white,
                    buttonColor: AppColors.error,
                    onConfirm: () => AuthController.to.logout(),
                    textCancel: 'cancel'.tr,
                  );
                },
                child: Text(
                  'logout'.tr,
                  style: TextStyle(color: AppColors.error),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
