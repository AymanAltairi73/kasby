import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/qr_payment/presentation/controllers/qr_payment_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Ensure controller exists
    if (!Get.isRegistered<QrPaymentController>()) {
      Get.put(QrPaymentController());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Scanner Layer
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  QrPaymentController.to.handleScanResult(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // 2. Overlay Layer
          _buildOverlay(),

          // 3. Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: Icons.close_rounded,
                  onTap: () => Get.back(),
                ),
                Text(
                  'scan_qr'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildActionButton(
                  icon: Icons.flash_on_rounded,
                  onTap: () => _scannerController.toggleTorch(),
                ),
              ],
            ),
          ),

          // 4. Instructions
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

  Widget _buildOverlay() {
    return Stack(
      children: [
        // Darkened area around the scanner box
        ScannerOverlayBackground(
          overlayColor: Colors.black.withValues(alpha: 0.5),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
        ),
        
        // The scanning frame
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  children: [
                    // Corner Borders
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),

                    // Scanning Line
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Positioned(
                          top: _animationController.value * 260,
                          left: 20,
                          right: 20,
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
                                  color: AppColors.darkGold.withValues(alpha: 0.5),
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    bool isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    bool isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: AppColors.darkGold, width: 4) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: AppColors.darkGold, width: 4) : BorderSide.none,
            left: isLeft ? BorderSide(color: AppColors.darkGold, width: 4) : BorderSide.none,
            right: !isLeft ? BorderSide(color: AppColors.darkGold, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onTap}) {
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

class ScannerOverlayBackground extends StatelessWidget {
  final Color overlayColor;
  final Widget child;

  const ScannerOverlayBackground({super.key, required this.overlayColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: overlayColor,
      ),
      child: child,
    );
  }
}
