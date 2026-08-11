import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/tour/tour_feature_host.dart';
import 'package:kasby/core/tour/tour_ids.dart';
import 'package:kasby/core/tour/tour_target_keys.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/qr_payment/presentation/controllers/qr_payment_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _scanWindowSize = 260;

  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  late AnimationController _animationController;
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SafeGetx.debugTrace(
      className: 'QrScannerView',
      method: 'initState',
      feature: 'QrPayment',
      status: 'INFO',
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (!Get.isRegistered<QrPaymentController>()) {
      Get.put(QrPaymentController());
    }

    _barcodeSubscription = _scannerController.barcodes.listen(_onBarcode);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startScanner());
      if (mounted) TourFeatureHost.scheduleForRoute(context, TourId.qr);
    });
  }

  Future<void> _startScanner() async {
    if (!mounted) return;
    try {
      await _scannerController.start();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'QrScannerView',
        method: '_startScanner',
        feature: 'QrPayment',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_isProcessing || QrPaymentController.to.isScanning.value) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;

      _isProcessing = true;
      await _scannerController.stop();

      final success = await QrPaymentController.to.handleScanResult(value);
      if (!success && mounted) {
        _isProcessing = false;
        await _startScanner();
      }
      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _barcodeSubscription ??= _scannerController.barcodes.listen(_onBarcode);
        unawaited(_startScanner());
      case AppLifecycleState.inactive:
        unawaited(_barcodeSubscription?.cancel());
        _barcodeSubscription = null;
        unawaited(_scannerController.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_barcodeSubscription?.cancel());
    _barcodeSubscription = null;
    _animationController.dispose();
    unawaited(_scannerController.dispose());
    SafeGetx.debugTrace(
      className: 'QrScannerView',
      method: 'dispose',
      feature: 'QrPayment',
      status: 'INFO',
    );
    super.dispose();
  }

  Rect _scanWindow(Size size) {
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: _scanWindowSize,
      height: _scanWindowSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            fit: BoxFit.cover,
            scanWindow: _scanWindow(MediaQuery.sizeOf(context)),
            errorBuilder: (context, error) {
              return _buildCameraErrorState(error);
            },
            placeholderBuilder: (context) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.darkGold),
                    const SizedBox(height: 16),
                    Text(
                      'scan_qr'.tr,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            },
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(
                scanWindowSize: _scanWindowSize,
                overlayColor: Colors.black.withValues(alpha: 0.55),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: KeyedSubtree(
                key: TourTargetKeys.qrScanner,
                child: SizedBox(
                  width: _scanWindowSize,
                  height: _scanWindowSize,
                  child: Stack(
                    children: [
                      _buildCorner(Alignment.topLeft),
                      _buildCorner(Alignment.topRight),
                      _buildCorner(Alignment.bottomLeft),
                      _buildCorner(Alignment.bottomRight),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Positioned(
                            top: _animationController.value * _scanWindowSize,
                            left: 16,
                            right: 16,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.darkGold.withValues(alpha: 0),
                                    AppColors.darkGold,
                                    AppColors.darkGold.withValues(alpha: 0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.darkGold.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: Icons.close_rounded,
                  onTap: () => Get.safeBack(),
                ),
                Text(
                  'scan_qr'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.flash_on_rounded,
                      onTap: () => _scannerController.toggleTorch(),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.qr_code_2_rounded,
                      onTap: () => Get.toNamed(Routes.myQr),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 80,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'qr_transfer_desc'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? BorderSide(color: AppColors.darkGold, width: 4)
                : BorderSide.none,
            bottom: !isTop
                ? BorderSide(color: AppColors.darkGold, width: 4)
                : BorderSide.none,
            left: isLeft
                ? BorderSide(color: AppColors.darkGold, width: 4)
                : BorderSide.none,
            right: !isLeft
                ? BorderSide(color: AppColors.darkGold, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraErrorState(MobileScannerException error) {
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionDenied
                  ? Icons.no_photography_rounded
                  : Icons.camera_alt_outlined,
              color: Colors.white54,
              size: 56,
            ),
            const SizedBox(height: 20),
            Text(
              isPermissionDenied
                  ? 'camera_permission_required'.tr
                  : 'unknown_error'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.errorDetails?.message ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: Text('app_error_retry'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanWindowSize;
  final Color overlayColor;

  _ScannerOverlayPainter({
    required this.scanWindowSize,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanWindowSize,
      height: scanWindowSize,
    );

    final overlayPaint = Paint()..color = overlayColor;
    final background = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)));

    canvas.drawPath(
      Path.combine(PathOperation.difference, background, hole),
      overlayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindowSize != scanWindowSize ||
        oldDelegate.overlayColor != overlayColor;
  }
}
