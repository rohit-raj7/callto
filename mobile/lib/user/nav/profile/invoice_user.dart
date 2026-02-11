import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoiceUserPage extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final String transactionTitle;
  final String userName;
  final String userCity;
  final String userEmail;
  final String userMobile;
  final bool isCredit;
  final double amount;

  const InvoiceUserPage({
    required this.transaction,
    required this.transactionTitle,
    required this.userName,
    required this.userCity,
    required this.userEmail,
    required this.userMobile,
    required this.isCredit,
    required this.amount,
    super.key,
  });

  @override
  State<InvoiceUserPage> createState() => _InvoiceUserPageState();
}

class _InvoiceUserPageState extends State<InvoiceUserPage> {
  bool _isDownloading = false;

  String _pickString(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = widget.transaction[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  /// IST offset: +5 hours 30 minutes
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  DateTime _toIST(DateTime utcDate) {
    return utcDate.toUtc().add(_istOffset);
  }

  DateTime _extractDate() {
    final raw =
        widget.transaction['created_at'] ??
        widget.transaction['createdAt'] ??
        widget.transaction['date'] ??
        widget.transaction['timestamp'];
    if (raw == null) return DateTime.utc(1970);
    if (raw is int) {
      final millis = raw < 1000000000000 ? raw * 1000 : raw;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (raw is double) {
      final value = raw.toInt();
      final millis = value < 1000000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (raw is String) {
      final numeric = int.tryParse(raw);
      if (numeric != null) {
        final millis = numeric < 1000000000000 ? numeric * 1000 : numeric;
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toUtc();
      return DateTime.utc(1970);
    }
    return DateTime.utc(1970);
  }

  double _extractAmount() {
    final raw =
        widget.transaction['amount'] ??
        widget.transaction['value'] ??
        widget.transaction['total'] ??
        widget.transaction['net_amount'];
    if (raw is num) return raw.toDouble().abs();
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return (double.tryParse(cleaned) ?? widget.amount).abs();
    }
    return widget.amount.abs();
  }

  String _formatAmount(double value) => '\u20B9${value.toStringAsFixed(2)}';
  String _formatPdfAmount(double value) => 'Rs.${value.toStringAsFixed(2)}';

  /// Extract the original recharge amount (before bonus) from description.
  /// Description format: "Wallet recharge ₹5 + ₹0.05 extra bonus"
  /// Returns null if no bonus pattern found (use full amount).
  double? _extractOriginalAmount() {
    final description = _pickString(
      ['description', 'title', 'note'],
      fallback: '',
    );
    // Match "Wallet recharge ₹<amount>" before the bonus part
    final match = RegExp(r'[Ww]allet\s+recharge\s+₹([\d.]+)').firstMatch(description);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Build a clean invoice title without bonus info
  String _cleanInvoiceTitle(double originalAmount) {
    return 'Wallet recharge ₹${originalAmount.toStringAsFixed(originalAmount == originalAmount.roundToDouble() ? 0 : 2)}';
  }

  String _formatInWords(double value) {
    final rounded = value.round();
    return '${_numberToWords(rounded)} only';
  }

  String _numberToWords(int number) {
    if (number == 0) return 'Zero rupees';

    String twoDigits(int n) {
      const units = [
        '',
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'ten',
        'eleven',
        'twelve',
        'thirteen',
        'fourteen',
        'fifteen',
        'sixteen',
        'seventeen',
        'eighteen',
        'nineteen',
      ];
      const tens = [
        '',
        '',
        'twenty',
        'thirty',
        'forty',
        'fifty',
        'sixty',
        'seventy',
        'eighty',
        'ninety',
      ];

      if (n < 20) return units[n];
      final t = n ~/ 10;
      final u = n % 10;
      return u == 0 ? tens[t] : '${tens[t]} ${units[u]}';
    }

    String threeDigits(int n) {
      final h = n ~/ 100;
      final rem = n % 100;
      if (h == 0) return twoDigits(rem);
      if (rem == 0) return '${twoDigits(h)} hundred';
      return '${twoDigits(h)} hundred ${twoDigits(rem)}';
    }

    int n = number;
    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;
    final remainder = n;

    final parts = <String>[];
    if (crore > 0) parts.add('${threeDigits(crore)} crore');
    if (lakh > 0) parts.add('${threeDigits(lakh)} lakh');
    if (thousand > 0) parts.add('${threeDigits(thousand)} thousand');
    if (remainder > 0) parts.add(threeDigits(remainder));

    final value = parts.join(' ').trim();
    return '${value[0].toUpperCase()}${value.substring(1)} rupees';
  }

  Future<void> _downloadInvoicePdf({
    required String invoiceNo,
    required String transactionId,
    required String paymentMethod,
    required DateTime createdAt,
    required double amount,
    required double taxableValue,
    required double sgst,
    required double cgst,
    required double igst,
    required String invoiceTitle,
  }) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final pdf = pw.Document();
      final textStyle = pw.TextStyle(fontSize: 11);
      final boldTextStyle = pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Center(
              child: pw.Text(
                'Tax Invoice',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF8F5FF),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFE5E5E5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CallTo ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Super Market, Ground Floor, Rajiv Nagar Road no. 21, Patna, Bihar - 800024, India',
                    style: textStyle,
                  ),
                  pw.Text('GSTIN: 29AAECC4821K1ZA', style: textStyle),
                  pw.Text('HSN Code: 998314', style: textStyle),
                  pw.Text('Invoice #: $invoiceNo', style: boldTextStyle),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            _pdfDetailRow('Name', widget.userName, textStyle, boldTextStyle),
            _pdfDetailRow(
              'Transaction Date & Time',
              DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
              textStyle,
              boldTextStyle,
            ),
            _pdfDetailRow(
              'Transaction ID #',
              transactionId,
              textStyle,
              boldTextStyle,
            ),
            _pdfDetailRow(
              'Mode of Payment',
              paymentMethod,
              textStyle,
              boldTextStyle,
            ),
            _pdfDetailRow(
              'Place of Supply',
              '${widget.userCity.toUpperCase()}, INDIA',
              textStyle,
              boldTextStyle,
            ),
            _pdfDetailRow('Email', widget.userEmail, textStyle, boldTextStyle),
            _pdfDetailRow(
              'Mobile',
              widget.userMobile,
              textStyle,
              boldTextStyle,
            ),
            _pdfDetailRow(
              'Entry Type',
              widget.isCredit ? 'CREDIT' : 'DEBIT',
              textStyle,
              boldTextStyle,
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFD8D8D8),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.4),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                _pdfTableRow(
                  'Description',
                  'Amount',
                  isHeader: true,
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
                _pdfTableRow(
                  invoiceTitle,
                  _formatPdfAmount(taxableValue),
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
                _pdfTableRow(
                  'Taxable value',
                  _formatPdfAmount(taxableValue),
                  bold: true,
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
                _pdfTableRow(
                  'SGST (9.0%)',
                  _formatPdfAmount(sgst),
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
                _pdfTableRow(
                  'CGST (9.0%)',
                  _formatPdfAmount(cgst),
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
                _pdfTableRow(
                  'IGST (0.0%)',
                  _formatPdfAmount(igst),
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
                _pdfTableRow(
                  'Grand Total',
                  _formatPdfAmount(amount),
                  bold: true,
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
                _pdfTableRow(
                  'Total Amount (In words)',
                  _formatInWords(amount),
                  textStyle: textStyle,
                  boldTextStyle: boldTextStyle,
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'For CallTo Digital Wellness Private Limited',
                style: boldTextStyle,
              ),
            ),
            pw.SizedBox(height: 36),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Authorised Signatory',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Reference: callto.app/terms-and-conditions',
              style: textStyle.copyWith(color: PdfColors.blue700),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Tax payable on reverse-charge: No', style: boldTextStyle),
            pw.SizedBox(height: 4),
            pw.Text(
              '*For interstate supply, IGST will be applicable. Intrastate supply attracts CGST and SGST.',
              style: textStyle,
            ),
          ],
        ),
      );

      Directory outputDir;
      try {
        final downloadsDir = await getDownloadsDirectory();
        outputDir = downloadsDir ?? await getApplicationDocumentsDirectory();
      } catch (_) {
        outputDir = await getApplicationDocumentsDirectory();
      }

      final safeTransactionId = transactionId.replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-]'),
        '',
      );
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName =
          'invoice_${safeTransactionId.isEmpty ? 'txn' : safeTransactionId}_$timestamp.pdf';
      final file = File('${outputDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save(), flush: true);

      // Open the saved PDF file
      final openResult = await OpenFilex.open(file.path);

      if (!mounted) return;
      if (openResult.type == ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice saved: $fileName'),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice saved at: ${file.path}'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download invoice PDF: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAtUtc = _extractDate();
    final createdAt = _toIST(createdAtUtc);
    final transactionId = _pickString([
      'transaction_id',
      'payment_gateway_id',
      'payment_id',
      'id',
    ], fallback: 'NA');
    final paymentMethod = _pickString([
      'payment_method',
      'method',
    ], fallback: 'ONLINE').toUpperCase();
    final absAmount = _extractAmount();
    // For invoice, use only the original recharge amount (exclude bonus)
    final originalAmount = widget.isCredit ? (_extractOriginalAmount() ?? absAmount) : absAmount;
    final invoiceTitle = widget.isCredit && _extractOriginalAmount() != null
        ? _cleanInvoiceTitle(originalAmount)
        : widget.transactionTitle;
    final taxableValue = originalAmount / 1.18;
    final sgst = taxableValue * 0.09;
    final cgst = taxableValue * 0.09;
    const igst = 0.0;
    final invoiceNo =
        'INV/${createdAt.year}-${createdAt.year + 1}/${transactionId.length >= 6 ? transactionId.substring(0, 6) : transactionId}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7DCE5),
        surfaceTintColor: const Color(0xFFF7DCE5),
        title: const Text(
          'Tax Invoice',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isDownloading
                ? null
                : () => _downloadInvoicePdf(
                    invoiceNo: invoiceNo,
                    transactionId: transactionId,
                    paymentMethod: paymentMethod,
                    createdAt: createdAt,
                    amount: originalAmount,
                    taxableValue: taxableValue,
                    sgst: sgst,
                    cgst: cgst,
                    igst: igst,
                    invoiceTitle: invoiceTitle,
                  ),
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_isDownloading ? 'Saving...' : 'Download'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E7E7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Tax Invoice',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEBE5F9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CallTo Digital Wellness Private Limited',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Address: Super Market, Ground Floor, Rajiv Nagar Road no. 21, Patna, Bihar - 800024, India',
                    ),
                    const SizedBox(height: 4),
                    const Text('GSTIN: 29AAECC4821K1ZA'),
                    const SizedBox(height: 4),
                    const Text('HSN Code: 998314'),
                    const SizedBox(height: 4),
                    Text(
                      'Invoice #: $invoiceNo',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('Name', widget.userName),
              _detailRow(
                'Transaction Date & Time',
                DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
              ),
              _detailRow('Transaction ID #', transactionId),
              _detailRow('Mode of Payment', paymentMethod),
              _detailRow('Email', widget.userEmail),
              _detailRow('Mobile', widget.userMobile),
              _detailRow(
                'Place of Supply',
                '${widget.userCity.toUpperCase()}, INDIA',
              ),
              _detailRow('Entry Type', widget.isCredit ? 'CREDIT' : 'DEBIT'),
              const SizedBox(height: 14),
              Table(
                border: TableBorder.all(color: const Color(0xFFE0E0E0)),
                columnWidths: const {
                  0: FlexColumnWidth(2.4),
                  1: FlexColumnWidth(1),
                },
                children: [
                  _tableRow('Description', 'Amount', isHeader: true),
                  _tableRow(
                    invoiceTitle,
                    _formatAmount(taxableValue),
                  ),
                  _tableRow(
                    'Taxable value',
                    _formatAmount(taxableValue),
                    bold: true,
                  ),
                  _tableRow('SGST (9.0%)', _formatAmount(sgst)),
                  _tableRow('CGST (9.0%)', _formatAmount(cgst)),
                  _tableRow('IGST (0.0%)', _formatAmount(igst)),
                  _tableRow(
                    'Grand Total',
                    _formatAmount(originalAmount),
                    bold: true,
                  ),
                  _tableRow(
                    'Total Amount (In words)',
                    _formatInWords(originalAmount),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'For CallTo Digital Wellness Private Limited',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 34),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Authorised Signatory',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Reference: callto.app/terms-and-conditions',
                style: TextStyle(
                  color: Colors.blue[700],
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tax payable on reverse-charge: No',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                '*For interstate supply, IGST will be applicable. Intrastate supply attracts CGST and SGST.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 165,
            child: Text(
              key,
              style: const TextStyle(fontSize: 15, color: Color(0xFF404040)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfDetailRow(
    String key,
    String value,
    pw.TextStyle textStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 180, child: pw.Text(key, style: textStyle)),
          pw.Expanded(child: pw.Text(value, style: valueStyle)),
        ],
      ),
    );
  }

  TableRow _tableRow(
    String label,
    String value, {
    bool isHeader = false,
    bool bold = false,
  }) {
    final bgColor = isHeader ? const Color(0xFFE8E8E8) : Colors.white;
    return TableRow(
      decoration: BoxDecoration(color: bgColor),
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isHeader || bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: isHeader || bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _pdfTableRow(
    String label,
    String value, {
    bool isHeader = false,
    bool bold = false,
    required pw.TextStyle textStyle,
    required pw.TextStyle boldTextStyle,
  }) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isHeader ? const PdfColor.fromInt(0xFFE8E8E8) : PdfColors.white,
      ),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: isHeader || bold ? boldTextStyle : textStyle,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: isHeader || bold ? boldTextStyle : textStyle,
          ),
        ),
      ],
    );
  }
}
