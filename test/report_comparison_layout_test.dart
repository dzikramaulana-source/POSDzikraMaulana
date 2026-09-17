import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_sop/models/report.dart';
import 'package:flutter_sop/providers/auth_provider.dart';
import 'package:flutter_sop/providers/notification_provider.dart';
import 'package:flutter_sop/providers/report_provider.dart';
import 'package:flutter_sop/screens/report_screen.dart';

/// Provider laporan palsu: menyajikan data statis tanpa memanggil backend.
class _FakeReportProvider extends ReportProvider {
  _FakeReportProvider(this._data);

  final PeriodReport _data;

  @override
  PeriodReport? get report => _data;

  @override
  DateTime? get start => null;

  @override
  DateTime? get end => null;

  @override
  Future<void> load({required DateTime start, required DateTime end}) async {}
}

PeriodReport _report() {
  ReportSummary summary(double revenue) => ReportSummary(
        totalRevenue: revenue,
        totalTransactions: 10,
        unitsSold: 20,
        averageTransaction: revenue / 10,
        totalCost: revenue * 0.6,
        totalProfit: revenue * 0.4,
        margin: 40,
      );

  return PeriodReport(
    start: '2026-09-17',
    end: '2026-09-17',
    summary: summary(1234567),
    previousSummary: summary(987654),
    chartData: [ChartPoint(label: '2026-09-17', total: 1234567)],
    topProducts: [
      TopSellingProduct(
        name: 'Kopi Susu Gula Aren',
        qty: 5,
        revenue: 90000,
        profit: 40000,
      ),
    ],
    paymentSummary: [
      PaymentMethodSummary(method: 'cash', count: 6, total: 700000),
      PaymentMethodSummary(method: 'qris', count: 4, total: 534567),
    ],
  );
}

Widget _buildApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<ReportProvider>(
        create: (_) => _FakeReportProvider(_report()),
      ),
    ],
    child: const MaterialApp(home: ReportScreen()),
  );
}

/// Menjalankan beberapa frame tanpa `pumpAndSettle` (grafik bersifat animasi).
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Mobile: Periode Ini di atas Periode Sebelumnya tanpa overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp());
    await _pumpFrames(tester);

    // Tidak ada RenderFlex overflow (atau error layout lain).
    expect(tester.takeException(), isNull);

    final ini = tester.getTopLeft(find.text('Periode Ini'));
    final sebelumnya = tester.getTopLeft(find.text('Periode Sebelumnya'));

    // Bertumpuk vertikal: Periode Ini di atas, sejajar kiri dengan yang bawah.
    expect(ini.dy, lessThan(sebelumnya.dy));
    expect(ini.dx, closeTo(sebelumnya.dx, 1));
  });

  testWidgets('Desktop: Periode Ini dan Periode Sebelumnya tetap berdampingan',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp());
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);

    final ini = tester.getTopLeft(find.text('Periode Ini'));
    final sebelumnya = tester.getTopLeft(find.text('Periode Sebelumnya'));

    // Berdampingan: item kedua di sebelah kanan, tinggi sejajar.
    expect(sebelumnya.dx, greaterThan(ini.dx));
    expect(ini.dy, closeTo(sebelumnya.dy, 1));
  });
}
