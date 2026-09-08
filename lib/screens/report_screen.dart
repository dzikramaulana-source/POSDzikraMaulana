import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';
import '../utils/formatter.dart';
import '../utils/payment_method.dart';
import '../widgets/pos_app_bar_actions.dart';

/// Periode laporan yang bisa dipilih user.
enum ReportPeriod {
  today('Hari ini'),
  thisWeek('Minggu Ini'),
  thisMonth('Bulan Ini'),
  custom('Custom');

  const ReportPeriod(this.label);
  final String label;

  /// Hitung rentang tanggal untuk periode ini (berbasis sekarang).
  (DateTime, DateTime) range(DateTime now) {
    switch (this) {
      case ReportPeriod.today:
        return (DateTime(now.year, now.month, now.day),
            DateTime(now.year, now.month, now.day));
      case ReportPeriod.thisWeek:
        // 7 hari terakhir (rolling): hari ini minus 6 hari s.d. hari ini.
        return (DateTime(now.year, now.month, now.day - 6),
            DateTime(now.year, now.month, now.day));
      case ReportPeriod.thisMonth:
        return (DateTime(now.year, now.month, 1),
            DateTime(now.year, now.month + 1, 0));
      case ReportPeriod.custom:
        return (DateTime(now.year, now.month, now.day),
            DateTime(now.year, now.month, now.day));
    }
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportPeriod _period = ReportPeriod.today;
  DateTime _customStart = DateTime.now();
  DateTime _customEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _applyPeriod(ReportPeriod.today);
  }

  Future<void> _applyPeriod(ReportPeriod period) async {
    final (start, end) = period.range(DateTime.now());
    setState(() {
      _period = period;
      _customStart = start;
      _customEnd = end;
    });
    await context.read<ReportProvider>().load(start: start, end: end);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 3);
    final lastDate = DateTime(now.year, now.month, now.day);

    final values = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.range,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: now,
        rangeBidirectional: true,
        // Mode day menampilkan panah navigasi bulan antarmuka familiar.
        calendarViewMode: CalendarDatePicker2Mode.day,
        weekdayLabels: const ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'],
        firstDayOfWeek: 1, // Senin
        selectableDayPredicate: (date) =>
            !date.isBefore(firstDate) && !date.isAfter(lastDate),
        cancelButton: const Text('Batal'),
        okButton: const Text('Terapkan'),
      ),
      dialogSize: const Size(400, 500),
      value: [_customStart, _customEnd],
      borderRadius: BorderRadius.circular(16),
    );

    if (values == null || values.length < 2 || !mounted) return;
    final start = values[0];
    final end = values[1];
    if (start == null || end == null) return;

    setState(() {
      _period = ReportPeriod.custom;
      _customStart = start;
      _customEnd = end;
    });
    await context
        .read<ReportProvider>()
        .load(start: start, end: end);
  }

  Future<void> _refresh() async {
    final provider = context.read<ReportProvider>();
    final start = provider.start;
    final end = provider.end;
    if (start != null && end != null) {
      await provider.load(start: start, end: end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: const [PosAppBarActions()],
      ),
      body: Column(
        children: [
          _buildPeriodFilter(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    final provider = context.watch<ReportProvider>();
    final isCustom = _period == ReportPeriod.custom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ReportPeriod.values.map((p) {
              return ChoiceChip(
                label: Text(p.label),
                selected: _period == p,
                onSelected: (_) => _applyPeriod(p),
              );
            }).toList(),
          ),
          if (isCustom) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCustomRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      '${_fmtDate(_customStart)} – ${_fmtDate(_customEnd)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (provider.start != null && provider.end != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_fmtDate(provider.start!)} – ${_fmtDate(provider.end!)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    final provider = context.watch<ReportProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                provider.error!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _refresh,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final report = provider.report;
    if (report == null) {
      return const Center(child: Text('Belum ada data'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildSummarySection(report),
          const SizedBox(height: 20),
          if (report.previousSummary != null) ...[
            _buildComparisonCard(report),
            const SizedBox(height: 20),
          ],
          _sectionTitle(context, 'Grafik Penjualan'),
          const SizedBox(height: 8),
          _SalesChartCard(chartData: report.chartData),
          const SizedBox(height: 20),
          _buildTopProductsAndPayment(report),
        ],
      ),
    );
  }

  // ---------- Ringkasan ----------

  Widget _buildSummarySection(PeriodReport report) {
    final summary = report.summary;
    final items = <_SummaryCardData>[
      _SummaryCardData(
        icon: Icons.payments,
        label: 'Total Penjualan',
        value: formatRupiah(summary.totalRevenue),
        color: Colors.green,
      ),
      _SummaryCardData(
        icon: Icons.savings,
        label: 'Modal',
        value: formatRupiah(summary.totalCost),
        color: Colors.orange,
      ),
      _SummaryCardData(
        icon: Icons.account_balance_wallet,
        label: 'Laba',
        value: formatRupiah(summary.totalProfit),
        color: Colors.teal,
      ),
      _SummaryCardData(
        icon: Icons.percent,
        label: 'Margin',
        value: '${summary.margin.toStringAsFixed(1)}%',
        color: Colors.brown,
      ),
      _SummaryCardData(
        icon: Icons.receipt_long,
        label: 'Transaksi',
        value: formatNumber(summary.totalTransactions),
        color: Colors.blue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 900
            ? 4
            : width >= 600
                ? 3
                : 2;
        const spacing = 12.0;
        final cardWidth = (width - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((item) => SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      icon: item.icon,
                      label: item.label,
                      value: item.value,
                      color: item.color,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  // ---------- Perbandingan periode ----------

  Widget _buildComparisonCard(PeriodReport report) {
    final current = report.summary.totalRevenue;
    final previous = report.previousSummary!.totalRevenue;
    final delta = current - previous;
    final percent = previous > 0 ? (delta / previous) * 100 : (current > 0 ? 100.0 : 0.0);
    final isUp = delta >= 0;
    final color = isUp ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perbandingan Periode Sebelumnya',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _comparisonItem(
                    'Periode Ini',
                    formatRupiah(current),
                    Colors.teal,
                  ),
                ),
                Expanded(
                  child: _comparisonItem(
                    'Periode Lalu',
                    formatRupiah(previous),
                    Colors.grey[600]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${isUp ? '+' : ''}${percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'dari periode sebelumnya',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  // ---------- Produk terlaris + metode pembayaran ----------

  Widget _buildTopProductsAndPayment(PeriodReport report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final topProducts = _buildTopProducts(report.topProducts);
        final payment = _buildPaymentSection(report.paymentSummary);

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: topProducts),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: payment),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            topProducts,
            const SizedBox(height: 16),
            payment,
          ],
        );
      },
    );
  }

  Widget _buildTopProducts(List<TopSellingProduct> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Produk Terlaris'),
        const SizedBox(height: 8),
        if (products.isEmpty)
          const _EmptyCard(message: 'Belum ada penjualan pada periode ini')
        else
          Card(
            child: Column(
              children: List.generate(products.length, (index) {
                final p = products[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${index + 1}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(p.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${formatNumber(p.qty)} terjual'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatRupiah(p.revenue),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Laba ${formatRupiah(p.profit)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentSection(List<PaymentMethodSummary> payment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Metode Pembayaran'),
        const SizedBox(height: 8),
        if (payment.isEmpty)
          const _EmptyCard(message: 'Belum ada data pembayaran')
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SizedBox(
                    height: 150,
                    child: _PaymentPieChart(payment: payment),
                  ),
                  const SizedBox(height: 12),
                  ...payment.map((p) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _paymentIcon(p.method),
                        color: _paymentColor(p.method),
                      ),
                      title: Text(_paymentLabel(p.method)),
                      subtitle: Text('${formatNumber(p.count)} transaksi'),
                      trailing: Text(
                        formatRupiah(p.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Helper ----------

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
}

IconData _paymentIcon(String method) {
  return paymentIcon(method);
}

Color _paymentColor(String method) {
  return paymentColor(method);
}

String _paymentLabel(String method) {
  return paymentLabel(method);
}

class _SummaryCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message,
            style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  final List<ChartPoint> chartData;

  const _SalesChartCard({required this.chartData});

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return const _EmptyCard(message: 'Belum ada data penjualan');
    }

    // Urutkan tanggal terbaru (Hari Ini) di paling atas.
    final points = [...chartData]
      ..sort((a, b) => b.label.compareTo(a.label));
    final maxTotal =
        chartData.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;
            final labelWidth = narrow ? 100.0 : 150.0;
            final amountStyle = TextStyle(
              fontSize: narrow ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade800,
            );

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: points.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final point = points[index];
                  final date = DateTime.tryParse(point.label);
                  final dateText = date != null
                      ? DateFormat('dd/MM/yyyy').format(date)
                      : point.label;

                  final String relLabel;
                  if (date == null) {
                    relLabel = point.label;
                  } else {
                    final daysAgo = today
                        .difference(DateTime(date.year, date.month, date.day))
                        .inDays;
                    if (daysAgo <= 0) {
                      relLabel = 'Hari Ini';
                    } else if (daysAgo == 1) {
                      relLabel = 'Kemarin';
                    } else {
                      relLabel = '$daysAgo Hari Lalu';
                    }
                  }

                  final ratio = maxTotal > 0 ? point.total / maxTotal : 0.0;

                  return Row(
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              relLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: ratio,
                                  heightFactor: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.teal,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRupiah(point.total),
                              style: amountStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentPieChart extends StatelessWidget {
  final List<PaymentMethodSummary> payment;

  const _PaymentPieChart({required this.payment});

  @override
  Widget build(BuildContext context) {
    final total = payment.fold<double>(0, (sum, p) => sum + p.total);
    if (total <= 0) {
      return const Center(child: Text('Belum ada data'));
    }

    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.orange,
      Colors.purple,
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 28,
        sections: List.generate(payment.length, (index) {
          final p = payment[index];
          final percent = (p.total / total * 100).toStringAsFixed(0);
          return PieChartSectionData(
            value: p.total,
            color: colors[index % colors.length],
            radius: 36,
            title: '$percent%',
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }
}

