import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/challan.dart';
import '../models/company_profile.dart';

/// Builds an in-memory delivery challan PDF.
///
/// [ChallanFormat.letterhead] prints the challan on the company letter pad
/// (`assets/brand/letterhead.jpg`); content is placed inside the blank body
/// area of the pad, below the header and above the footer band.
/// [ChallanFormat.plain] renders a clean bordered sheet with no letterhead.
class ChallanPdfService {
  const ChallanPdfService._();

  // ------------------------------------------------------------- lifecycle

  static pw.MemoryImage? _cachedLetterhead;

  static Future<pw.MemoryImage> _letterhead() async {
    if (_cachedLetterhead != null) return _cachedLetterhead!;
    final data = await rootBundle.load('assets/brand/letterhead.jpg');
    final image = pw.MemoryImage(data.buffer.asUint8List());
    _cachedLetterhead = image;
    return image;
  }

  static Future<Uint8List> build(
    Challan challan,
    CompanyProfile company,
  ) async {
    final doc = pw.Document(
      title: 'Delivery Challan ${challan.number}',
      author: company.name,
      subject: 'Delivery Challan - ${challan.format.label}',
    );

    switch (challan.format) {
      case ChallanFormat.letterhead:
        _addLetterheadPage(doc, challan, company, await _letterhead());
      case ChallanFormat.plain:
        _addPlainPage(doc, challan, company);
    }

    return doc.save();
  }

  static Future<void> preview(Challan challan, CompanyProfile company) =>
      Printing.layoutPdf(
        name: 'Challan_${_fileSafe(challan.number)}',
        onLayout: (_) => build(challan, company),
      );

  static Future<void> share(Challan challan, CompanyProfile company) async {
    final bytes = await build(challan, company);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Challan_${_fileSafe(challan.number)}.pdf',
    );
  }

  // ------------------------------------------------------------- palette

  static const PdfColor _navy = PdfColor.fromInt(0xFF0A2A66);
  static const PdfColor _accent = PdfColor.fromInt(0xFF1E8E3E);
  static const PdfColor _grey = PdfColor.fromInt(0xFF5B6675);
  static const PdfColor _lightLine = PdfColor.fromInt(0xFFE4E8F0);
  static const PdfColor _ink = PdfColor.fromInt(0xFF0F1A2B);

  static final pw.Font _bold = pw.Font.helveticaBold();
  static final pw.Font _regular = pw.Font.helvetica();

  // ------------------------------------------------------------- helpers

  static pw.Widget _cell(
    String text, {
    double size = 9,
    bool isBold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    PdfColor color = PdfColors.black,
    pw.Font? font,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font ?? (isBold ? _bold : _regular),
          fontSize: size,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _boxLabel(String label) => pw.Text(
    label,
    style: pw.TextStyle(
      font: _bold,
      fontSize: 7.5,
      letterSpacing: 0.9,
      color: _grey,
    ),
  );

  static pw.Widget _detail(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 74,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: _regular, fontSize: 8.5, color: _grey),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isEmpty ? '-' : value,
            style: pw.TextStyle(font: _bold, fontSize: 9),
          ),
        ),
      ],
    ),
  );

  static String _fileSafe(String number) =>
      number.replaceAll('/', '-').replaceAll(' ', '_');

  /// Indian-grouped amount with **up to 2 decimals** (no rounding to integer).
  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final intPart = fixed.substring(0, dot);
    var dec = fixed.substring(dot + 1);

    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final fromEnd = intPart.length - i;
      buffer.write(intPart[i]);
      if (fromEnd > 1) {
        final remaining = fromEnd - 1;
        if (remaining % 3 == 0) buffer.write(',');
      }
    }

    if (dec == '00') {
      dec = '';
    } else if (dec.endsWith('0')) {
      dec = dec.substring(0, dec.length - 1);
    }
    return dec.isEmpty ? buffer.toString() : '${buffer.toString()}.$dec';
  }

  static String _date(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = d.day.toString().padLeft(2, '0');
    return '$day ${months[d.month - 1]} ${d.year}';
  }

  static const List<String> _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  static String _underHundred(int n) {
    if (n < 20) return _ones[n];
    final t = _tens[n ~/ 10];
    final o = _ones[n % 10];
    return o.isEmpty ? t : '$t $o';
  }

  /// Indian numbering system: crore / lakh / thousand.
  static String _inWords(int number) {
    if (number <= 0) return 'Zero';

    final buffer = StringBuffer();
    final crore = number ~/ 10000000;
    final lakh = (number ~/ 100000) % 100;
    final thousand = (number ~/ 1000) % 100;
    final hundred = (number ~/ 100) % 10;
    final rest = number % 100;

    if (crore > 0) buffer.write('${_underHundred(crore)} Crore ');
    if (lakh > 0) buffer.write('${_underHundred(lakh)} Lakh ');
    if (thousand > 0) buffer.write('${_underHundred(thousand)} Thousand ');
    if (hundred > 0) buffer.write('${_ones[hundred]} Hundred ');
    if (rest > 0) buffer.write(_underHundred(rest));

    return buffer.toString().trim();
  }

  // --------------------------------------------------------- shared blocks

  static pw.Widget _partyBlock(
    String label,
    ChallanParty party, {
    required bool showSite,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _boxLabel(label),
      pw.SizedBox(height: 4),
      pw.Text(
        party.name.isEmpty ? '-' : party.name,
        style: pw.TextStyle(font: _bold, fontSize: 11),
      ),
      if (showSite && party.siteProject.isNotEmpty)
        pw.Text(
          party.siteProject,
          style: pw.TextStyle(font: _regular, fontSize: 9),
        ),
      pw.SizedBox(height: 3),
      pw.Text(
        party.address.isEmpty ? '-' : party.address,
        style: pw.TextStyle(font: _regular, fontSize: 8.5),
      ),
      pw.Text(
        'Contact: ${party.phone.isEmpty ? '-' : party.phone}',
        style: pw.TextStyle(font: _regular, fontSize: 8.5),
      ),
      if (party.gstin.isNotEmpty)
        pw.Text(
          'GSTIN: ${party.gstin}',
          style: pw.TextStyle(font: _regular, fontSize: 8.5),
        ),
      if (party.contactPerson.isNotEmpty)
        pw.Text(
          'Contact person: ${party.contactPerson}',
          style: pw.TextStyle(font: _regular, fontSize: 8.5),
        ),
    ],
  );

  static pw.Widget _partyAndMeta(Challan challan) => pw.Column(
    children: [
      pw.Table(
        border: pw.TableBorder.all(color: _lightLine, width: 0.6),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.45),
          1: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: _partyBlock('BILL TO', challan.billTo, showSite: false),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _boxLabel('CHALLAN DETAILS'),
                    pw.SizedBox(height: 4),
                    _detail('Challan No.', challan.number),
                    _detail('Date', _date(challan.date)),
                    _detail(
                      'Vehicle No.',
                      challan.vehicleNo.isEmpty ? '-' : challan.vehicleNo,
                    ),
                    _detail('Prepared by', challan.preparedBy),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _lightLine, width: 0.6),
        ),
        child: _partyBlock('SHIP TO', challan.shipTo, showSite: true),
      ),
    ],
  );

  static pw.Widget _itemsTable(Challan challan) => pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(0.5),
      1: pw.FlexColumnWidth(2.9),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(0.6),
      4: pw.FlexColumnWidth(0.6),
      5: pw.FlexColumnWidth(0.9),
      6: pw.FlexColumnWidth(1.1),
    },
    border: pw.TableBorder.all(color: _lightLine, width: 0.6),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: [
          _cell('S.No', isBold: true, size: 8.5, color: PdfColors.white),
          _cell(
            'Description of Goods',
            isBold: true,
            size: 8.5,
            color: PdfColors.white,
          ),
          _cell('SKU / Code', isBold: true, size: 8.5, color: PdfColors.white),
          _cell('Unit', isBold: true, size: 8.5, color: PdfColors.white),
          _cell('Qty', isBold: true, size: 8.5, color: PdfColors.white),
          _cell(
            'Rate (Rs.)',
            isBold: true,
            size: 8.5,
            color: PdfColors.white,
            align: pw.Alignment.centerRight,
          ),
          _cell(
            'Amount (Rs.)',
            isBold: true,
            size: 8.5,
            color: PdfColors.white,
            align: pw.Alignment.centerRight,
          ),
        ],
      ),
      for (var i = 0; i < challan.lines.length; i++)
        pw.TableRow(
          children: [
            _cell('${i + 1}', size: 9, align: pw.Alignment.center),
            _cell(challan.lines[i].itemName, size: 9),
            _cell(challan.lines[i].sku, size: 8.5, color: _grey),
            _cell(challan.lines[i].unit, size: 8.5),
            _cell('${challan.lines[i].quantity}', size: 9, isBold: true),
            _cell(
              _money(challan.lines[i].rate),
              size: 8.5,
              align: pw.Alignment.centerRight,
            ),
            _cell(
              _money(challan.lines[i].amount),
              size: 9,
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.white),
        children: [
          _cell('', size: 9),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'TOTAL',
              style: pw.TextStyle(font: _bold, fontSize: 9),
            ),
          ),
          _cell('', size: 9),
          _cell('', size: 9),
          _cell('${challan.totalUnits}', size: 9, isBold: true),
          _cell('', size: 9),
          _cell(
            _money(challan.totalValue),
            size: 9.5,
            isBold: true,
            align: pw.Alignment.centerRight,
          ),
        ],
      ),
    ],
  );

  static pw.Widget _taxSummary(Challan challan) {
    pw.Widget row(String label, String value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: bold ? _bold : _regular,
                  fontSize: bold ? 9.5 : 8.5,
                  color: bold ? _ink : _grey,
                ),
              ),
              pw.Text(
                value,
                style: pw.TextStyle(
                  font: bold ? _bold : _regular,
                  fontSize: bold ? 9.5 : 8.5,
                  color: _ink,
                ),
              ),
            ],
          ),
        );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Column(
            children: [
              row('Taxable value', 'Rs. ${_money(challan.taxableValue)}'),
              for (final e in challan.gstBreakdown.entries)
                row(
                  'GST @ ${e.key.toStringAsFixed(e.key == e.key.roundToDouble() ? 0 : 2)}%',
                  'Rs. ${_money(e.value)}',
                ),
              if (challan.gstBreakdown.isEmpty) row('GST', 'Rs. 0'),
              if (challan.roundOff != 0)
                row(
                  'Round off',
                  '${challan.roundOff >= 0 ? '+' : '-'}Rs. ${_money(challan.roundOff.abs())}',
                ),
              pw.Divider(color: _lightLine, height: 10),
              row(
                'Grand total',
                'Rs. ${_money(challan.grandTotal)}',
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _amountInWords(Challan challan) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF4F6FB),
      border: pw.Border.all(color: _lightLine, width: 0.6),
    ),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: 'Amount in words:  ',
            style: pw.TextStyle(font: _bold, fontSize: 8.5, color: _grey),
          ),
          pw.TextSpan(
            text: 'Rupees ${_inWords(challan.grandTotal.round())} Only',
            style: pw.TextStyle(font: _bold, fontSize: 9, color: _ink),
          ),
        ],
      ),
    ),
  );

  static pw.Widget _remarksAndSignature(
    Challan challan,
    CompanyProfile company,
  ) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _boxLabel('REMARKS'),
            pw.SizedBox(height: 4),
            pw.Text(
              challan.notes.isEmpty
                  ? 'Material issued against approved requisition.'
                  : challan.notes,
              style: pw.TextStyle(font: _regular, fontSize: 8.5),
            ),
            pw.SizedBox(height: 10),
            _boxLabel('TERMS'),
            pw.SizedBox(height: 4),
            pw.Text(
              '1. Goods once dispatched will not be taken back.\n'
              '2. Please check quantity before unloading.\n'
              '3. Goods are checked and accepted at the time of delivery.',
              style: pw.TextStyle(font: _regular, fontSize: 8, color: _grey),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _boxLabel('FOR ${company.name.toUpperCase()}'),
            pw.SizedBox(height: 6),
            pw.Container(
              height: 60,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightLine, width: 0.8),
              ),
              padding: const pw.EdgeInsets.all(7),
              alignment: pw.Alignment.bottomCenter,
              child: pw.Text(
                'Authorised Signatory',
                style: pw.TextStyle(
                  font: _regular,
                  fontSize: 8.5,
                  color: _grey,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  // ---------------------------------------------------------- letterhead

  static void _addLetterheadPage(
    pw.Document doc,
    Challan challan,
    CompanyProfile company,
    pw.MemoryImage letterhead,
  ) {
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          // Leave the letter pad's header (top) and footer band (bottom) clear.
          margin: const pw.EdgeInsets.only(
            top: 122,
            left: 42,
            right: 42,
            bottom: 52,
          ),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(letterhead, fit: pw.BoxFit.fill),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'DELIVERY CHALLAN',
                style: pw.TextStyle(
                  font: _bold,
                  fontSize: 15,
                  letterSpacing: 1.4,
                  color: _navy,
                ),
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'No. ${challan.number}',
                    style: pw.TextStyle(font: _bold, fontSize: 10),
                  ),
                  pw.Text(
                    _date(challan.date),
                    style: pw.TextStyle(
                      font: _regular,
                      fontSize: 9,
                      color: _grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 2, color: _accent),
          pw.SizedBox(height: 14),
          _partyAndMeta(challan),
          pw.SizedBox(height: 14),
          _itemsTable(challan),
          pw.SizedBox(height: 8),
          _taxSummary(challan),
          pw.SizedBox(height: 8),
          _amountInWords(challan),
          pw.SizedBox(height: 18),
          _remarksAndSignature(challan, company),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- plain

  static pw.Widget _footer(pw.Context ctx) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'This is a computer generated challan.',
          style: pw.TextStyle(font: _regular, fontSize: 7.5, color: _grey),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(font: _regular, fontSize: 7.5, color: _grey),
        ),
      ],
    ),
  );

  static void _addPlainPage(
    pw.Document doc,
    Challan challan,
    CompanyProfile company,
  ) {
    const border = pw.BorderSide(width: 0.8, color: _ink);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: _footer,
        build: (context) => [
          // ------------------------------------------------ letterhead
          pw.Center(
            child: pw.Text(
              company.name.toUpperCase(),
              style: pw.TextStyle(
                font: _bold,
                fontSize: 21,
                letterSpacing: 2,
                color: _navy,
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              company.tagline,
              style: pw.TextStyle(font: _regular, fontSize: 8, color: _grey),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              company.address,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: _regular, fontSize: 8.5),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'Phone: ${company.phone}   |   GSTIN: ${company.gstin}',
              style: pw.TextStyle(font: _regular, fontSize: 8.5),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 1.4, color: _navy),
          pw.SizedBox(height: 2),
          pw.Container(height: 0.6, color: _navy),
          pw.SizedBox(height: 14),

          // ------------------------------------------------ title band
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            decoration: const pw.BoxDecoration(
              border: pw.Border.fromBorderSide(border),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'DELIVERY CHALLAN',
              style: pw.TextStyle(
                font: _bold,
                fontSize: 14,
                letterSpacing: 2.5,
                color: _ink,
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          _partyAndMeta(challan),
          pw.SizedBox(height: 16),
          _itemsTable(challan),
          pw.SizedBox(height: 8),
          _taxSummary(challan),
          pw.SizedBox(height: 8),
          _amountInWords(challan),
          pw.SizedBox(height: 14),
          _remarksAndSignature(challan, company),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _boxLabel('RECEIVED BY'),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      height: 64,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border.fromBorderSide(border),
                      ),
                      padding: const pw.EdgeInsets.all(7),
                      alignment: pw.Alignment.bottomCenter,
                      child: pw.Text(
                        'Signature & Date',
                        style: pw.TextStyle(
                          font: _regular,
                          fontSize: 8.5,
                          color: _grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _boxLabel('DRIVER / TRANSPORTER'),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      height: 64,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border.fromBorderSide(border),
                      ),
                      padding: const pw.EdgeInsets.all(7),
                      alignment: pw.Alignment.bottomCenter,
                      child: pw.Text(
                        'Signature & Date',
                        style: pw.TextStyle(
                          font: _regular,
                          fontSize: 8.5,
                          color: _grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
