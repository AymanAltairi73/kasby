import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/profile/domain/kyc_selfie_angle.dart';
import 'package:kasby/features/profile/domain/kyc_selfie_capture_result.dart';
import 'package:kasby/features/profile/presentation/controllers/kyc_selfie_liveness_controller.dart';
import 'package:kasby/features/profile/presentation/widgets/kyc_face_guide_painter.dart';

class KycSelfieLivenessView extends StatefulWidget {
  const KycSelfieLivenessView({super.key});

  static Future<KycSelfieCaptureResult?> open() async {
    final result = await Get.to<KycSelfieCaptureResult>(
      () => const KycSelfieLivenessView(),
    );
    return result;
  }

  @override
  State<KycSelfieLivenessView> createState() => _KycSelfieLivenessViewState();
}

class _KycSelfieLivenessViewState extends State<KycSelfieLivenessView>
    with SingleTickerProviderStateMixin {
  late final KycSelfieLivenessController controller;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    controller = Get.put(KycSelfieLivenessController());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (Get.isRegistered<KycSelfieLivenessController>()) {
      Get.delete<KycSelfieLivenessController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('kyc_selfie_liveness_title'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'cancel'.tr,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isInitializing.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.darkGold),
          );
        }
        if (controller.initError.value.isNotEmpty) {
          return _buildErrorState();
        }
        return _buildCaptureBody(theme);
      }),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            'kyc_selfie_camera_error'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          KasbyButton(text: 'retry'.tr, onPressed: controller.retryInit),
        ],
      ),
    );
  }

  Widget _buildCaptureBody(ThemeData theme) {
    final camera = controller.cameraController;
    if (camera == null || !camera.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.darkGold),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(camera),
              LayoutBuilder(
                builder: (context, constraints) {
                  final geometry = KycGuideGeometry.forSize(
                    constraints.biggest,
                  );
                  return Obx(() {
                    final showSuccess = controller.showCaptureSuccess.value;
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: KycFaceGuidePainter(
                            geometry: geometry,
                            showSuccess: showSuccess,
                            pulse: showSuccess ? 1 : _pulseController.value,
                          ),
                        );
                      },
                    );
                  });
                },
              ),
              Obx(
                () => controller.showCaptureSuccess.value
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.softGreen.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.softGreen.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildProgressCard(theme),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: _buildInstructionCard(theme),
              ),
            ],
          ),
        ),
        _buildBottomActions(theme),
      ],
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'kyc_selfie_progress'.trParams({
                'current': '${controller.currentAngleIndex.value + 1}',
                'total': '${KycSelfieAngle.ordered.length}',
              }),
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.darkGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(KycSelfieAngle.ordered.length, (index) {
                final angle = KycSelfieAngle.ordered[index];
                final done = controller.capturedPaths.containsKey(angle);
                final active = index == controller.currentAngleIndex.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == KycSelfieAngle.ordered.length - 1 ? 0 : 8,
                    ),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: done
                                ? AppColors.softGreen
                                : active
                                ? AppColors.darkGold
                                : Colors.white24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          angle.titleKey.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: active ? Colors.white : Colors.white60,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(ThemeData theme) {
    return Obx(() {
      final showSuccess = controller.showCaptureSuccess.value;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey('${controller.currentAngleIndex.value}_$showSuccess'),
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: showSuccess
                ? AppColors.softGreen.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: showSuccess
                  ? AppColors.softGreen.withValues(alpha: 0.6)
                  : AppColors.darkGold.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.currentAngle.titleKey.tr,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                showSuccess
                    ? 'kyc_selfie_captured'.tr
                    : controller.currentAngle.instructionKey.tr,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Obx(() {
      final canCapture =
          !controller.isCapturing.value && !controller.showCaptureSuccess.value;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canCapture
                        ? controller.retakeCurrentAngle
                        : null,
                    child: Text('kyc_selfie_retake'.tr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: KasbyButton(
                    text: 'kyc_selfie_capture'.tr,
                    isLoading: controller.isCapturing.value,
                    onPressed: canCapture
                        ? controller.captureCurrentAngle
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
