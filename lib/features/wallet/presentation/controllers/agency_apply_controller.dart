import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';

class AgencyApplyController extends GetxController {
  final isLoading = false.obs;
  final hasApplied = false.obs;
  final RxString applicationStatus = ''.obs;

  @override
  void onInit() {
    super.onInit();
    checkApplicationStatus();
  }

  Future<void> checkApplicationStatus() async {
    if (!SupabaseService.isLoggedIn) return;
    
    isLoading.value = true;
    try {
      final response = await SupabaseService.client
          .from('agent_applications')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();

      if (response != null) {
        hasApplied.value = true;
        applicationStatus.value = response['status'] ?? 'pending';
      }
    } catch (e) {
      debugPrint('Error checking agency application: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitApplication({
    required String fullName,
    required String phone,
    required String whatsapp,
    required String city,
    required String country,
    required String hasOffice,
  }) async {
    if (hasApplied.value) return;

    isLoading.value = true;
    try {
      await SupabaseService.client.from('agent_applications').insert({
        'user_id': SupabaseService.userId!,
        'full_name': fullName,
        'phone': phone,
        'city': city,
        'whatsapp': whatsapp,
        'country': country,
        'office_available': hasOffice.toLowerCase() == 'yes' || hasOffice == 'true',
        'status': 'pending',
      });

      hasApplied.value = true;
      applicationStatus.value = 'pending';
      
      HapticFeedback.heavyImpact();
      Get.snackbar(
        'success'.tr,
        'agency_apply_success'.tr,
        backgroundColor: AppColors.softGreen,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    } catch (e) {
      debugPrint('Error submitting agency application: $e');
      Get.snackbar(
        'error'.tr,
        'حدث خطأ أثناء إرسال الطلب. حاول مرة أخرى.',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
