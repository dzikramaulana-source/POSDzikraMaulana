import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/transaction.dart';
import 'formatter.dart';

/// Helper untuk membuat, mencetak, dan mengunduh struk transaksi (PDF).
///
/// - [generateReceiptPdf]: buat file PDF struk 80mm.
/// - [printReceipt]: cetak langsung ke printer (dialog pilih printer).
/// - [downloadReceipt]: simpan PDF struk ke file (desktop) / folder Download.
class ReceiptPrinter {
  static const double _pageWidth = 80 * PdfPageFormat.mm;

  /// Format tanggal struk, mis. "Kamis, 27 Agustus 2026 10:30"
  static final DateFormat _dateFmt =
      DateFormat('EEEE, dd MMMM yyyy HH:mm', 'id_ID');

  /// Nama toko/kasir untuk kop struk (bisa disesuaikan).
  static const String shopName = 'Toko Kasir';

  /// Label tarif pajak (mis. "PPN 10%") dari tarif yang tersimpan di transaksi.
  /// Untuk transaksi lama yang belum menyimpan tarif, dihitung dari nominal pajak.
  static String _taxLabel(Transaction transaction) {
    double percent = transaction.taxRate;
    final subtotal = transaction.total - transaction.tax;
    if (percent <= 0 && subtotal > 0) {
      percent = transaction.tax / subtotal * 100;
    }
    if (percent <= 0) return 'PPN';

    final rounded = (percent * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
    return 'PPN $text%';
  }

  /// Buat PDF struk dari data transaksi.
  static Future<Uint8List> generateReceiptPdf(Transaction transaction) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_pageWidth, double.infinity, marginAll: 8),
        build: (context) => _buildReceipt(context, transaction),
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildReceipt(
    pw.Context context,
    Transaction transaction,
  ) {
    final baseStyle = pw.TextStyle(fontSize: 9);
    final boldStyle =
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Kop struk
        pw.Center(
          child: pw.Text(
            shopName,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            _dateFmt.format(transaction.createdAt),
            style: baseStyle,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'No. Invoice: ${transaction.invoiceNumber}',
          style: boldStyle,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Kasir: ${transaction.createdByName}',
          style: baseStyle,
          textAlign: pw.TextAlign.center,
        ),
        pw.Divider(),
        // Daftar item
        ...transaction.items.map((item) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(item.name, style: boldStyle),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${formatNumber(item.qty)} x ${formatRupiah(item.price)}',
                      style: baseStyle,
                    ),
                    pw.Text(
                      formatRupiah(item.subtotal),
                      style: baseStyle,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        pw.Divider(),
        // Rincian pajak (hanya bila transaksi dikenakan PPN)
        if (transaction.tax > 0) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Subtotal', style: baseStyle),
              pw.Text(
                formatRupiah(transaction.total - transaction.tax),
                style: baseStyle,
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_taxLabel(transaction), style: baseStyle),
              pw.Text(formatRupiah(transaction.tax), style: baseStyle),
            ],
          ),
          pw.SizedBox(height: 2),
        ],
        // Total
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL', style: boldStyle),
            pw.Text(
              formatRupiah(transaction.total),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        if (transaction.paymentMethod == 'cash') ...[
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tunai', style: baseStyle),
              pw.Text(formatRupiah(transaction.cashReceived), style: baseStyle),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Kembalian', style: baseStyle),
              pw.Text(formatRupiah(transaction.change), style: baseStyle),
            ],
          ),
        ] else ...[
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Pembayaran', style: baseStyle),
              pw.Text('QRIS', style: baseStyle),
            ],
          ),
        ],
        pw.Divider(),
        pw.Center(
          child: pw.Text(
            'Terima kasih atas kunjungan Anda',
            style: baseStyle,
          ),
        ),
      ],
    );
  }

  /// Cetak struk ke printer (menampilkan dialog pilih printer).
  static Future<void> printReceipt(Transaction transaction) async {
    final pdf = await generateReceiptPdf(transaction);
    await Printing.layoutPdf(
      onLayout: (_) => pdf,
      name: 'Struk_${transaction.invoiceNumber}',
    );
  }

  /// Simpan struk sebagai file PDF.
  ///
  /// Di platform mobile memunculkan dialog simpan, di desktop langsung
  /// disimpan ke folder Downloads.
  static Future<void> downloadReceipt(Transaction transaction) async {
    final pdf = await generateReceiptPdf(transaction);
    final fileName = 'Struk_${transaction.invoiceNumber}.pdf';

    // Desktop (Windows/Linux/macOS): simpan langsung ke folder Downloads.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        final file = File('${dir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsBytes(pdf, flush: true);
        return;
      }
    }

    // Mobile / fallback: dialog simpan file.
    await Printing.sharePdf(bytes: pdf, filename: fileName);
  }
}
