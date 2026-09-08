import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../services/shift_service.dart';
import '../utils/formatter.dart';
import '../utils/payment_method.dart';

/// Halaman detail shift kasir.
///
/// Dibuka dari daftar shift. Menampilkan info kasir/waktu, ringkasan transaksi,
/// serta rekap kas (kas sistem vs uang fisik + selisih) bila shift sudah ditutup.
class ShiftDetailScreen extends StatefulWidget {
  final String shiftId;

  const ShiftDetailScreen({super.key, required this.shiftId});

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Shift? _shift;
  ShiftSummary? _summary;
  double? _expectedCash;
  double? _difference;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ShiftService.getShiftDetail(widget.shiftId);
      if (!mounted) return;
      setState(() {
        final shiftJson = data['shift'] as Map<String, dynamic>?;
        _shift = shiftJson != null ? Shift.fromJson(shiftJson) : null;
        _summary = ShiftSummary.fromJson(
            data['summary'] as Map<String, dynamic>?);
        _expectedCash = (data['expectedCash'] as num?)?.toDouble();
        _difference = data['difference'] == null
            ? null
            : (data['difference'] as num).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Shift')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _load,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final shift = _shift;
    if (shift == null) {
      return const Center(child: Text('Shift tidak ditemukan'));
    }

    final summary = _summary ?? ShiftSummary.fromJson(null);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kartu info shift
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: shift.isOpen
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          shift.isOpen ? 'Aktif' : 'Tutup',
                          style: TextStyle(
                            color: shift.isOpen ? Colors.green : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (shift.autoClosed)
                        Text(
                          'Ditutup otomatis',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Kasir',
                    value: shift.kasirName.isEmpty
                        ? shift.kasirId
                        : shift.kasirName,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.login,
                    label: 'Buka Shift',
                    value: _fmtDateTime(shift.openedAt),
                  ),
                  if (shift.closedAt != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.logout,
                      label: 'Tutup Shift',
                      value: _fmtDateTime(shift.closedAt!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.savings,
                    label: 'Kas Awal',
                    value: formatRupiah(shift.openingCash),
                  ),
                  if (shift.closingCash != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.payments,
                      label: 'Kas Akhir (Fisik)',
                      value: formatRupiah(shift.closingCash!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ringkasan Transaksi',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow('Jumlah Transaksi',
                      '${summary.totalTransactions}'),
                  const SizedBox(height: 12),
                  _summaryRow(
                    'Total Penjualan',
                    formatRupiah(summary.totalSales),
                    emphasize: true,
                  ),
                  const SizedBox(height: 12),
                  _summaryRow(
                    'Penjualan Tunai',
                    formatRupiah(summary.cashSales),
                  ),
                  if (summary.paymentSummary.isNotEmpty) ...[
                    const Divider(height: 24),
                    ...summary.paymentSummary.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(paymentIcon(p.method),
                                  size: 18, color: paymentColor(p.method)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${paymentLabel(p.method)} (${p.count})',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                formatRupiah(p.total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
          // Rekap kas (hanya untuk shift tertutup)
          if (!shift.isOpen) ...[
            const SizedBox(height: 16),
            Text('Rekap Kas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rekapRow(
                      'Kas Sistem',
                      '(Kas awal + penjualan tunai)',
                      formatRupiah(_expectedCash ?? 0),
                    ),
                    const SizedBox(height: 12),
                    _rekapRow(
                      'Uang Fisik',
                      '(Kas akhir dicatat kasir)',
                      formatRupiah(shift.closingCash ?? 0),
                    ),
                    const Divider(height: 24),
                    _buildDifference(context, _difference),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.withValues(alpha: 0.06),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Shift ini masih berjalan. Tutup shift untuk melihat rekap kas dan selisih.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDifference(BuildContext context, double? difference) {
    if (difference == null) return const SizedBox.shrink();

    final Color color;
    final String label;
    if (difference > 0) {
      color = Colors.green;
      label = 'Lebih ${formatRupiah(difference)}';
    } else if (difference < 0) {
      color = Colors.red;
      label = 'Kurang ${formatRupiah(difference.abs())}';
    } else {
      color = Colors.blueGrey;
      label = 'Pas';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selisih',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              difference == 0 ? Icons.check_circle : Icons.info,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: emphasize
              ? TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _rekapRow(String label, String sublabel, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Text(
                sublabel,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _fmtDateTime(DateTime dt) =>
      DateFormat('EEEE, dd MMM yyyy • HH:mm', 'id_ID').format(dt);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
