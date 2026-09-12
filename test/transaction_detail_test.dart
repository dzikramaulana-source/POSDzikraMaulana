import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_sop/models/transaction.dart';
import 'package:flutter_sop/screens/transaction_detail_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('Detail transaksi menampilkan nomor, tanggal, waktu, metode bayar',
      (WidgetTester tester) async {
    final tx = Transaction(
      id: 'tx1',
      invoiceNumber: 'TRX-20260827-0001',
      items: [
        TransactionItem(name: 'Kopi Hitam', price: 10000, qty: 2, subtotal: 20000),
      ],
      total: 20000,
      tax: 0,
      taxRate: 0,
      profit: 10000,
      paymentMethod: 'cash',
      cashReceived: 50000,
      change: 30000,
      createdByName: 'Kasir Satu',
      createdAt: DateTime(2026, 8, 27, 10, 30, 45),
    );

    await tester.pumpWidget(
      MaterialApp(home: TransactionDetailScreen(transaction: tx)),
    );

    // Nomor transaksi
    expect(find.text('TRX-20260827-0001'), findsOneWidget);
    // Label info
    expect(find.text('No. Transaksi'), findsOneWidget);
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Waktu'), findsOneWidget);
    expect(find.text('Metode Pembayaran'), findsOneWidget);
    // Tanggal & waktu terformat
    expect(find.text('Kamis, 27 Agustus 2026'), findsOneWidget);
    expect(find.text('10:30:45'), findsOneWidget);
    // Metode pembayaran
    expect(find.text('Tunai'), findsOneWidget);
    // Rincian item
    expect(find.text('Kopi Hitam'), findsOneWidget);
    // Tombol cetak/download struk
    expect(find.byIcon(Icons.print), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
  });
}
