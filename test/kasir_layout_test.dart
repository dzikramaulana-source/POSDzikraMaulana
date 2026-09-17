import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_sop/models/product.dart';
import 'package:flutter_sop/providers/auth_provider.dart';
import 'package:flutter_sop/providers/cart_provider.dart';
import 'package:flutter_sop/providers/notification_provider.dart';
import 'package:flutter_sop/providers/product_provider.dart';
import 'package:flutter_sop/providers/setting_provider.dart';
import 'package:flutter_sop/screens/kasir_screen.dart';

/// Keranjang berisi dua item agar panel pesanan, ringkasan, dan tombol bayar
/// ikut dirender saat pengujian tata letak.
CartProvider _cartWithItems() {
  final cart = CartProvider();
  cart.addItem(Product(
    id: 'p1',
    name: 'Kopi Susu Gula Aren',
    sku: 'KOPI-01',
    price: 18000,
    cost: 10000,
    stock: 20,
    category: 'Minuman',
  ));
  cart.addItem(Product(
    id: 'p2',
    name: 'Roti Bakar Keju',
    sku: 'ROTI-02',
    price: 25000,
    cost: 15000,
    stock: 3,
    category: 'Camilan',
  ));
  return cart;
}

Widget _buildApp(CartProvider cart) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
      ChangeNotifierProvider(create: (_) => SettingProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => cart),
    ],
    child: const MaterialApp(home: KasirScreen()),
  );
}

/// Menjalankan beberapa frame tanpa `pumpAndSettle` (indikator loading bersifat
/// animasi tanpa akhir sehingga pumpAndSettle bisa tidak pernah selesai).
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Layar sempit: daftar produk tampil di atas keranjang tanpa overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp(_cartWithItems()));
    await _pumpFrames(tester);

    // Tidak ada RenderFlex overflow (atau error layout lain).
    expect(tester.takeException(), isNull);

    // Daftar produk tetap muncul di atas panel pesanan.
    final produkY = tester.getTopLeft(find.text('Daftar Produk')).dy;
    final pesananY = tester.getTopLeft(find.text('Pesanan')).dy;
    expect(produkY, lessThan(pesananY));
  });

  testWidgets('Layar sempit dengan tinggi pendek tetap tanpa overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp(_cartWithItems()));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Daftar Produk'), findsOneWidget);
    expect(find.text('Pesanan'), findsOneWidget);
  });

  testWidgets('Layar lebar: produk dan keranjang tampil berdampingan',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp(_cartWithItems()));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);

    // Pada layar lebar panel pesanan berada di sebelah kanan daftar produk.
    final produkX = tester.getTopLeft(find.text('Daftar Produk')).dx;
    final pesananX = tester.getTopLeft(find.text('Pesanan')).dx;
    expect(pesananX, greaterThan(produkX));
  });
}
