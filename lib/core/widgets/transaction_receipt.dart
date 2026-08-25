import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/kasby_receipt_data.dart';
import 'package:kasby/core/services/receipt_export_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' as intl;

class TransactionReceipt extends StatefulWidget {
  final KasbyReceiptData data;

  const TransactionReceipt({super.key, required this.data});

  /// Legacy constructor for existing call sites.
  TransactionReceipt.legacy({
    super.key,
    required String transactionId,
    required String recipientName,
    required double amount,
    required String type,
    required DateTime date,
  }) : data = KasbyReceiptData.legacy(
         transactionId: transactionId,
         recipientName: recipientName,
         amount: amount,
         type: type,
         date: date,
       );

  @override
  State<TransactionReceipt> createState() => _TransactionReceiptState();
}

class _TransactionReceiptState extends State<TransactionReceipt> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'TransactionReceipt',
      method: 'initState',
      feature: 'Wallet',
      status: 'INFO',
      message: 'Receipt displayed',
      params: {
        'type': widget.data.operationType,
        'amount': widget.data.amount,
        'txId': widget.data.transactionId.length > 8
            ? '${widget.data.transactionId.substring(0, 8)}...'
            : widget.data.transactionId,
      },
    );
  }

  Future<void> _shareAsImage() async {
    SafeGetx.debugTrace(
      className: 'TransactionReceipt',
      method: '_shareAsImage',
      feature: 'Wallet',
      status: 'INFO',
    );
    setState(() => _isExporting = true);
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = File(
          '${directory.path}/receipt_${widget.data.transactionId}.png',
        );
        await imagePath.writeAsBytes(image);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(imagePath.path)],
            text: 'receipt_share_text'.tr,
          ),
        );
      }
    } catch (e, stackTrace) {
      SafeGetx.debugTrace(
        className: 'TransactionReceipt',
        method: '_shareAsImage',
        feature: 'Wallet',
        status: 'FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      AppSnack.error('error'.tr, 'share_error'.tr);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isExporting = true);
    try {
      await ReceiptExportService.exportPdf(widget.data);
      AppSnack.success('success'.tr, 'pdf_saved'.tr);
    } catch (e, stackTrace) {
      SafeGetx.debugTrace(
        className: 'TransactionReceipt',
        method: '_downloadPdf',
        feature: 'Wallet',
        status: 'FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      AppSnack.error('error'.tr, 'pdf_error'.tr);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('transaction_receipt'.tr),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (!_isExporting)
            IconButton(
              icon: const Icon(Icons.share_rounded, size: 20),
              onPressed: _shareAsImage,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Screenshot(
              controller: _screenshotController,
              child: _buildPremiumReceiptCard(isDark),
            ),
            const SizedBox(height: 40),
            if (_isExporting)
              Center(
                child: CircularProgressIndicator(color: AppColors.darkGold),
              )
            else
              Column(
                children: [
                  KasbyButton(
                    text: 'download_pdf'.tr,
                    onPressed: _downloadPdf,
                    icon: Icons.picture_as_pdf_rounded,
                  ),
                  const SizedBox(height: 16),
                  KasbyButton(
                    text: 'done'.tr,
                    onPressed: () => Get.back(),
                    isSecondary: true,
                  ),
                ],
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumReceiptCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with logo
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo5.png',
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'KASBY',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.softGreen.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.softGreen,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'payment_successful'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  intl.DateFormat(
                    'MMM dd, yyyy • hh:mm a',
                  ).format(widget.data.date),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Details section
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                _receiptRow(
                  'transaction_id'.tr,
                  widget.data.transactionId,
                  isDark,
                  canCopy: true,
                ),
                const SizedBox(height: 12),
                if (widget.data.recipientName != null &&
                    widget.data.recipientName!.isNotEmpty)
                  _receiptRow(
                    'recipient'.tr,
                    widget.data.recipientName!,
                    isDark,
                  ),
                if (widget.data.recipientName != null &&
                    widget.data.recipientName!.isNotEmpty)
                  const SizedBox(height: 12),
                _receiptRow(
                  'operation_type'.tr,
                  widget.data.operationType.tr,
                  isDark,
                ),
                if (widget.data.referenceNumber != null) ...[
                  const SizedBox(height: 12),
                  _receiptRow(
                    'reference'.tr,
                    widget.data.referenceNumber!,
                    isDark,
                  ),
                ],
                if (widget.data.walletBalanceAfter != null) ...[
                  const SizedBox(height: 12),
                  _receiptRow(
                    'wallet_balance_after'.tr,
                    '\$${widget.data.walletBalanceAfter!.toStringAsFixed(2)}',
                    isDark,
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(height: 1),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'total_amount'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      widget.data.currency.toUpperCase() == 'KSP'
                          ? '${widget.data.amount.toInt()} KSP'
                          : '\$${widget.data.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        color: AppColors.darkGold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Trust Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.softGreen.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: AppColors.softGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'securely_processed_by_kasby'.tr,
                        style: TextStyle(
                          color: AppColors.softGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'thank_you_note'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(
    String label,
    String value,
    bool isDark, {
    bool canCopy = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                softWrap: true,
              ),
            ),
            if (canCopy)
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                icon: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.darkGold,
                ),
                onPressed: () {
                  SafeGetx.debugTrace(
                    className: 'TransactionReceipt',
                    method: 'copyTransactionId',
                    feature: 'Wallet',
                    status: 'INFO',
                  );
                  Clipboard.setData(ClipboardData(text: value));
                  HapticFeedback.mediumImpact();
                  AppSnack.success('copied'.tr, 'transaction_id_copied'.tr);
                },
              ),
          ],
        ),
      ],
    );
  }
}
