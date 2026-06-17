import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Generates and shares a PDF account statement (audit C11).
///
/// Dependency-light: reuses the already-bundled `pdf` + `printing` packages and
/// formats numbers/dates with `intl`. No backend changes required — operates on
/// the transactions already loaded in the app.
class StatementService {
  StatementService._();

  static Future<void> generateAndShare({
    required String accountName,
    required String accountEmail,
    required List<TransactionModel> transactions,
    required DateTime from,
    required DateTime to,
    String Function(double) formatAmount = _defaultMoney,
  }) async {
    return SafeGetx.traceAsync(
      className: 'StatementService',
      method: 'generateAndShare',
      feature: 'Wallet',
      params: {'count': transactions.length},
      operation: () async {
        final doc = pw.Document();
        final df = DateFormat('yyyy-MM-dd');
        final dfFull = DateFormat('yyyy-MM-dd HH:mm');

        final filtered = transactions.where((t) {
          final d = t.createdAt;
          if (d == null) return false;
          return !d.isBefore(from) &&
              !d.isAfter(to.add(const Duration(days: 1)));
        }).toList()
          ..sort((a, b) =>
              (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

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
            build: (context) => [
              _header(accountName, accountEmail, df.format(from),
                  df.format(to)),
              pw.SizedBox(height: 16),
              _summary(formatAmount(inflow), formatAmount(outflow),
                  formatAmount(inflow - outflow)),
              pw.SizedBox(height: 16),
              _table(filtered, dfFull, formatAmount),
              pw.SizedBox(height: 24),
              pw.Text(
                'Kasby — Investment Platform · This statement is generated for informational purposes.',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        );

        final bytes = await doc.save();
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'kasby_statement_${df.format(from)}_${df.format(to)}.pdf',
        );
      },
    );
  }

  static pw.Widget _header(
      String name, String email, String from, String to) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('KASBY',
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFC9A24D))),
            pw.Text('Account Statement',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Divider(color: PdfColor.fromInt(0xFFC9A24D)),
        pw.SizedBox(height: 8),
        pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (email.isNotEmpty)
          pw.Text(email, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text('Period: $from to $to',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _summary(String inflow, String outflow, String net) {
    pw.Widget cell(String label, String value, PdfColor color) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          margin: const pw.EdgeInsets.only(right: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        cell('Total In', inflow, PdfColors.green700),
        cell('Total Out', outflow, PdfColors.red700),
        cell('Net', net, PdfColors.blue700),
      ],
    );
  }

  static pw.Widget _table(
      List<TransactionModel> txns,
      DateFormat df,
      String Function(double) money) {
    final headers = ['Date', 'Type', 'Status', 'Amount'];
    final rows = txns.map((t) {
      final sign = t.isDebit ? '-' : '+';
      return [
        t.createdAt != null ? df.format(t.createdAt!) : '--',
        t.type,
        t.status,
        '$sign${money(t.amount)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1A1F)),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      oddRowDecoration:
          const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static String _defaultMoney(double v) => '\$${v.toStringAsFixed(2)}';
}
