import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kasby/features/profile/domain/kyc_selfie_angle.dart';

class KycFaceAnalysis {
  final bool isReady;
  final String guidanceKey;
  final double? yaw;

  const KycFaceAnalysis({
    required this.isReady,
    required this.guidanceKey,
    this.yaw,
  });
}

KycFaceAnalyzer kycFaceAnalyzer() => KycFaceAnalyzer();

class KycFaceAnalyzer {
  late final FaceDetector _detector;

  KycFaceAnalyzer() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  /// Post-capture quality checks for saved selfie files.
  ///
  /// [requirePoseYaw] is intended for live auto-capture flows. Manual multi-step
  /// capture should keep this false because front-camera still images often
  /// report unreliable [Face.headEulerAngleY] values after [takePicture].
  Future<KycFaceAnalysis> analyzeFile(
    String path, {
    KycSelfieAngle? angle,
    bool requirePoseYaw = false,
  }) async {
    if (!File(path).existsSync()) {
      return const KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_not_detected',
      );
    }

    final imageSize = await _readImageSize(path);
    if (imageSize == null) {
      return const KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_blurry',
      );
    }

    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) {
      return const KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_not_detected',
      );
    }
    if (faces.length > 1) {
      return const KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_multiple',
      );
    }

    final face = faces.first;
    final box = face.boundingBox;
    final imageArea = imageSize.width * imageSize.height;
    final faceArea = box.width * box.height;
    final faceRatio = faceArea / imageArea;

    if (faceRatio < 0.08) {
      return KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_too_far',
        yaw: face.headEulerAngleY,
      );
    }
    if (faceRatio > 0.55) {
      return KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_too_close',
        yaw: face.headEulerAngleY,
      );
    }

    if (!_isFaceCentered(box, imageSize)) {
      return KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_outside_frame',
        yaw: face.headEulerAngleY,
      );
    }

    final maxRoll = angle?.maxRoll ?? 22;
    final roll = face.headEulerAngleZ;
    if (roll != null && roll.abs() > maxRoll) {
      return KycFaceAnalysis(
        isReady: false,
        guidanceKey: 'kyc_face_tilted',
        yaw: face.headEulerAngleY,
      );
    }

    final yaw = face.headEulerAngleY;

    if (requirePoseYaw && angle != null) {
      if (yaw == null) {
        return const KycFaceAnalysis(
          isReady: false,
          guidanceKey: 'kyc_face_partial',
        );
      }
      if (!_yawMatchesAngle(yaw, angle)) {
        return KycFaceAnalysis(
          isReady: false,
          guidanceKey: angle.instructionKey,
          yaw: yaw,
        );
      }
    }

    if (angle == KycSelfieAngle.front) {
      final leftOpen = face.leftEyeOpenProbability;
      final rightOpen = face.rightEyeOpenProbability;
      if ((leftOpen != null && leftOpen < 0.35) ||
          (rightOpen != null && rightOpen < 0.35)) {
        return KycFaceAnalysis(
          isReady: false,
          guidanceKey: 'kyc_face_eyes_closed',
          yaw: yaw,
        );
      }
    }

    return KycFaceAnalysis(
      isReady: true,
      guidanceKey: 'kyc_face_hold_still',
      yaw: yaw,
    );
  }

  Future<void> dispose() async {
    await _detector.close();
  }

  Future<ui.Size?> _readImageSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  bool _isFaceCentered(ui.Rect box, ui.Size imageSize) {
    final center = box.center;
    // Saved camera JPEGs can differ from the on-screen oval guide (orientation,
    // aspect ratio). Use a generous central region instead of preview geometry.
    const horizontalMargin = 0.14;
    const verticalMargin = 0.16;
    return center.dx >= imageSize.width * horizontalMargin &&
        center.dx <= imageSize.width * (1 - horizontalMargin) &&
        center.dy >= imageSize.height * verticalMargin &&
        center.dy <= imageSize.height * (1 - verticalMargin);
  }

  bool _yawMatchesAngle(double yaw, KycSelfieAngle angle) {
    return (yaw - angle.targetYaw).abs() <= angle.yawTolerance;
  }

}

bool kycMovementVerifiedFromYaws({
  required double? frontYaw,
  required double? rightYaw,
  required double? leftYaw,
}) {
  if (frontYaw == null || rightYaw == null || leftYaw == null) {
    return false;
  }

  final values = [frontYaw, rightYaw, leftYaw];
  final spread = values.reduce(math.max) - values.reduce(math.min);
  if (spread >= 8) return true;

  return (rightYaw - frontYaw).abs() >= 4 &&
      (leftYaw - frontYaw).abs() >= 4 &&
      (rightYaw - leftYaw).abs() >= 6;
}

bool kycManualCaptureMovementVerified(Map<String, dynamic> metadata) {
  return metadata['capture_flow'] == 'multi_angle_manual_v2';
}
