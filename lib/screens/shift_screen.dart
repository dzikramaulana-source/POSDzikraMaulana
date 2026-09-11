import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/shift.dart';
import '../providers/auth_provider.dart';
import '../providers/shift_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatter.dart';
import '../utils/payment_method.dart';
import '../widgets/pos_app_bar_actions.dart';
import 'shift_detail_screen.dart';

/// Layar Kas / Shift.
///
/// - Kasir: membuka shift dengan kas awal, melihat ringkasan transaksi selama
///   shift, lalu menutup shift dengan kas akhir dan melihat selisih.
/// - Admin: melihat daftar shift semua kasir (read-only).
class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _openingCashController = TextEditingController();
  bool _isAdmin = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.role == 'admin';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShiftProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _openingCashController.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    final value = double.tryParse(_openingCashController.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kas awal wajib diisi dengan benar')),
      );
      return;
    }

    setState(() => _isBusy = true);
    final provider = context.read<ShiftProvider>();
    final result = await provider.openShift(value);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result != null) {
      _openingCashController.clear();
      final autoClosed = result['autoClosed'];
      if (autoClosed is Map && autoClosed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift sebelumnya ditutup otomatis karena Anda membuka shift baru'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift dibuka')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Gagal membuka shift')),
      );
    }
  }

  Future<void> _closeShift() async {
    final provider = context.read<ShiftProvider>();
    final shift = provider.activeShift;
    if (shift == null) return;

    final closingCash = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClosingCashSheet(shift: shift),
    );

    if (closingCash == null || !mounted) return;

    setState(() => _isBusy = true);
    final result = await provider.closeShift(shift.id, closingCash);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result != null) {
      await _showCloseResult(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Gagal menutup shift')),
      );
    }
  }

  Future<void> _showCloseResult(
    BuildContext context,
    Map<String, dynamic> result,
  ) async {
    final expected = (result['expectedCash'] as num?)?.toDouble() ?? 0;
    final closing = (result['difference'] == null
            ? null
            : (result['difference'] as num).toDouble())
        ??
        0;
    final physical = expected + closing;

    final Color color;
    final String label;
    if (closing > 0) {
      color = Colors.green;
      label = 'Lebih ${formatRupiah(closing)}';
    } else if (closing < 0) {
      color = Colors.red;
      label = 'Kurang ${formatRupiah(closing.abs())}';
    } else {
      color = Colors.blueGrey;
      label = 'Pas';
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.account_balance_wallet, color: color, size: 48),
        title: const Text('Shift Ditutup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow('Kas Sistem', formatRupiah(expected)),
            _resultRow('Uang Fisik', formatRupiah(physical)),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selisih',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShiftProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kas / Shift'),
        actions: const [PosAppBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isAdmin)
              _buildAdminHeader(context)
            else
              _buildKasirSection(context, provider),
            const SizedBox(height: 24),
            Text('Riwayat Shift', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (provider.isLoading && provider.history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.history.isEmpty)
              _buildError(context, provider)
            else if (provider.history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Belum ada shift tercatat.')),
              )
            else
              ...provider.history.map((shift) => _HistoryCard(shift: shift)),
          ],
        ),
      ),
    );
  }

  Widget _buildKasirSection(BuildContext context, ShiftProvider provider) {
    if (provider.isLoading && provider.activeShift == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final shift = provider.activeShift;
    if (shift != null) {
      return _buildActiveShiftCard(context, provider, shift);
    }
    return _buildOpenShiftCard(context);
  }

  Widget _buildOpenShiftCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buka Shift Kasir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Catat kas modal awal di laci sebelum memulai melayani transaksi.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _openingCashController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Kas Modal Awal (Rp)',
              prefixIcon: Icon(Icons.savings_rounded),
            ),
          ),
          const SizedBox(height: 12),
          // Quick amount chips
          Wrap(
            spacing: 8,
            children: [50000, 100000, 200000, 500000].map((amount) {
              return ActionChip(
                label: Text(formatRupiah(amount)),
                onPressed: () {
                  _openingCashController.text = amount.toString();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isBusy ? null : _openShift,
            icon: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: const Text('Buka Shift Sekarang'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveShiftCard(
    BuildContext context,
    ShiftProvider provider,
    Shift shift,
  ) {
    final summary = provider.activeSummary ?? ShiftSummary.fromJson(null);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shift Sedang Berjalan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dibuka ${DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(shift.openedAt)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'Aktif',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),
          _summaryRow('Kas Modal Awal', formatRupiah(shift.openingCash)),
          const SizedBox(height: 8),
          _summaryRow('Jumlah Transaksi', '${summary.totalTransactions}'),
          const SizedBox(height: 8),
          _summaryRow(
            'Total Penjualan',
            formatRupiah(summary.totalSales),
            emphasize: true,
          ),
          const SizedBox(height: 8),
          _summaryRow('Penjualan Tunai', formatRupiah(summary.cashSales)),
          if (summary.paymentSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 8),
            ...summary.paymentSummary.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(paymentIcon(p.method),
                        size: 16, color: paymentColor(p.method)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${paymentLabel(p.method)} (${p.count})',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      formatRupiah(p.total),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isBusy ? null : _closeShift,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.stop_circle_rounded),
            label: const Text('Tutup Shift'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: emphasize
              ? const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.primary,
                )
              : const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
        ),
      ],
    );
  }

  Widget _buildAdminHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring Kas & Shift',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Daftar shift seluruh kasir terpusat (mode pengawasan admin).',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, ShiftProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(provider.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => provider.refresh(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingCashSheet extends StatefulWidget {
  final Shift shift;

  const _ClosingCashSheet({required this.shift});

  @override
  State<_ClosingCashSheet> createState() => _ClosingCashSheetState();
}

class _ClosingCashSheetState extends State<_ClosingCashSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tutup Shift', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Hitung uang fisik di laci, lalu catat sebagai kas akhir.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Kas Akhir / Uang Fisik (Rp)',
              prefixIcon: Icon(Icons.payments),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(_controller.text.trim());
              if (value == null || value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kas akhir wajib diisi dengan benar'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(value);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Hitung Selisih & Tutup'),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Shift shift;

  const _HistoryCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final isOpen = shift.isOpen;
    final total = shift.summary?.totalSales ?? 0;

    final Color statusColor = isOpen ? AppColors.success : AppColors.textMuted;
    final Color statusBg = isOpen ? AppColors.successLight : AppColors.surfaceVariant;
    final String statusLabel = isOpen ? 'Aktif' : 'Tutup';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLight,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          shift.kasirName.isEmpty
              ? 'Shift ${DateFormat('dd MMM yyyy', 'id_ID').format(shift.openedAt)}'
              : '${shift.kasirName} • ${DateFormat('dd MMM yyyy', 'id_ID').format(shift.openedAt)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${DateFormat('HH:mm', 'id_ID').format(shift.openedAt)}'
            '${!isOpen && shift.closedAt != null ? ' – ${DateFormat('HH:mm', 'id_ID').format(shift.closedAt!)}' : ''}'
            ' • Omset: ${formatRupiah(total)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isOpen) ...[
                  const SizedBox(height: 4),
                  Text(
                    _differenceLabel(shift),
                    style: TextStyle(
                      color: _differenceColor(shift),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShiftDetailScreen(shiftId: shift.id),
          ),
        ),
      ),
    );
  }

  double? get _difference {
    if (shift.isOpen) return null;
    final closing = shift.closingCash;
    if (closing == null) return null;
    final summary = shift.summary;
    final expected = shift.openingCash + (summary?.cashSales ?? 0);
    return closing - expected;
  }

  Color _differenceColor(Shift shift) {
    final d = _difference;
    if (d == null) return AppColors.textMuted;
    if (d > 0) return AppColors.success;
    if (d < 0) return AppColors.danger;
    return AppColors.textMedium;
  }

  String _differenceLabel(Shift shift) {
    final d = _difference;
    if (d == null) return '';
    if (d > 0) return '+${formatRupiah(d)}';
    if (d < 0) return '-${formatRupiah(d.abs())}';
    return 'Pas';
  }
}
