import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class KycController extends GetxController {
  final ImagePicker _picker = ImagePicker();
  var currentStep = 0.obs;

  // Step 1: ID Type
  var selectedIdType = ''.obs;

  // Step 2: Personal Info
  final nameController = TextEditingController();
  final idNumberController = TextEditingController();
  final dobController = TextEditingController();
  var dob = ''.obs;

  // Step 3: Documents
  var frontImagePath = ''.obs;
  var backImagePath = ''.obs;

  // Step 4: Selfie
  var selfiePath = ''.obs;

  var isLoading = false.obs;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'KycController',
      method: 'onInit',
      feature: 'Profile',
      status: 'INFO',
    );
    super.onInit();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'KycController',
      method: 'onClose',
      feature: 'Profile',
      status: 'INFO',
    );
    nameController.dispose();
    idNumberController.dispose();
    dobController.dispose();
    super.onClose();
  }

  Future<void> pickImage(String type) async {
    final XFile? image = await _picker.pickImage(
      source: type == 'selfie' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      if (type == 'front') {
        frontImagePath.value = image.path;
      } else if (type == 'back') {
        backImagePath.value = image.path;
      } else if (type == 'selfie') {
        selfiePath.value = image.path;
      }
      SafeGetx.debugTrace(
        className: 'KycController',
        method: 'pickImage',
        feature: 'Profile',
        status: 'SUCCESS',
        params: {'type': type},
      );
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
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
    if (currentStep.value == 0) {
      if (selectedIdType.isEmpty) {
        Get.snackbar('error'.tr, 'select_id_type_error'.tr);
        return;
      }
    } else if (currentStep.value == 1) {
      if (nameController.text.trim().isEmpty ||
          idNumberController.text.trim().isEmpty ||
          dob.isEmpty) {
        Get.snackbar('error'.tr, 'fill_all_fields_error'.tr);
        return;
      }
    } else if (currentStep.value == 2) {
      if (frontImagePath.isEmpty || backImagePath.isEmpty) {
        Get.snackbar('error'.tr, 'upload_both_id_sides_error'.tr);
        return;
      }
    }

    if (currentStep.value < 3) {
      currentStep.value++;
    } else {
      if (selfiePath.isEmpty) {
        Get.snackbar('error'.tr, 'take_selfie_error'.tr);
        return;
      }
      submitKyc();
    }
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

    isLoading.value = true;
    final stopwatch = Stopwatch()..start();
    SafeGetx.debugTrace(
      className: 'KycController',
      method: 'submitKyc',
      feature: 'Profile',
      status: 'INFO',
    );

    try {
      final userId = SupabaseService.userId!;

      // Upload documents to Supabase Storage
      final frontUrl = await _uploadDocument(
        frontImagePath.value,
        'id_card_front',
        userId,
      );
      final backUrl = await _uploadDocument(
        backImagePath.value,
        'id_card_back',
        userId,
      );
      final selfieUrl = await _uploadDocument(
        selfiePath.value,
        'selfie',
        userId,
      );

      if (frontUrl == null || backUrl == null || selfieUrl == null) {
        throw Exception('Failed to upload one or more documents');
      }

      // Insert KYC document records into the database
      final documents = [
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
          'document_type': 'selfie',
          'document_url': selfieUrl,
          'status': 'pending',
        },
      ];

      await SupabaseService.client.from('kyc_documents').insert(documents);

      // Update profile KYC status to pending
      await SupabaseService.client
          .from('profiles')
          .update({
            'kyc_status': 'pending',
            'full_name': nameController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      isLoading.value = false;

      SafeGetx.debugTrace(
        className: 'KycController',
        method: 'submitKyc',
        feature: 'Profile',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
      );
      Get.offAllNamed(Routes.home);
      Get.snackbar(
        'kyc_success_title'.tr,
        'kyc_success_desc'.tr,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e, stack) {
      isLoading.value = false;
      SafeGetx.debugTrace(
        className: 'KycController',
        method: 'submitKyc',
        feature: 'Profile',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      Get.snackbar(
        'error'.tr,
        'kyc_upload_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.2),
      );
    }
  }

  /// Upload a document file to Supabase Storage.
  /// Returns the public URL of the uploaded file, or null if the path is empty.
  Future<String?> _uploadDocument(
    String filePath,
    String documentType,
    String userId,
  ) async {
    if (filePath.isEmpty) return null;

    final file = File(filePath);
    final fileName =
        '${userId}_${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'kyc/$userId/$fileName';

    await SupabaseService.client.storage
        .from('documents')
        .upload(storagePath, file);

    final publicUrl = SupabaseService.client.storage
        .from('documents')
        .getPublicUrl(storagePath);

    return publicUrl;
  }
}
