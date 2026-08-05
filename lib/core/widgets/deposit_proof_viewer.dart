import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

/// Full-screen deposit proof viewer with zoom and download.
class DepositProofViewer extends StatefulWidget {
  final String imageUrl;
  final String? title;

  const DepositProofViewer({super.key, required this.imageUrl, this.title});

  static Future<void> show(
    BuildContext context,
    String imageUrl, {
    String? title,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => DepositProofViewer(imageUrl: imageUrl, title: title),
    );
  }

  @override
  State<DepositProofViewer> createState() => _DepositProofViewerState();
}

class _DepositProofViewerState extends State<DepositProofViewer> {
  bool _isDownloading = false;

  Future<void> _downloadProof() async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) throw Exception('Download failed');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/deposit_proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'deposit_proof'.tr),
      );
    } catch (_) {
      if (mounted) {
        Get.snackbar('error'.tr, 'download_failed'.tr);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.title ?? 'deposit_proof'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _isDownloading ? null : _downloadProof,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: Colors.grey.shade800,
                      highlightColor: Colors.grey.shade600,
                      child: Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'image_load_error'.tr,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: KasbyButton(
                text: 'close'.tr,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact proof thumbnail for agent operation cards.
class DepositProofThumbnail extends StatelessWidget {
  final String? proofUrl;
  final VoidCallback? onTap;

  const DepositProofThumbnail({super.key, this.proofUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (proofUrl == null || proofUrl!.trim().isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(height: 4),
            Text(
              'no_deposit_proof'.tr,
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap ?? () => DepositProofViewer.show(context, proofUrl!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: proofUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(height: 160, color: Colors.grey[300]),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 160,
                color: Colors.grey[200],
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'tap_to_preview'.tr,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
