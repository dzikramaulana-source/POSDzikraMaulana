import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_sop/main.dart';
import 'package:flutter_sop/widgets/pos_sidebar.dart';

void main() {
  testWidgets('App membuka layar login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PosApp());
    await tester.pumpAndSettle();

    // Layar login menampilkan judul dan field username/password
    expect(find.text('POS Kasir'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets(
      'Sidebar tidak memicu error layout saat menjadi anak Row tanpa lebar terbatas',
      (WidgetTester tester) async {
    // Lebar desktop agar NavigationRail memakai mode extended (header berisi Expanded).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PosSidebar(
                selectedIndex: 0,
                onSelected: (_) {},
                items: const [
                  PosSidebarItem(
                    icon: Icons.inventory_2_outlined,
                    selectedIcon: Icons.inventory_2,
                    label: 'Manajemen Produk',
                    page: SizedBox.shrink(),
                  ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Store Online'), findsOneWidget);
  });
}
