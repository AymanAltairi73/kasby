import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../../models/ad_model.dart';

class AdController extends GetxController {
  static AdController get to => Get.find();

  final ads = <Ad>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'AdController',
      method: 'onInit',
      feature: 'Home',
      status: 'INFO',
    );
    super.onInit();
    fetchAds();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'AdController',
      method: 'onClose',
      feature: 'Home',
      status: 'INFO',
    );
    super.onClose();
  }

  Future<void> fetchAds() async {
    isLoading.value = true;
    final stopwatch = Stopwatch()..start();
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
      SafeGetx.debugTrace(
        className: 'AdController',
        method: 'fetchAds',
        feature: 'Home',
        status: 'SUCCESS',
        params: {'count': ads.length},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AdController',
        method: 'fetchAds',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
