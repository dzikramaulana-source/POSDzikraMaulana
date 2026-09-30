import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_sop/models/product.dart';
import 'package:flutter_sop/widgets/product_barcode.dart';

Product _product(String barcode) => Product(
      id: 'p1',
      name: 'Nasi Goreng',
      sku: 'NASGOR-001',
      barcode: barcode,
      price: 25000,
      cost: 15000,
      stock: 10,
      category: 'Makanan',
    );

Widget _wrap(Product product) => MaterialApp(
      home: Scaffold(body: ProductBarcode(product: product)),
    );

void main() {
  test('bentuk barcode permanen: angka yang sama selalu menghasilkan gambar sama',
      () {
    final ean13 = Barcode.ean13();
    const code = '2414375064068';

    final pertama = ean13.toSvg(code, width: 220, height: 90);
    final kedua = ean13.toSvg(code, width: 220, height: 90);
    final angkaLain = ean13.toSvg('9817094286972', width: 220, height: 90);

    // Dibentuk murni dari angka barcode -> identik setiap kali, tanpa unsur acak.
    expect(pertama, equals(kedua));
    expect(pertama, isNot(equals(angkaLain)));
  });

  testWidgets('produk dengan barcode valid menampilkan gambar barcode',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_product('2414375064068')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(find.text('Barcode Produk'), findsOneWidget);
  });

  testWidgets('produk tanpa barcode menampilkan keterangan, bukan gambar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_product('')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BarcodeWidget), findsNothing);
    expect(find.text('Barcode belum tersedia untuk produk ini.'), findsOneWidget);
  });

  testWidgets('barcode tidak valid tidak digambar (tidak error)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_product('1234567890123')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BarcodeWidget), findsNothing);
  });
}
