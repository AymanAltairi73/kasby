import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Fallback UI shown when an unhandled widget build error occurs.
class AppErrorWidget extends StatefulWidget {
  final FlutterErrorDetails? details;

  const AppErrorWidget({super.key, this.details});

  @override
  State<AppErrorWidget> createState() => _AppErrorWidgetState();
}

class _AppErrorWidgetState extends State<AppErrorWidget> {
  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'AppErrorWidget',
      method: 'initState',
      feature: 'Core',
      status: 'ERROR',
      message: 'Unhandled widget build error',
      params: {
        'hasDetails': widget.details != null,
        'exception': widget.details?.exceptionAsString() ?? 'unknown',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.background : AppColors.backgroundLight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 24),
              Text(
                'app_error_title'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'app_error_message'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              KasbyButton(
                text: 'app_error_retry'.tr,
                onPressed: () {
                  SafeGetx.debugTrace(
                    className: 'AppErrorWidget',
                    method: 'retry',
                    feature: 'Core',
                    status: 'INFO',
                    params: {
                      'canPop': Get.key.currentState?.canPop() == true,
                    },
                  );
                  if (Get.key.currentState?.canPop() == true) {
                    Get.back();
                  } else {
                    Get.offAllNamed(Routes.splash);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
