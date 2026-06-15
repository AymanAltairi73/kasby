import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class QrPaymentController extends GetxController {
  static QrPaymentController get to => Get.find();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxBool isScanning = false.obs;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'QrPaymentController',
      method: 'onInit',
      feature: 'QrPayment',
      status: 'INFO',
    );
    super.onInit();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'QrPaymentController',
      method: 'onClose',
      feature: 'QrPayment',
      status: 'INFO',
    );
    _audioPlayer.dispose();
    super.onClose();
  }

  void _log(String msg, {required String method, bool isError = false, Object? error, StackTrace? stack, Map<String, Object?>? params}) {
    SafeGetx.debugTrace(
      className: 'QrPaymentController',
      method: method,
      feature: 'QrPayment',
      status: isError ? 'ERROR' : 'INFO',
      message: msg,
      params: params,
      error: error,
      stackTrace: stack,
    );
  }

  /// Generates the standard JSON metadata for a user's receive QR
  String generateUserQrData({double? amount, String? type = 'transfer'}) {
    final profile = HomeController.to.profile.value;
    if (profile == null) return '';

    final data = {
      'type': type,
      'user_id': profile.id,
      'referral_code': ReferralService.formatDisplayCode(profile.referralCode),
      'name': profile.fullName,
      if (amount != null && amount > 0) 'amount': amount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return jsonEncode(data);
  }

  /// Plays the scan success sound and triggers haptic feedback
  Future<void> playScanFeedback() async {
    try {
      HapticFeedback.heavyImpact();
      await _audioPlayer.play(AssetSource('sounds/scan_success.mp3'));
    } catch (e) {
      _log('Error playing feedback', method: 'playScanFeedback', isError: true, error: e);
    }
  }

  /// Maximum age of a QR code before it's considered expired (15 minutes)
  static const _qrMaxAgeMs = 15 * 60 * 1000;

  /// Parses the scanned QR string and returns a map if valid
  Map<String, dynamic>? parseQrData(String rawData) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawData);
      
      if (!data.containsKey('user_id') || !data.containsKey('type')) {
        _log('Invalid QR structure', method: 'parseQrData', isError: true);
        return null;
      }

      final timestamp = data['timestamp'] as int?;
      if (timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > _qrMaxAgeMs) {
          _log('QR code expired', method: 'parseQrData', isError: true, params: {'ageMs': age});
          AppSnack.error('expired_qr'.tr, 'expired_qr_desc'.tr);
          return null;
        }
      }

      return data;
    } catch (e) {
      _log('Error parsing QR data', method: 'parseQrData', isError: true, error: e);
      return null;
    }
  }

  /// Process the scanned data and navigate to transfer for payment.
  /// Returns true when navigation to transfer succeeds.
  Future<bool> handleScanResult(String rawData) async {
    SafeGetx.debugTrace(
      className: 'QrPaymentController',
      method: 'handleScanResult',
      feature: 'QrPayment',
      status: 'INFO',
    );
    if (isScanning.value) return false;
    isScanning.value = true;

    try {
      final data = parseQrData(rawData);
      if (data == null) {
        AppSnack.error('invalid_qr'.tr, 'invalid_qr_desc'.tr);
        return false;
      }

      final myId = HomeController.to.profile.value?.id;
      final scannedUserId = data['user_id']?.toString();
      if (myId != null && scannedUserId == myId) {
        AppSnack.error('error'.tr, 'transfer_to_self_error'.tr);
        return false;
      }

      await playScanFeedback();

      final referralCode = ReferralService.normalizeCode(
        data['referral_code']?.toString() ?? scannedUserId ?? '',
      );
      final amount = data['amount'];

      await Get.offNamed(
        Routes.transfer,
        arguments: {
          'receiver_id': referralCode,
          'amount': amount?.toString(),
          'funds_mode': true,
          'from_qr_scan': true,
        },
      );
      return true;
    } catch (e, stack) {
      _log('Error handling scan result', method: 'handleScanResult', isError: true, error: e, stack: stack);
      AppSnack.error('error'.tr, 'invalid_qr_desc'.tr);
      return false;
    } finally {
      isScanning.value = false;
    }
  }
}
