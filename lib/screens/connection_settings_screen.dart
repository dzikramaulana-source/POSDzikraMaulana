import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Layar pengaturan alamat server backend.
///
/// Bisa dibuka dari layar login (sebelum masuk) maupun dari Pengaturan Sistem,
/// sehingga IP komputer server dapat diubah tanpa perlu build ulang aplikasi.
/// Layar ini sengaja tidak memakai Provider apa pun agar aman dibuka sebelum
/// pengguna login.
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;

  bool _isTesting = false;
  bool _isSaving = false;
  bool _testSuccess = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  // Setiap perubahan teks membatalkan hasil tes sebelumnya agar tidak menyesatkan
  void _onAddressChanged(String _) {
    setState(() => _testMessage = null);
  }

  /// Ubah error teknis menjadi pesan yang bisa ditindaklanjuti pengguna.
  /// Tidak memakai dart:io agar tetap aman di web.
  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'Waktu habis. Pastikan backend berjalan dan perangkat berada di Wi-Fi yang sama.';
    }
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('XMLHttpRequest') ||
        text.contains('Failed host lookup')) {
      return 'Tidak dapat menjangkau server. Periksa alamat IP dan koneksi jaringan.';
    }
    return text;
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Uji koneksi langsung ke root endpoint (tanpa lewat ApiService, karena
  /// ApiService menambahkan prefix `/api` dan header autentikasi).
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    final url = ApiConfig.normalize(_addressController.text);
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$url/'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      setState(() {
        _isTesting = false;
        _testSuccess = ok;
        _testMessage = ok
            ? 'Terhubung — POS API berjalan'
            : 'Server merespons dengan status ${response.statusCode}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testMessage = 'Gagal terhubung: ${_friendlyError(error)}';
      });
    }
  }

  /// Terapkan alamat baru: minta konfirmasi bila ada sesi login aktif, karena
  /// token lama milik server sebelumnya. Kembalikan false bila dibatalkan.
  Future<bool> _applyAddress(String newBaseUrl) async {
    final changed = newBaseUrl != ApiConfig.baseUrl;

    if (changed && await ApiService.getToken() != null) {
      if (!mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ubah Alamat Server'),
          content: const Text(
            'Mengubah alamat server akan mengeluarkan Anda dari sesi saat ini. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      );
      if (!mounted || proceed != true) return false;
    }

    // Alamat yang sama dengan bawaan berarti kembali ke bawaan, sehingga
    // penanda "diatur manual" tidak menyala tanpa alasan.
    if (newBaseUrl == ApiConfig.defaultBaseUrl) {
      await ApiConfig.reset();
    } else {
      await ApiConfig.save(newBaseUrl);
    }

    if (changed) {
      // Token lama tidak berlaku untuk server baru.
      await ApiService.clearToken();
    }
    return true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final target = ApiConfig.normalize(_addressController.text);
    setState(() => _isSaving = true);
    final applied = await _applyAddress(target);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _addressController.text = ApiConfig.baseUrl;
    });

    if (applied) {
      _showSnack('Alamat server disimpan: ${ApiConfig.baseUrl}', success: true);
    }
  }

  Future<void> _resetToDefault() async {
    if (!ApiConfig.isCustom) return;

    final target = ApiConfig.defaultBaseUrl;
    setState(() => _isSaving = true);
    final applied = await _applyAddress(target);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _addressController.text = ApiConfig.baseUrl;
      _testMessage = null;
    });

    if (applied) {
      _showSnack(
        'Alamat dikembalikan ke bawaan: ${ApiConfig.baseUrl}',
        success: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pengaturan Koneksi Server')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildAddressCard(),
                const SizedBox(height: 16),
                _buildHelpCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
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
            child: const Icon(Icons.dns_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koneksi Server',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Alamat backend yang dipakai aplikasi ini. Ubah bila IP komputer server berubah.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
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
                const Icon(Icons.lan_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Alamat IP Server',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                if (ApiConfig.isCustom)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Diatur manual',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              onChanged: _onAddressChanged,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Alamat Server',
                hintText: 'Contoh: 192.168.0.13',
                prefixIcon: Icon(Icons.link_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Alamat server wajib diisi';
                }
                if (!ApiConfig.isValid(value)) {
                  return 'Alamat server tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Cukup ketik IP komputer. Port 3000 dan http:// ditambahkan otomatis.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            _buildPreview(),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _isTesting || _isSaving ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: const Text(
                  'Tes Koneksi',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _buildTestResult(),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
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
                  'Simpan Alamat Server',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (ApiConfig.isCustom) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isSaving ? null : _resetToDefault,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text(
                  'Kembalikan ke Bawaan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pratinjau alamat final setelah input pengguna dirapikan.
  Widget _buildPreview() {
    final valid = ApiConfig.isValid(_addressController.text);
    final preview = valid ? ApiConfig.normalize(_addressController.text) : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Alamat yang akan dipakai',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResult() {
    final message = _testMessage;
    if (message == null) return const SizedBox.shrink();

    final color = _testSuccess ? AppColors.success : AppColors.danger;
    final background =
        _testSuccess ? AppColors.successLight : AppColors.dangerLight;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _testSuccess
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Text(
                'Cara mengetahui alamat server',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHelpStep('1', 'Di komputer server, buka CMD lalu jalankan perintah ipconfig.'),
          _buildHelpStep('2', 'Lihat baris "IPv4 Address" pada adapter Wi-Fi, misalnya 192.168.0.13.'),
          _buildHelpStep('3', 'HP dan komputer harus tersambung ke jaringan Wi-Fi yang sama.'),
          _buildHelpStep('4', 'Backend harus berjalan di komputer (node server.js di folder backend).'),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
