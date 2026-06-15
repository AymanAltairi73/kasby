import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks remote app_config for minimum required version and prompts update if needed.
class AppVersionService extends GetxService {
  static AppVersionService get to => Get.find();

  static const String currentVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  final RxBool updateRequired = false.obs;

  Future<void> checkForUpdate() async {
    final stopwatch = Stopwatch()..start();
    SafeGetx.debugTrace(className: 'AppVersionService', method: 'checkForUpdate', feature: 'Core', status: 'INFO');
    try {
      final response = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'min_app_version')
          .maybeSingle();

      if (response == null || response['value'] == null) return;

      final minVersion = response['value'].toString().trim();
      if (minVersion.isEmpty) return;

      if (_isVersionLower(currentVersion, minVersion)) {
        updateRequired.value = true;
        SafeGetx.debugTrace(
          className: 'AppVersionService',
          method: 'checkForUpdate',
          feature: 'Core',
          status: 'WARN',
          params: {'current': currentVersion, 'minimum': minVersion},
          durationMs: stopwatch.elapsedMilliseconds,
        );
        _showForceUpdateDialog();
      } else {
        SafeGetx.debugTrace(
          className: 'AppVersionService',
          method: 'checkForUpdate',
          feature: 'Core',
          status: 'SUCCESS',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AppVersionService',
        method: 'checkForUpdate',
        feature: 'Core',
        status: 'WARN',
        message: 'Version check skipped',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }

  bool _isVersionLower(String current, String minimum) {
    final currentParts = current.split('.').map(int.parse).toList();
    final minimumParts = minimum.split('.').map(int.parse).toList();
    final length = currentParts.length > minimumParts.length
        ? currentParts.length
        : minimumParts.length;

    for (var i = 0; i < length; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final m = i < minimumParts.length ? minimumParts[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  void _showForceUpdateDialog() {
    if (Get.isDialogOpen == true) return;

    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('force_update_title'.tr),
          content: Text('force_update_message'.tr),
          actions: [
            TextButton(
              onPressed: _openStore,
              child: Text('force_update_button'.tr),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _openStore() async {
    const storeUrl = 'https://kasby.app/download';
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
