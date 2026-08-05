import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/services/notification_navigation_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _hasNavigated = false;
  Worker? _authWorker;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    _authWorker = ever(AuthController.to.authStatus, (status) {
      if (status != AuthStatus.initial) {
        _navigateToNext(status);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final status = AuthController.to.authStatus.value;
      if (status != AuthStatus.initial) {
        _navigateToNext(status);
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (!_hasNavigated && mounted) {
        _navigateToNext(AuthStatus.unauthenticated);
      }
    });
  }

  void _navigateToNext(AuthStatus status) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    SafeGetx.debugTrace(
      className: 'SplashView',
      method: '_navigateToNext',
      feature: 'Splash',
      status: 'INFO',
      params: {'authStatus': status.name},
    );

    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final remaining = const Duration(seconds: 2) - elapsed;

    Future.delayed(
      remaining > Duration.zero ? remaining : Duration.zero,
      () async {
        if (!mounted) return;

        // Check if onboarding is completed
        final prefs = await SharedPreferences.getInstance();
        final onboardingCompleted =
            prefs.getBool('onboarding_completed') ?? false;

        if (status == AuthStatus.authenticated) {
          Get.offAllNamed(Routes.home);
          NotificationNavigationService.processPendingNavigation();
        } else if (!AuthOtpConfig.tempSkipEmailVerification &&
            AuthController.to.pendingVerificationEmail.value?.isNotEmpty ==
                true) {
          Get.offAllNamed(
            Routes.verifyEmail,
            arguments: {
              'email': AuthController.to.pendingVerificationEmail.value,
            },
          );
        } else if (!onboardingCompleted) {
          // First launch: show onboarding
          Get.offAllNamed(Routes.onboarding);
        } else {
          // Returning user: go to login
          Get.offAllNamed(Routes.login);
        }
      },
    );
  }

  @override
  void dispose() {
    _authWorker?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.white : AppColors.primaryLight;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              isDark
                  ? AppColors.darkGold.withValues(alpha: 0.35)
                  : AppColors.darkGold.withValues(alpha: 0.25),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'app_name'.tr,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: accent,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: AppColors.darkGold,
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
