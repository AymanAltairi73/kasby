import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/qr_payment/presentation/controllers/qr_payment_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/tour/tour_target_keys.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/routes/app_routes.dart';

class MyQrView extends StatefulWidget {
  const MyQrView({super.key});

  @override
  State<MyQrView> createState() => _MyQrViewState();
}

class _MyQrViewState extends State<MyQrView> {
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  double? _customAmount;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'MyQrView',
      method: 'initState',
      feature: 'QrPayment',
      status: 'INFO',
    );
    if (!Get.isRegistered<QrPaymentController>()) {
      Get.put(QrPaymentController());
    }
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'MyQrView',
      method: 'dispose',
      feature: 'QrPayment',
      status: 'INFO',
    );
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final profile = HomeController.to.profile.value;
      final isVerified = HomeController.to.kycStatus == 'verified';

      if (!isVerified) {
        return Scaffold(
          appBar: AppBar(
            title: Text('my_qr'.tr),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Get.back(),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 72,
                    color: AppColors.darkGold.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'kyc_verification'.tr,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'verified_account_required'.tr,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  KasbyButton(
                    text: 'verify_now'.tr,
                    onPressed: () => Get.toNamed(Routes.kyc),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return _buildQrContent(context, profile);
    });
  }

  Widget _buildQrContent(BuildContext context, profile) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_qr'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 1. User Profile Info
            Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.darkGold.withValues(alpha: 0.1),
                  child: Icon(Icons.person_rounded, size: 40, color: AppColors.darkGold),
                ),
                const SizedBox(height: 12),
                Text(
                  profile?.fullName ?? '...',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  profile?.referralCode ?? '...',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.1),

            const SizedBox(height: 40),

            // 2. QR Card
            RepaintBoundary(
            key: _qrKey,
            child: KeyedSubtree(
              key: TourTargetKeys.qrReceive,
              child: GlassCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkGold.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: QrPaymentController.to.generateUserQrData(amount: _customAmount),
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (_customAmount != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.darkGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${_customAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGold,
                        ),
                      ),
                    ).animate().scale(),
                  ],
                ],
              ),
            ),
            ),
            ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),

            const SizedBox(height: 40),

            // 3. Amount Generator
            KasbyTextField(
              label: 'generate_amount_qr'.tr,
              hint: 'enter_amount'.tr,
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.darkGold),
              onChanged: (val) {
                setState(() {
                  _customAmount = double.tryParse(val);
                });
              },
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),

            // 4. Actions
            Row(
              children: [
                Expanded(
                  child: KeyedSubtree(
                    key: TourTargetKeys.qrShare,
                    child: KasbyButton(
                      text: 'share_qr'.tr,
                      onPressed: _shareQr,
                      isSecondary: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KasbyButton(
                    text: 'save_qr'.tr,
                    onPressed: _saveQr,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Future<File?> _captureQrImage() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kasby_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (e) {
      return null;
    }
  }

  Future<void> _shareQr() async {
    final stopwatch = Stopwatch()..start();
    try {
      final file = await _captureQrImage();
      if (file == null) {
        SafeGetx.debugTrace(
          className: 'MyQrView',
          method: '_shareQr',
          feature: 'QrPayment',
          status: 'WARN',
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'QR capture failed',
        );
        AppSnack.error('error'.tr, 'qr_capture_error'.tr);
        return;
      }
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'qr_share_text'.tr,
      ));
      SafeGetx.debugTrace(
        className: 'MyQrView',
        method: '_shareQr',
        feature: 'QrPayment',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'MyQrView',
        method: '_shareQr',
        feature: 'QrPayment',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _saveQr() async {
    final stopwatch = Stopwatch()..start();
    try {
      final file = await _captureQrImage();
      if (file == null) {
        SafeGetx.debugTrace(
          className: 'MyQrView',
          method: '_saveQr',
          feature: 'QrPayment',
          status: 'WARN',
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'QR capture failed',
        );
        AppSnack.error('error'.tr, 'qr_capture_error'.tr);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final savedFile = await file.copy('${dir.path}/kasby_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      if (savedFile.existsSync()) {
        SafeGetx.debugTrace(
          className: 'MyQrView',
          method: '_saveQr',
          feature: 'QrPayment',
          status: 'SUCCESS',
          durationMs: stopwatch.elapsedMilliseconds,
        );
        AppSnack.success('success'.tr, 'qr_saved'.tr);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'MyQrView',
        method: '_saveQr',
        feature: 'QrPayment',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }
}
