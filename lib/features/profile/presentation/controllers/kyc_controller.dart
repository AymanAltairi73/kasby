import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/kyc_document_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/profile/domain/kyc_selfie_capture_result.dart';
import 'package:kasby/features/profile/presentation/views/kyc_selfie_liveness_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/profile/domain/kyc_face_analyzer.dart';
import 'package:kasby/features/profile/domain/kyc_selfie_angle.dart';

class KycController extends GetxController {
  final ImagePicker _picker = ImagePicker();
  var currentStep = 0.obs;
  static const int reviewStepIndex = 4;

  var selectedIdType = ''.obs;
  final nameController = TextEditingController();
  final idNumberController = TextEditingController();
  final dobController = TextEditingController();
  var dob = ''.obs;

  var frontImagePath = ''.obs;
  var backImagePath = ''.obs;
  var selfieFrontPath = ''.obs;
  var selfieRightPath = ''.obs;
  var selfieLeftPath = ''.obs;
  Map<String, dynamic> selfieLivenessMetadata = {};

  var isLoading = false.obs;
  var isLaunchingSelfie = false.obs;

  String get idTypeLabel {
    switch (selectedIdType.value) {
      case 'passport':
        return 'passport'.tr;
      case 'drivers_license':
        return 'drivers_license'.tr;
      case 'id_card':
      default:
        return 'id_card'.tr;
    }
  }

  bool get hasCompleteSelfieSet =>
      selfieFrontPath.isNotEmpty &&
      selfieRightPath.isNotEmpty &&
      selfieLeftPath.isNotEmpty;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'KycController',
      method: 'onInit',
      feature: 'Profile',
      status: 'INFO',
    );
    super.onInit();
    _prefillFromProfile();
  }

  void _prefillFromProfile() {
    final profile = HomeController.to.profile.value;
    if (profile == null) return;
    if (nameController.text.trim().isEmpty && profile.fullName.isNotEmpty) {
      nameController.text = profile.fullName;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    idNumberController.dispose();
    dobController.dispose();
    super.onClose();
  }

  Future<void> pickImage(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      if (type == 'front') {
        frontImagePath.value = image.path;
      } else if (type == 'back') {
        backImagePath.value = image.path;
      }
    }
  }

  Future<void> startSelfieLivenessCapture() async {
    if (isLaunchingSelfie.value) return;
    isLaunchingSelfie.value = true;
    try {
      final result = await KycSelfieLivenessView.open();
      if (result == null) return;

      final metadata = await _validateSelfieCapture(result);
      if (metadata == null) return;

      selfieFrontPath.value = result.frontPath;
      selfieRightPath.value = result.rightPath;
      selfieLeftPath.value = result.leftPath;
      selfieLivenessMetadata = metadata;
    } finally {
      isLaunchingSelfie.value = false;
    }
  }

  Future<Map<String, dynamic>?> _validateSelfieCapture(
    KycSelfieCaptureResult result,
  ) async {
    final analyzer = kycFaceAnalyzer();
    final yaws = <KycSelfieAngle, double>{};
    try {
      for (final angle in KycSelfieAngle.ordered) {
        final path = switch (angle) {
          KycSelfieAngle.front => result.frontPath,
          KycSelfieAngle.right => result.rightPath,
          KycSelfieAngle.left => result.leftPath,
        };
        final analysis = await analyzer.analyzeFile(path, angle: angle);
        if (!analysis.isReady) {
          Get.snackbar('error'.tr, analysis.guidanceKey.tr);
          return null;
        }
        if (analysis.yaw != null) {
          yaws[angle] = analysis.yaw!;
        }
      }

      final movementVerified =
          result.livenessMetadata['movement_verified'] == true ||
          kycManualCaptureMovementVerified(result.livenessMetadata) ||
          kycMovementVerifiedFromYaws(
            frontYaw: yaws[KycSelfieAngle.front],
            rightYaw: yaws[KycSelfieAngle.right],
            leftYaw: yaws[KycSelfieAngle.left],
          );
      if (!movementVerified) {
        Get.snackbar('error'.tr, 'kyc_selfie_liveness_failed'.tr);
        return null;
      }

      return {
        ...result.livenessMetadata,
        'movement_verified': true,
        if (yaws.length == KycSelfieAngle.ordered.length)
          'yaw_angles': {
            'front': yaws[KycSelfieAngle.front],
            'right': yaws[KycSelfieAngle.right],
            'left': yaws[KycSelfieAngle.left],
          },
      };
    } finally {
      await analyzer.dispose();
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.darkGold,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      dob.value = DateFormat('yyyy-MM-dd').format(picked);
      dobController.text = dob.value;
    }
  }

  void nextStep() {
    if (!_validateCurrentStep()) return;

    if (currentStep.value < reviewStepIndex) {
      currentStep.value++;
    } else {
      submitKyc();
    }
  }

  bool _validateCurrentStep() {
    switch (currentStep.value) {
      case 0:
        if (selectedIdType.isEmpty) {
          Get.snackbar('error'.tr, 'select_id_type_error'.tr);
          return false;
        }
        return true;
      case 1:
        if (nameController.text.trim().isEmpty ||
            idNumberController.text.trim().isEmpty ||
            dob.isEmpty) {
          Get.snackbar('error'.tr, 'fill_all_fields_error'.tr);
          return false;
        }
        return true;
      case 2:
        if (frontImagePath.isEmpty || backImagePath.isEmpty) {
          Get.snackbar('error'.tr, 'upload_both_id_sides_error'.tr);
          return false;
        }
        return true;
      case 3:
        if (!hasCompleteSelfieSet) {
          Get.snackbar('error'.tr, 'kyc_selfie_incomplete_error'.tr);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void resetForResubmission() {
    currentStep.value = 0;
    selectedIdType.value = '';
    frontImagePath.value = '';
    backImagePath.value = '';
    selfieFrontPath.value = '';
    selfieRightPath.value = '';
    selfieLeftPath.value = '';
    selfieLivenessMetadata = {};
  }

  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
    }
  }

  Future<void> submitKyc() async {
    if (!SupabaseService.isLoggedIn) {
      Get.snackbar('error'.tr, 'login_required'.tr);
      return;
    }

    if (!hasCompleteSelfieSet) {
      Get.snackbar('error'.tr, 'kyc_selfie_incomplete_error'.tr);
      return;
    }

    isLoading.value = true;
    try {
      final userId = SupabaseService.userId!;

      final frontUrl = await KycDocumentService.upload(
        file: File(frontImagePath.value),
        userId: userId,
        documentType: 'id_card_front',
      );
      final backUrl = await KycDocumentService.upload(
        file: File(backImagePath.value),
        userId: userId,
        documentType: 'id_card_back',
      );

      final selfieFrontUrl = await KycDocumentService.upload(
        file: File(selfieFrontPath.value),
        userId: userId,
        documentType: 'selfie_front',
        metadata: {...selfieLivenessMetadata, 'angle': 'front'},
      );
      final selfieRightUrl = await KycDocumentService.upload(
        file: File(selfieRightPath.value),
        userId: userId,
        documentType: 'selfie_right',
        metadata: {...selfieLivenessMetadata, 'angle': 'right'},
      );
      final selfieLeftUrl = await KycDocumentService.upload(
        file: File(selfieLeftPath.value),
        userId: userId,
        documentType: 'selfie_left',
        metadata: {...selfieLivenessMetadata, 'angle': 'left'},
      );

      await SupabaseService.client
          .from('kyc_documents')
          .delete()
          .eq('user_id', userId)
          .eq('status', 'pending');

      await SupabaseService.client.from('kyc_documents').insert([
        {
          'user_id': userId,
          'document_type': 'id_card_front',
          'document_url': frontUrl,
          'status': 'pending',
        },
        {
          'user_id': userId,
          'document_type': 'id_card_back',
          'document_url': backUrl,
          'status': 'pending',
        },
        {
          'user_id': userId,
          'document_type': 'selfie_front',
          'document_url': selfieFrontUrl,
          'status': 'pending',
          'metadata': {...selfieLivenessMetadata, 'angle': 'front'},
        },
        {
          'user_id': userId,
          'document_type': 'selfie_right',
          'document_url': selfieRightUrl,
          'status': 'pending',
          'metadata': {...selfieLivenessMetadata, 'angle': 'right'},
        },
        {
          'user_id': userId,
          'document_type': 'selfie_left',
          'document_url': selfieLeftUrl,
          'status': 'pending',
          'metadata': {...selfieLivenessMetadata, 'angle': 'left'},
        },
      ]);

      final result = await SupabaseService.client.rpc(
        'fn_submit_kyc',
        params: {'p_full_name': nameController.text.trim()},
      );

      final payload = result is Map ? Map<String, dynamic>.from(result) : null;
      if (payload?['success'] != true) {
        throw Exception(payload?['message'] ?? 'KYC submission failed');
      }

      await HomeController.to.fetchProfile();
      await HomeController.to.fetchDashboard();

      Get.offAllNamed(Routes.home);
      Get.snackbar(
        'kyc_success_title'.tr,
        'kyc_success_desc'.tr,
        backgroundColor: AppColors.softGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'KycController',
        method: 'submitKyc',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      Get.snackbar(
        'error'.tr,
        '${'kyc_upload_error'.tr}\n${KycDocumentService.readableError(e)}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
