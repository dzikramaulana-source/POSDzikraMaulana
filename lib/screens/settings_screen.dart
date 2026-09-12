import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/setting_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatter.dart';
import '../widgets/pos_app_bar_actions.dart';

/// Halaman Pengaturan Sistem (khusus admin).
///
/// Saat ini mengatur tarif PPN default yang dipakai untuk transaksi baru.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taxRateController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<SettingProvider>();
      await provider.load();
      if (mounted && _taxRateController.text.isEmpty) {
        _taxRateController.text = _formatRate(provider.taxRate);
      }
    });
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    super.dispose();
  }

  String _formatRate(double percent) {
    if (percent == percent.roundToDouble()) return percent.toStringAsFixed(0);
    return percent
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  double? _parsedRate() {
    final text = _taxRateController.text.trim().replaceAll(',', '.');
    return double.tryParse(text);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final rate = _parsedRate()!;
    setState(() => _isSaving = true);
    final provider = context.read<SettingProvider>();
    final success = await provider.saveTaxRate(rate);
    if (!mounted) return;

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Pengaturan PPN disimpan (${_formatRate(rate)}%)'
              : provider.error ?? 'Gagal menyimpan pengaturan',
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Sistem'),
        actions: const [PosAppBarActions()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final provider = context.watch<SettingProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Sistem',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Atur nilai default yang berlaku untuk seluruh aplikasi',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kartu PPN
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Pajak PPN',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Saat ini: ${_formatRate(provider.taxRate)}%',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tarif ini otomatis ditambahkan ke total pembayaran transaksi baru.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _taxRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tarif PPN (%)',
                    hintText: 'Contoh: 10',
                    prefixIcon: Icon(Icons.percent_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final rate = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (rate == null) return 'Masukkan angka tarif PPN';
                    if (rate < 0 || rate > 100) return 'Tarif harus antara 0 - 100';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Isi 0 bila transaksi tidak dikenakan PPN.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _isSaving || provider.isLoading ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text(
                      'Simpan Pengaturan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Preview contoh perhitungan
        _buildPreviewCard(),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final rate = _parsedRate();
    final valid = rate != null && rate >= 0 && rate <= 100;
    const sample = 100000.0;
    final sampleTax = valid ? (sample * rate / 100).roundToDouble() : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Contoh perhitungan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valid
                ? 'Subtotal ${formatRupiah(sample)}  •  PPN ${_formatRate(rate)}% = ${formatRupiah(sampleTax)}  •  Total ${formatRupiah(sample + sampleTax)}'
                : 'Masukkan tarif yang valid untuk melihat contoh perhitungan.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}
