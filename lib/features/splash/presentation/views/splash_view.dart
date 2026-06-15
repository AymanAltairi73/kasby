import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/services/notification_navigation_service.dart';
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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    // Listen to auth status changes
    _authWorker = ever(AuthController.to.authStatus, (status) {
      if (status != AuthStatus.initial) {
        _navigateToNext(status);
      }
    });

    // Check if status is already determined (case where Supabase completes before splash init)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthController.to.authStatus.value != AuthStatus.initial) {
        _navigateToNext(AuthController.to.authStatus.value);
      }
    });

    // Timeout fallback: navigate to onboarding if auth check hangs
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

    // Ensure splash shows for at least 2 seconds for smooth UX
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final remaining = const Duration(seconds: 2) - elapsed;

    Future.delayed(remaining > Duration.zero ? remaining : Duration.zero, () {
      if (!mounted) return;
      if (status == AuthStatus.authenticated) {
        Get.offAllNamed(Routes.home);
        NotificationNavigationService.processPendingNavigation();
      } else if (AuthController.to.pendingVerificationEmail.value?.isNotEmpty ==
          true) {
        Get.offAllNamed(
          Routes.verifyEmail,
          arguments: {
            'email': AuthController.to.pendingVerificationEmail.value,
          },
        );
      } else {
        Get.offAllNamed(Routes.onboarding);
      }
    });
  }

  @override
  void dispose() {
    _authWorker?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              Theme.of(context).brightness == Brightness.dark ? AppColors.darkGold : AppColors.darkGold.withValues(alpha: 0.8)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.6, 1.0],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image.asset('assets/images/logo.png', width: 150, height: 150),
                // const SizedBox(height: 24),
                Text(
                  'app_name'.tr,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.primaryLight,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 48),
                CircularProgressIndicator(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.primaryLight,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
