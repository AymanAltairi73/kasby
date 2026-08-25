import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kasby/core/models/kasby_receipt_data.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/widgets/transaction_receipt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Generates enterprise PDF receipts with Arabic/RTL support and professional branding.
class ReceiptExportService {
  ReceiptExportService._();

  static bool get _isRtl => Get.locale?.languageCode == 'ar';

  static Future<void> showReceiptSheet(KasbyReceiptData data) {
    SafeGetx.debugTrace(
      className: 'ReceiptExportService',
      method: 'showReceiptSheet',
      feature: 'Wallet',
      status: 'INFO',
      params: {
        'operationType': data.operationType,
        'txId': data.transactionId.length > 8
            ? '${data.transactionId.substring(0, 8)}...'
            : data.transactionId,
      },
    );
    return Get.bottomSheet(
      TransactionReceipt(data: data),
      isScrollControlled: true,
      backgroundColor: Get.theme.colorScheme.surface.withValues(alpha: 0),
      isDismissible: true,
      enableDrag: true,
    );
  }

  static Future<void> exportPdf(KasbyReceiptData data) async {
    SafeGetx.debugTrace(
      className: 'ReceiptExportService',
      method: 'exportPdf',
      feature: 'Wallet',
      status: 'INFO',
      params: {'operationType': data.operationType},
    );

    try {
      // 1. Load Arabic Fonts
      pw.Font regularFont;
      pw.Font boldFont;
      try {
        final regularData = await rootBundle.load(
          'assets/fonts/IBM_Plex_Sans_Arabic/IBMPlexSansArabic-Regular.ttf',
        );
        final boldData = await rootBundle.load(
          'assets/fonts/IBM_Plex_Sans_Arabic/IBMPlexSansArabic-Bold.ttf',
        );
        regularFont = pw.Font.ttf(regularData);
        boldFont = pw.Font.ttf(boldData);
      } catch (e) {
        regularFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
      }

      final baseStyle = pw.TextStyle(
        font: regularFont,
        fontSize: 10,
        color: PdfColor.fromInt(0xFF1E293B),
      );
      final boldStyle = pw.TextStyle(
        font: boldFont,
        fontSize: 10,
        color: PdfColor.fromInt(0xFF0F172A),
      );
      final titleStyle = pw.TextStyle(
        font: boldFont,
        fontSize: 22,
        color: PdfColor.fromInt(0xFFC9A24D),
      );
      final headerStyle = pw.TextStyle(
        font: boldFont,
        fontSize: 15,
        color: PdfColor.fromInt(0xFF0F172A),
      );

      // 2. Load Logo Image
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = (await rootBundle.load(
          'assets/images/logo5.png',
        )).buffer.asUint8List();
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {
        try {
          final fallbackBytes = (await rootBundle.load(
            'assets/images/logo.png',
          )).buffer.asUint8List();
          logoImage = pw.MemoryImage(fallbackBytes);
        } catch (_) {}
      }

      final textDirection =
          _isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
      );

      final rows = <MapEntry<String, String>>[
        MapEntry('operation_type'.tr, data.operationType.tr),
        MapEntry('transaction_id'.tr, data.transactionId),
        if (data.referenceNumber != null && data.referenceNumber!.isNotEmpty)
          MapEntry('reference'.tr, data.referenceNumber!),
        MapEntry(
          'date'.tr,
          intl.DateFormat('yyyy-MM-dd HH:mm').format(data.date),
        ),
        if (data.userName != null && data.userName!.isNotEmpty)
          MapEntry('full_name'.tr, data.userName!),
        if (data.userId != null && data.userId!.isNotEmpty)
          MapEntry('user_id'.tr, data.userId!),
        if (data.recipientName != null && data.recipientName!.isNotEmpty)
          MapEntry('recipient'.tr, data.recipientName!),
        MapEntry('amount'.tr, _formatAmount(data.amount, data.currency)),
        MapEntry('status'.tr, data.status.tr),
        if (data.walletBalanceAfter != null)
          MapEntry(
            'wallet_balance_after'.tr,
            _formatAmount(data.walletBalanceAfter!, data.currency),
          ),
        if (data.notes != null && data.notes!.isNotEmpty)
          MapEntry('description'.tr, data.notes!),
      ];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: textDirection,
          build: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Branded Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Row(
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 40,
                              height: 40,
                              margin: const pw.EdgeInsets.only(right: 12),
                              child: pw.Image(logoImage),
                            ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('KASBY', style: titleStyle),
                              pw.Text(
                                _isRtl
                                    ? 'منصة الاستثمار الرقمية'
                                    : 'Digital Investment Platform',
                                style: pw.TextStyle(
                                  font: regularFont,
                                  fontSize: 9,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFFFFBEB),
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(
                            color: PdfColor.fromInt(0xFFC9A24D),
                            width: 1,
                          ),
                        ),
                        child: pw.Text(
                          'transaction_receipt'.tr,
                          style: headerStyle.copyWith(
                            fontSize: 12,
                            color: PdfColor.fromInt(0xFF8C6B1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(color: PdfColor.fromInt(0xFFC9A24D), thickness: 1.5),
                  pw.SizedBox(height: 20),

                  // Amount Card
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'total_amount'.tr,
                          style: boldStyle.copyWith(fontSize: 12),
                        ),
                        pw.Text(
                          _formatAmount(data.amount, data.currency),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 22,
                            color: PdfColor.fromInt(0xFFC9A24D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Transaction Details List
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                    ),
                    child: pw.Column(
                      children: [
                        for (int i = 0; i < rows.length; i++) ...[
                          _pdfRow(rows[i].key, rows[i].value, baseStyle, boldStyle),
                          if (i < rows.length - 1)
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 6),
                              child: pw.Divider(
                                color: PdfColor.fromInt(0xFFF1F5F9),
                                thickness: 1,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),

                  if (data.qrPayload != null && data.qrPayload!.isNotEmpty) ...[
                    pw.SizedBox(height: 24),
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: data.qrPayload!,
                            width: 80,
                            height: 80,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _isRtl ? 'مسح للتحقق الرقمي' : 'Scan to Verify',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 8,
                              color: PdfColors.grey500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  pw.Spacer(),

                  // Footer
                  pw.Divider(color: PdfColor.fromInt(0xFFE2E8F0)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'securely_processed_by_kasby'.tr,
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Kasby Platform © ${DateTime.now().year}',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/receipt_${data.transactionId}.pdf');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'receipt_share_text'.tr,
        ),
      );
    } catch (e, stackTrace) {
      SafeGetx.debugTrace(
        className: 'ReceiptExportService',
        method: 'exportPdf',
        feature: 'Wallet',
        status: 'FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      AppSnack.error('error'.tr, 'pdf_error'.tr);
    }
  }

  static String _formatAmount(double amount, String currency) {
    if (currency.toUpperCase() == 'KSP') {
      return '${amount.toStringAsFixed(0)} KSP';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  static pw.Widget _pdfRow(
    String label,
    String value,
    pw.TextStyle baseStyle,
    pw.TextStyle boldStyle,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Text(label, style: baseStyle),
        ),
        pw.Expanded(
          flex: 6,
          child: pw.Text(
            value,
            style: boldStyle,
            textAlign: _isRtl ? pw.TextAlign.left : pw.TextAlign.right,
          ),
        ),
      ],
    );
  }
}

