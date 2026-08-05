import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kasby/core/models/kasby_receipt_data.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/widgets/transaction_receipt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Generates enterprise PDF receipts with Arabic/RTL support.
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

    final regularFontData = await rootBundle.load(
      'assets/fonts/IBM_Plex_Sans_Arabic/IBMPlexSansArabic-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/IBM_Plex_Sans_Arabic/IBMPlexSansArabic-Bold.ttf',
    );

    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);
    final baseStyle = pw.TextStyle(font: regularFont, fontSize: 11);
    final titleStyle = pw.TextStyle(font: boldFont, fontSize: 20);
    final headerStyle = pw.TextStyle(font: boldFont, fontSize: 14);

    final logoBytes = (await rootBundle.load(
      'assets/images/logo.png',
    )).buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

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
      if (data.invitationCode != null && data.invitationCode!.isNotEmpty)
        MapEntry('invitation_code'.tr, data.invitationCode!),
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
        MapEntry('notes'.tr, data.notes!),
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: _isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(logo, width: 42, height: 42),
                    pw.SizedBox(width: 12),
                    pw.Text('KASBY', style: titleStyle),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'transaction_receipt'.tr,
                  style: headerStyle,
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 12),
                for (final row in rows) ...[
                  _pdfRow(row.key, row.value, baseStyle, boldFont),
                  pw.SizedBox(height: 6),
                ],
                if (data.qrPayload != null && data.qrPayload!.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: data.qrPayload!,
                      width: 96,
                      height: 96,
                    ),
                  ),
                ],
                pw.Spacer(),
                pw.Text(
                  'thank_you_note'.tr,
                  style: baseStyle,
                  textAlign: pw.TextAlign.center,
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
    pw.Font boldFont,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Text(label, style: baseStyle.copyWith(font: boldFont)),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            value,
            style: baseStyle,
            textAlign: _isRtl ? pw.TextAlign.left : pw.TextAlign.right,
          ),
        ),
      ],
    );
  }
}
