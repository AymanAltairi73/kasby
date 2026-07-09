import 'dart:io';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:kasby/features/profile/domain/kyc_selfie_angle.dart';
import 'package:kasby/features/profile/domain/kyc_selfie_capture_result.dart';

/// Manual multi-angle selfie capture — no on-device face detection.
class KycSelfieLivenessController extends GetxController {
  CameraController? cameraController;

  final isInitializing = true.obs;
  final initError = ''.obs;
  final currentAngleIndex = 0.obs;
  final isCapturing = false.obs;
  final showCaptureSuccess = false.obs;

  final capturedPaths = <KycSelfieAngle, String>{}.obs;

  KycSelfieAngle get currentAngle =>
      KycSelfieAngle.ordered[currentAngleIndex.value];

  bool get isComplete => capturedPaths.length == KycSelfieAngle.ordered.length;

  @override
  void onInit() {
    super.onInit();
    _initCamera();
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }

  Future<void> _initCamera() async {
    isInitializing.value = true;
    initError.value = '';
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);

      cameraController = controller;
      isInitializing.value = false;
    } catch (e) {
      initError.value = e.toString();
      isInitializing.value = false;
    }
  }

  Future<void> retryInit() async {
    await cameraController?.dispose();
    cameraController = null;
    await _initCamera();
  }

  Future<void> captureCurrentAngle() async {
    if (isCapturing.value || showCaptureSuccess.value || isComplete) return;
    await _captureCurrentAngle();
  }

  Future<void> _captureCurrentAngle() async {
    if (isCapturing.value) return;
    isCapturing.value = true;

    try {
      final controller = cameraController;
      if (controller == null || !controller.value.isInitialized) return;

      final file = await controller.takePicture();
      capturedPaths[currentAngle] = file.path;
      capturedPaths.refresh();

      showCaptureSuccess.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      showCaptureSuccess.value = false;

      if (currentAngleIndex.value < KycSelfieAngle.ordered.length - 1) {
        currentAngleIndex.value++;
      } else {
        final result = await buildResult();
        if (result != null) {
          Get.back(result: result);
        }
      }
    } finally {
      isCapturing.value = false;
    }
  }

  Future<void> retakeCurrentAngle() async {
    final angle = currentAngle;
    capturedPaths.remove(angle);
    capturedPaths.refresh();
    showCaptureSuccess.value = false;
  }

  Future<void> retakeAll() async {
    capturedPaths.clear();
    capturedPaths.refresh();
    currentAngleIndex.value = 0;
    showCaptureSuccess.value = false;
  }

  Future<Map<String, dynamic>> _buildMetadata() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> device = {'platform': 'unknown'};
    if (GetPlatform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      device = {
        'platform': 'android',
        'model': info.model,
        'manufacturer': info.manufacturer,
        'sdk': info.version.sdkInt,
      };
    } else if (GetPlatform.isIOS) {
      final info = await deviceInfo.iosInfo;
      device = {
        'platform': 'ios',
        'model': info.utsname.machine,
        'system': info.systemVersion,
      };
    }

    return {
      'submission_timestamp': DateTime.now().toUtc().toIso8601String(),
      'device': device,
      'liveness_session': DateTime.now().millisecondsSinceEpoch.toString(),
      'movement_verified': false,
      'face_detection': false,
      'capture_flow': 'multi_angle_manual_v2',
    };
  }

  Future<KycSelfieCaptureResult?> buildResult() async {
    if (!isComplete) return null;
    final metadata = await _buildMetadata();
    return KycSelfieCaptureResult(
      frontPath: capturedPaths[KycSelfieAngle.front]!,
      rightPath: capturedPaths[KycSelfieAngle.right]!,
      leftPath: capturedPaths[KycSelfieAngle.left]!,
      livenessMetadata: metadata,
    );
  }
}
