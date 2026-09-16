import 'dart:async';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_history_provider.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatter.dart';
import '../utils/payment_method.dart';
import '../widgets/pos_app_bar_actions.dart';
import 'transaction_detail_screen.dart';

/// Layar Riwayat Transaksi.
///
/// Menampilkan & mencari seluruh transaksi berdasarkan nomor transaksi,
/// rentang tanggal, kasir (khusus admin), dan metode pembayaran. Setiap item
/// membuka detail transaksi dengan opsi cetak/download struk.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _invoiceController = TextEditingController();
  bool _isAdmin = false;
  bool _isResetting = false;
  List<User> _kasirList = [];
  Timer? _debounce;

  DateTime? _start;
  DateTime? _end;
  String? _kasirId;
  String? _payment;

  bool get _isFilterActive =>
      _invoiceController.text.trim().isNotEmpty ||
      _start != null ||
      _end != null ||
      _kasirId != null ||
      _payment != null;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.role == 'admin';
    _invoiceController.addListener(_onFilterChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAdmin) _loadKasirList();
      _search();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _loadKasirList() async {
    try {
      final kasir = await UserService.getKasir();
      if (mounted) setState(() => _kasirList = kasir);
    } catch (_) {
      // Filter kasir tetap bisa dipakai walau daftar kasir gagal dimuat.
    }
  }

  // Ketik nomor invoice -> tunggu sebentar lalu cari otomatis
  void _onFilterChanged() {
    if (_isResetting) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final provider = context.read<TransactionHistoryProvider>();
    provider
      ..setInvoice(_invoiceController.text)
      ..setStart(_start)
      ..setEnd(_end)
      ..setKasirId(_isAdmin ? _kasirId : null)
      ..setPayment(_payment);
    await provider.search();
  }

  void _resetFilters() {
    _debounce?.cancel();
    _isResetting = true;
    _invoiceController.clear();
    setState(() {
      _start = null;
      _end = null;
      _kasirId = null;
      _payment = null;
    });
    _isResetting = false;
    _search();
  }

  /// Pilih rentang tanggal (mulai & selesai) dalam satu dialog, seperti
  /// pola pemilihan periode custom di layar Laporan.
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year, now.month, now.day);

    final values = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.range,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: now,
        rangeBidirectional: true,
        calendarViewMode: CalendarDatePicker2Mode.day,
        weekdayLabels: const ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'],
        firstDayOfWeek: 1, // Senin
        selectableDayPredicate: (date) =>
            !date.isBefore(firstDate) && !date.isAfter(lastDate),
        cancelButton: const Text('Batal'),
        okButton: const Text('Terapkan'),
      ),
      dialogSize: const Size(400, 500),
      value: [_start ?? now, _end ?? now],
      borderRadius: BorderRadius.circular(16),
    );

    if (values == null || values.length < 2 || !mounted) return;
    final start = values[0];
    final end = values[1];
    if (start == null || end == null) return;

    setState(() {
      _start = start;
      _end = end;
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionHistoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: const [PosAppBarActions()],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          const Divider(height: 1),
          Expanded(child: _buildBody(context, provider)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nomor transaksi + tombol cari/reset
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _invoiceController,
                  decoration: const InputDecoration(
                    hintText: 'Cari nomor transaksi...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _search,
                icon: const Icon(Icons.search),
                tooltip: 'Cari',
              ),
              if (_isFilterActive) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Filter tanggal / kasir / metode
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                label: _rangeLabel(),
                icon: Icons.date_range,
                onTap: _pickDateRange,
              ),
              if (_isAdmin)
                _kasirChip(context)
              else
                _paymentChip(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _kasirChip(BuildContext context) {
    return _filterChip(
      label: _kasirNameLabel(),
      icon: Icons.person,
      onTap: () => _showKasirPicker(context),
    );
  }

  Widget _paymentChip(BuildContext context) {
    return _filterChip(
      label: _payment == null ? 'Semua Metode' : paymentLabel(_payment!),
      icon: Icons.payment,
      onTap: () => _showPaymentPicker(context),
    );
  }

  String _kasirNameLabel() {
    if (_kasirId == null) return 'Semua Kasir';
    final user = _kasirList.where((u) => u.id == _kasirId).firstOrNull;
    return user?.name ?? 'Semua Kasir';
  }

  String _rangeLabel() {
    if (_start == null && _end == null) return 'Semua Tanggal';
    final fmt = DateFormat('dd/MM/yyyy');
    return '${_start != null ? fmt.format(_start!) : '…'} – '
        '${_end != null ? fmt.format(_end!) : '…'}';
  }

  Future<void> _showKasirPicker(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Kasir'),
          contentPadding: const EdgeInsets.only(top: 8, bottom: 4),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: RadioGroup<String>(
                groupValue: _kasirId ?? '',
                onChanged: (v) => Navigator.of(context).pop(v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RadioListTile<String>(
                      title: Text('Semua Kasir'),
                      value: '',
                    ),
                    ..._kasirList.map((k) {
                      return RadioListTile<String>(
                        title: Text(k.name),
                        subtitle: Text('@${k.username}'),
                        value: k.id,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
    if (selected == null) return;
    setState(() => _kasirId = selected.isEmpty ? null : selected);
    _search();
  }

  Future<void> _showPaymentPicker(BuildContext context) async {
    final methods = [
      ('', 'Semua Metode'),
      ('cash', 'Tunai'),
      ('qris', 'QRIS'),
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Metode Pembayaran'),
          contentPadding: const EdgeInsets.only(top: 8, bottom: 4),
          content: RadioGroup<String>(
            groupValue: _payment ?? '',
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: methods.map((m) {
                return RadioListTile<String>(
                  title: Text(m.$2),
                  value: m.$1,
                  dense: true,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
    if (selected == null) return;
    setState(() => _payment = selected.isEmpty ? null : selected);
    _search();
  }

  Widget _buildBody(BuildContext context, TransactionHistoryProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(provider.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _search,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (provider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Tidak ada transaksi ditemukan'),
            const SizedBox(height: 4),
            Text(
              'Coba ubah kata kunci atau filter pencarian.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _search,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '${formatNumber(provider.total)} transaksi ditemukan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...provider.items.map((t) => _TransactionTile(transaction: t)),
          if (provider.hasMore)
            Padding(
              padding: const EdgeInsets.all(8),
              child: provider.isLoadingMore
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton.icon(
                      onPressed: provider.loadMore,
                      icon: const Icon(Icons.more_horiz),
                      label: const Text('Muat Lebih'),
                    ),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final itemCount = transaction.items.fold<int>(0, (sum, i) => sum + i.qty);
    final method = transaction.paymentMethod;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: paymentColor(method).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            paymentIcon(method),
            color: paymentColor(method),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                transaction.invoiceNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: paymentColor(method).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                paymentLabel(method),
                style: TextStyle(
                  color: paymentColor(method),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(transaction.createdAt)}'
            '${transaction.createdByName.isNotEmpty ? ' • ${transaction.createdByName}' : ''}'
            ' • ${formatNumber(itemCount)} item',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatRupiah(transaction.total),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
        onTap: () => _openDetail(context),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
  }
}
