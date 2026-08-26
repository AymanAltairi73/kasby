import 'package:get/get.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/services/sensitive_operation_guard.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/widgets/transaction_pin_sheet.dart';
import 'package:local_auth/local_auth.dart';

/// Enterprise financial step-up: Biometric (priority 1) OR server-verified Transaction PIN (priority 2).
///
/// OTP is intentionally NOT used for wallet operations. Account recovery flows keep OTP separately.
class TransactionAuthService extends GetxService {
  static TransactionAuthService get to => Get.find();

  static const int pinLength = 6;
  static const int lockoutMinutes = 15;

  final LocalAuthentication _localAuth = LocalAuthentication();

  void _log(
    String method,
    String message, {
    String status = 'INFO',
    Map<String, Object?>? params,
    Object? error,
  }) {
    SafeGetx.debugTrace(
      className: 'TransactionAuthService',
      method: method,
      feature: 'Security',
      status: status,
      message: message,
      params: params,
      error: error,
    );
  }

  /// Confirms identity before a financial mutation.
  Future<bool> requireConfirmation({required String purpose}) async {
    if (!SupabaseService.isLoggedIn) {
      AppSnack.error('error'.tr, 'session_expired'.tr);
      return false;
    }

    if (await _tryBiometric(purpose: purpose)) {
      return true;
    }

    return _requireTransactionPin(purpose: purpose);
  }

  Future<bool> _tryBiometric({required String purpose}) async {
    if (Get.isRegistered<SessionService>()) {
      SessionService.to.notifyBiometricPromptStarted();
    }
    try {
      final canBio = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canBio && !supported) {
        _log(
          '_tryBiometric',
          'Biometrics unavailable; falling back to PIN',
          params: {'purpose': purpose},
        );
        return false;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'transaction_biometric_reason'.tr,
        persistAcrossBackgrounding: true,
        biometricOnly: canBio,
      );

      if (ok) {
        _log(
          'requireConfirmation',
          'Biometric confirmed',
          params: {'purpose': purpose},
        );
      }
      return ok;
    } catch (e, stack) {
      _log(
        '_tryBiometric',
        'Biometric error',
        status: 'ERROR',
        params: {'purpose': purpose},
        error: e,
      );
      SafeGetx.debugTrace(
        className: 'TransactionAuthService',
        method: '_tryBiometric',
        feature: 'Security',
        status: 'ERROR',
        stackTrace: stack,
      );
      return false;
    } finally {
      if (Get.isRegistered<SessionService>()) {
        SessionService.to.notifyBiometricPromptEnded();
      }
    }
  }

  Future<Map<String, dynamic>> _pinStatus() async {
    try {
      final raw = await SupabaseService.client.rpc('fn_transaction_pin_status');
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (e) {
      _log('_pinStatus', 'Status RPC failed', status: 'WARN', error: e);
    }
    return {'has_pin': false, 'locked': false};
  }

  Future<bool> _requireTransactionPin({required String purpose}) async {
    final status = await _pinStatus();
    if (status['locked'] == true) {
      final until = status['locked_until']?.toString();
      AppSnack.error(
        'error'.tr,
        until != null && until.isNotEmpty
            ? 'transaction_pin_locked_until'.trParams({'time': until})
            : 'transaction_pin_locked'.tr,
      );
      return false;
    }

    if (status['has_pin'] != true) {
      final created = await _setupTransactionPin();
      if (!created) return false;
    }

    while (true) {
      final pin = await TransactionPinSheet.show(
        title: 'transaction_pin_title'.tr,
        subtitle: 'transaction_pin_subtitle'.tr,
      );
      if (pin == null || pin.length != pinLength) {
        return false;
      }

      final verify = await _verifyPinOnServer(pin);
      if (verify['success'] == true) {
        _log(
          'requireConfirmation',
          'Transaction PIN confirmed',
          params: {'purpose': purpose},
        );
        return true;
      }

      if (verify['locked'] == true) {
        AppSnack.error('error'.tr, 'transaction_pin_locked'.tr);
        return false;
      }

      final remaining = verify['attempts_remaining'];
      AppSnack.error(
        'error'.tr,
        remaining is num
            ? 'transaction_pin_wrong'.trParams({'count': '$remaining'})
            : 'transaction_pin_invalid'.tr,
      );

      if (verify['retry'] != true) {
        return false;
      }
    }
  }

  /// Resets transaction PIN after OTP identity verification (when PIN already exists).
  Future<bool> changeTransactionPin() async {
    if (!SupabaseService.isLoggedIn) {
      AppSnack.error('error'.tr, 'session_expired'.tr);
      return false;
    }

    final status = await _pinStatus();
    if (status['has_pin'] == true) {
      final otpOk = await SensitiveOperationGuard.requirePhoneOtp(
        purpose: 'transaction_pin_reset',
      );
      if (!otpOk) return false;
    }

    return _setupTransactionPin(showSuccessOnCreate: true);
  }

  Future<bool> _setupTransactionPin({bool showSuccessOnCreate = false}) async {
    final pin = await TransactionPinSheet.show(
      title: 'transaction_pin_setup_title'.tr,
      subtitle: 'transaction_pin_setup_subtitle'.tr,
    );
    if (pin == null || pin.length != pinLength) return false;

    final confirm = await TransactionPinSheet.show(
      title: 'transaction_pin_confirm_title'.tr,
      subtitle: 'transaction_pin_confirm_subtitle'.tr,
    );
    if (confirm != pin) {
      AppSnack.error('error'.tr, 'transaction_pin_mismatch'.tr);
      return false;
    }

    final result = await _setPinOnServer(pin);
    if (result['success'] == true) {
      if (showSuccessOnCreate) {
        AppSnack.success('success'.tr, 'transaction_pin_change_success'.tr);
      } else {
        AppSnack.success('success'.tr, 'transaction_pin_setup_success'.tr);
      }
      return true;
    }

    AppSnack.error(
      'error'.tr,
      result['error']?.toString() ?? 'transaction_pin_setup_failed'.tr,
    );
    return false;
  }

  Future<Map<String, dynamic>> _setPinOnServer(String pin) async {
    try {
      final raw = await SupabaseService.client.rpc(
        'fn_set_transaction_pin',
        params: {'p_pin': pin},
      );
      return raw is Map ? Map<String, dynamic>.from(raw) : {'success': false};
    } catch (e) {
      _log('_setPinOnServer', 'Failed', status: 'ERROR', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _verifyPinOnServer(String pin) async {
    try {
      final raw = await SupabaseService.client.rpc(
        'fn_verify_transaction_pin',
        params: {'p_pin': pin},
      );
      return raw is Map ? Map<String, dynamic>.from(raw) : {'success': false};
    } catch (e) {
      _log('_verifyPinOnServer', 'Failed', status: 'ERROR', error: e);
      return {'success': false, 'error': e.toString(), 'retry': false};
    }
  }
}
