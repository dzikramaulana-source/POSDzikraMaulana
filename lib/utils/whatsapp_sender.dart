import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/whatsapp_service.dart';
import 'receipt_printer.dart';

/// Normalisasi nomor WhatsApp ke format internasional tanpa tanda "+".
///
/// Contoh: "0812-3456-7890" -> "6281234567890",
/// "+62 812 3456 7890" -> "6281234567890", "81234567890" -> "6281234567890".
String normalizeWhatsAppNumber(String input) {
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (digits.startsWith('8')) {
    digits = '62$digits';
  }
  return digits;
}

/// Ambil 4 digit terakhir dari [input], atau `''` bila digitnya belum
/// mencapai 4. Dipakai untuk mencari nomor pelanggan yang pernah dipakai.
String lastFourDigitsOf(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length < 4 ? '' : digits.substring(digits.length - 4);
}

/// Format nomor WhatsApp menjadi bentuk lokal yang mudah dibaca.
///
/// Contoh: "6281234567890" -> "0812-3456-7890".
String formatWhatsAppNumber(String input) {
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return input;
  if (digits.startsWith('62')) {
    digits = '0${digits.substring(2)}';
  }

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 4 || (i > 4 && (i - 4) % 4 == 0)) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Kirim PDF struk transaksi ke nomor WhatsApp pelanggan melalui backend
/// (endpoint `/whatsapp/send-document`).
///
/// Menampilkan notifikasi berhasil/gagal dan mengembalikan `true` bila terkirim.
Future<bool> sendReceiptToWhatsApp(
  BuildContext context, {
  required Transaction transaction,
  required String phone,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final number = normalizeWhatsAppNumber(phone);

  if (number.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Masukkan nomor WhatsApp pelanggan terlebih dahulu'),
      ),
    );
    return false;
  }

  try {
    final pdf = await ReceiptPrinter.generateReceiptPdf(transaction);
    await WhatsAppService.sendReceiptDocument(
      phone: number,
      pdfBytes: pdf,
      filename: 'Struk_${transaction.invoiceNumber}.pdf',
      caption: 'Struk ${transaction.invoiceNumber}',
    );

    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Struk berhasil dikirim ke WhatsApp')),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengirim struk ke WhatsApp: $error')),
      );
    }
    return false;
  }
}
