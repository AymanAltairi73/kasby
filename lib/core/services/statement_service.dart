import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Generates and shares enterprise PDF account statements with full RTL/Arabic support.
class StatementService {
  StatementService._();

  static bool get _isRtl => Get.locale?.languageCode == 'ar';

  static Future<void> generateAndShare({
    required String accountName,
    required String accountEmail,
    required List<TransactionModel> transactions,
    required DateTime from,
    required DateTime to,
    String Function(double)? formatAmount,
  }) async {
    return SafeGetx.traceAsync(
      className: 'StatementService',
      method: 'generateAndShare',
      feature: 'Wallet',
      params: {'count': transactions.length},
      operation: () async {
        try {
          // 1. Load Fonts
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

          // 2. Load Logo
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

          final doc = pw.Document(
            theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          );

          final df = DateFormat('yyyy-MM-dd');
          final dfFull = DateFormat('yyyy-MM-dd HH:mm');
          final formatter = formatAmount ?? _defaultMoney;
          final textDirection =
              _isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

          // 3. Filter Transactions
          final filtered =
              transactions.where((t) {
                final d = t.createdAt;
                if (d == null) return false;
                return !d.isBefore(from) &&
                    !d.isAfter(to.add(const Duration(days: 1)));
              }).toList()..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                  a.createdAt ?? DateTime(0),
                ),
              );

          double inflow = 0;
          double outflow = 0;
          for (final t in filtered) {
            if (t.isDebit) {
              outflow += t.amount;
            } else {
              inflow += t.amount;
            }
          }

          doc.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              textDirection: textDirection,
              margin: const pw.EdgeInsets.all(32),
              header: (context) => _buildHeader(
                accountName,
                accountEmail,
                df.format(from),
                df.format(to),
                logoImage,
                regularFont,
                boldFont,
              ),
              footer: (context) => _buildFooter(
                context,
                regularFont,
              ),
              build: (context) => [
                pw.SizedBox(height: 16),
                _buildSummaryCard(
                  formatter(inflow),
                  formatter(outflow),
                  formatter(inflow - outflow),
                  regularFont,
                  boldFont,
                ),
                pw.SizedBox(height: 16),
                if (filtered.isEmpty)
                  _buildEmptyState(regularFont)
                else
                  _buildTable(filtered, dfFull, formatter, regularFont, boldFont),
                pw.SizedBox(height: 24),
              ],
            ),
          );

          final bytes = await doc.save();
          final filename =
              'kasby_statement_${df.format(from)}_${df.format(to)}.pdf';
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);

          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: 'application/pdf')],
              subject: _isRtl ? 'كشف حساب كاسبي' : 'Kasby Account Statement',
            ),
          );
        } catch (e, stackTrace) {
          SafeGetx.debugTrace(
            className: 'StatementService',
            method: 'generateAndShare',
            feature: 'Wallet',
            status: 'FAILED',
            error: e,
            stackTrace: stackTrace,
          );
          AppSnack.error('error'.tr, 'pdf_error'.tr);
        }
      },
    );
  }

  static pw.Widget _buildHeader(
    String name,
    String email,
    String from,
    String to,
    pw.MemoryImage? logo,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              children: [
                if (logo != null)
                  pw.Container(
                    width: 38,
                    height: 38,
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logo),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'KASBY',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 22,
                        color: PdfColor.fromInt(0xFFC9A24D),
                      ),
                    ),
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
                'statements'.tr,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 12,
                  color: PdfColor.fromInt(0xFF8C6B1C),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColor.fromInt(0xFFC9A24D), thickness: 1.5),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name.isNotEmpty ? name : 'account'.tr,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    color: PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
                if (email.isNotEmpty)
                  pw.Text(
                    email,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
            pw.Text(
              '${'statement_period'.tr}: $from — $to',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCard(
    String inflow,
    String outflow,
    String net,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    pw.Widget cell(String label, String value, PdfColor textColor, PdfColor bgColor) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            color: bgColor,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                value,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        cell(
          _isRtl ? 'إجمالي الإيداعات' : 'Total Inflow',
          inflow,
          PdfColor.fromInt(0xFF16A34A),
          PdfColor.fromInt(0xFFF0FDF4),
        ),
        cell(
          _isRtl ? 'إجمالي السحوبات' : 'Total Outflow',
          outflow,
          PdfColor.fromInt(0xFFDC2626),
          PdfColor.fromInt(0xFFFEF2F2),
        ),
        cell(
          _isRtl ? 'صافي التدفقات' : 'Net Flow',
          net,
          PdfColor.fromInt(0xFFC9A24D),
          PdfColor.fromInt(0xFFFFFBEB),
        ),
      ],
    );
  }

  static pw.Widget _buildEmptyState(pw.Font regularFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(32),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
      ),
      child: pw.Text(
        'no_transactions'.tr,
        style: pw.TextStyle(
          font: regularFont,
          fontSize: 12,
          color: PdfColors.grey600,
        ),
      ),
    );
  }

  static pw.Widget _buildTable(
    List<TransactionModel> txns,
    DateFormat df,
    String Function(double) money,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    final headers = [
      'date'.tr,
      'type'.tr,
      'status'.tr,
      'amount'.tr,
    ];

    final rows = txns.map((t) {
      final typeLabel = t.localizedTypeLabel;
      final statusLabel = t.localizedStatusLabel;
      return [
        t.createdAt != null ? df.format(t.createdAt!) : '--',
        typeLabel,
        statusLabel,
        t.formattedAmount,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: 10,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF1E293B),
      ),
      cellStyle: pw.TextStyle(
        font: regularFont,
        fontSize: 9,
        color: PdfColor.fromInt(0xFF0F172A),
      ),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      oddRowDecoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
      ),
      tableDirection: _isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font regularFont) {
    final pageStr = _isRtl
        ? 'صفحة ${context.pageNumber} من ${context.pagesCount}'
        : 'Page ${context.pageNumber} of ${context.pagesCount}';

    return pw.Column(
      children: [
        pw.Divider(color: PdfColor.fromInt(0xFFE2E8F0)),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _isRtl
                  ? 'كاسبي — منصة الاستثمار الرقمية · تقرير مالي إلكتروني'
                  : 'Kasby — Digital Investment Platform · Official E-Statement',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              pageStr,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _defaultMoney(double v) => '\$${v.toStringAsFixed(2)}';
}

