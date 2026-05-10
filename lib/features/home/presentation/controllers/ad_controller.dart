import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import '../../models/ad_model.dart';

class AdController extends GetxController {
  static AdController get to => Get.find();

  final ads = <Ad>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAds();
  }

  Future<void> fetchAds() async {
    isLoading.value = true;
    try {
      // Fetch only active ads that haven't expired
      final now = DateTime.now().toIso8601String();
      final response = await SupabaseService.client
          .from('ads')
          .select()
          .eq('is_active', true)
          .or('expires_at.is.null,expires_at.gt.$now')
          .order('priority', ascending: false);

      ads.assignAll((response as List).map((e) => Ad.fromSupabase(e)).toList());
    } catch (e) {
      debugPrint('Error fetching ads: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
