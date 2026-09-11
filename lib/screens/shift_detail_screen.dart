import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../services/shift_service.dart';
import '../theme/app_colors.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Detail Shift',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 40, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
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
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Info Shift ──
          _SectionCard(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: shift.isOpen
                          ? AppColors.successLight
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      shift.isOpen
                          ? Icons.play_circle_outline
                          : Icons.stop_circle_outlined,
                      color: shift.isOpen
                          ? AppColors.success
                          : AppColors.textMuted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Shift',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: shift.isOpen
                              ? AppColors.successLight
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: shift.isOpen
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: shift.isOpen
                                    ? AppColors.success
                                    : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              shift.isOpen ? 'Sedang Aktif' : 'Sudah Ditutup',
                              style: TextStyle(
                                color: shift.isOpen
                                    ? AppColors.success
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (shift.autoClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Auto Closed',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 18),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Kasir',
                value: shift.kasirName.isEmpty ? shift.kasirId : shift.kasirName,
              ),
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.login_outlined,
                label: 'Buka Shift',
                value: _fmtDateTime(shift.openedAt),
              ),
              if (shift.closedAt != null) ...[
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.logout_outlined,
                  label: 'Tutup Shift',
                  value: _fmtDateTime(shift.closedAt!),
                ),
              ],
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.savings_outlined,
                label: 'Kas Awal',
                value: formatRupiah(shift.openingCash),
              ),
              if (shift.closingCash != null) ...[
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Kas Akhir (Fisik)',
                  value: formatRupiah(shift.closingCash!),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Ringkasan Transaksi ──
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Ringkasan Transaksi',
          ),
          const SizedBox(height: 10),
          _SectionCard(
            children: [
              _SummaryRow(
                label: 'Jumlah Transaksi',
                value: '${summary.totalTransactions} transaksi',
              ),
              const SizedBox(height: 12),
              _SummaryRow(
                label: 'Total Penjualan',
                value: formatRupiah(summary.totalSales),
                emphasized: true,
              ),
              const SizedBox(height: 12),
              _SummaryRow(
                label: 'Penjualan Tunai',
                value: formatRupiah(summary.cashSales),
              ),
              if (summary.paymentSummary.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                ...summary.paymentSummary.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color:
                                  paymentColor(p.method).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              paymentIcon(p.method),
                              size: 16,
                              color: paymentColor(p.method),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paymentLabel(p.method),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  '${p.count} transaksi',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatRupiah(p.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),

          // ── Rekap Kas ──
          if (!shift.isOpen) ...[
            const SizedBox(height: 16),
            _SectionHeader(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Rekap Kas',
            ),
            const SizedBox(height: 10),
            _SectionCard(
              children: [
                _RekapRow(
                  label: 'Kas Sistem',
                  sublabel: 'Kas awal + penjualan tunai',
                  value: formatRupiah(_expectedCash ?? 0),
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                _RekapRow(
                  label: 'Uang Fisik',
                  sublabel: 'Kas akhir dicatat kasir',
                  value: formatRupiah(shift.closingCash ?? 0),
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                _buildDifference(_difference),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Shift ini masih berjalan. Tutup shift untuk melihat rekap kas dan selisih.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDifference(double? difference) {
    if (difference == null) return const SizedBox.shrink();

    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String label;

    if (difference > 0) {
      bgColor = AppColors.successLight;
      fgColor = AppColors.success;
      icon = Icons.arrow_upward_rounded;
      label = 'Lebih ${formatRupiah(difference)}';
    } else if (difference < 0) {
      bgColor = AppColors.dangerLight;
      fgColor = AppColors.danger;
      icon = Icons.arrow_downward_rounded;
      label = 'Kurang ${formatRupiah(difference.abs())}';
    } else {
      bgColor = AppColors.primaryLight;
      fgColor = AppColors.primary;
      icon = Icons.check_rounded;
      label = 'Pas / Tidak Ada Selisih';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fgColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fgColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selisih Kas',
                style: TextStyle(
                  fontSize: 11,
                  color: fgColor.withValues(alpha: 0.8),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime dt) =>
      DateFormat('EEE, dd MMM yyyy • HH:mm', 'id_ID').format(dt);
}

// ─── Helper Widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
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
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: emphasized ? AppColors.textDark : AppColors.textMedium,
              fontWeight:
                  emphasized ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: emphasized ? 16 : 14,
            color: emphasized ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _RekapRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;

  const _RekapRow({
    required this.label,
    required this.sublabel,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                sublabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
