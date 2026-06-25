import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/services/notification_navigation_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  String _versionLabel = '';
  bool _isRestoringSession = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _loadVersion();

    _authWorker = ever(AuthController.to.authStatus, (status) {
      if (status != AuthStatus.initial) {
        _navigateToNext(status);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final status = AuthController.to.authStatus.value;
      if (status != AuthStatus.initial) {
        _navigateToNext(status);
      } else {
        setState(() => _isRestoringSession = true);
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (!_hasNavigated && mounted) {
        _navigateToNext(AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _versionLabel = 'v${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {}
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

    Future.delayed(remaining > Duration.zero ? remaining : Duration.zero, () {
      if (!mounted) return;
      if (status == AuthStatus.authenticated) {
        Get.offAllNamed(Routes.home);
        NotificationNavigationService.processPendingNavigation();
      }
      else if (!AuthOtpConfig.tempSkipEmailVerification &&
          AuthController.to.pendingVerificationEmail.value?.isNotEmpty == true) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            child: Column(
              children: [
                const Spacer(flex: 2),
                Semantics(
                  label: 'app_name'.tr,
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo2.jpg',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: KasbySpacing.lg),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Lottie.asset(
                    'assets/lottie/splash_secure.json',
                    repeat: true,
                    animate: KasbyMotion.enabled(context),
                  ),
                ),
                const SizedBox(height: KasbySpacing.md),
                Text(
                  'app_name'.tr,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: isDark ? Colors.white : AppColors.primaryLight,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: KasbySpacing.sm),
                Text(
                  'splash_secured_platform'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: KasbySpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.darkGold.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'splash_protected_encryption'.tr,
                      style: TextStyle(
                        color: AppColors.darkGold.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                if (_isRestoringSession)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KasbySpacing.md),
                    child: Text(
                      'restoring_session'.tr,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: isDark ? Colors.white : AppColors.primaryLight,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: KasbySpacing.xl),
                if (_versionLabel.isNotEmpty)
                  Text(
                    _versionLabel,
                    style: TextStyle(
                      color: (isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight)
                          .withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: KasbySpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
