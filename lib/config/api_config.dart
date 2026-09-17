import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Konfigurasi alamat backend.
///
/// Alamat server bisa diubah langsung dari dalam aplikasi (layar login dan
/// Pengaturan Sistem) lalu disimpan di perangkat, sehingga tidak perlu build
/// ulang saat IP komputer server berubah.
///
/// Nilai ini sengaja disimpan lokal (SharedPreferences) dan bukan di database
/// backend, karena justru dibutuhkan sebelum aplikasi bisa menghubungi backend.
class ApiConfig {
  ApiConfig._();

  /// Kunci penyimpanan alamat server di perangkat.
  static const String prefsKey = 'api_base_url';

  /// Alamat dari build-time override (opsional), mis.:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000`
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// IP komputer bawaan (dipakai HP fisik maupun emulator).
  static const String defaultHost = '192.168.0.13';

  static const String defaultLanBaseUrl = 'http://$defaultHost:3000';

  /// Dipakai saat aplikasi berjalan di browser pada komputer yang sama.
  static const String localhostBaseUrl = 'http://localhost:3000';

  static const int defaultPort = 3000;

  static String? _savedBaseUrl;

  /// Alamat bawaan bila pengguna belum mengatur apa pun.
  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return normalize(_envBaseUrl);
    if (kIsWeb) return localhostBaseUrl;
    return defaultLanBaseUrl;
  }

  /// Alamat yang sedang dipakai seluruh service.
  static String get baseUrl {
    final saved = _savedBaseUrl;
    if (saved != null && saved.isNotEmpty) return saved;
    return defaultBaseUrl;
  }

  static String get apiUrl => '$baseUrl/api';

  /// True bila pengguna menyimpan alamatnya sendiri (bukan bawaan).
  static bool get isCustom => _savedBaseUrl != null && _savedBaseUrl!.isNotEmpty;

  /// Muat alamat tersimpan. Panggil sekali di `main()` sebelum `runApp()`.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedBaseUrl = prefs.getString(prefsKey);
    } catch (_) {
      // Bila penyimpanan tidak bisa dibaca, pakai alamat bawaan.
      _savedBaseUrl = null;
    }
  }

  /// Simpan alamat baru (dinormalisasi lebih dulu).
  static Future<void> save(String input) async {
    final normalized = normalize(input);
    _savedBaseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, normalized);
  }

  /// Kembalikan ke alamat bawaan.
  static Future<void> reset() async {
    _savedBaseUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  /// Rapikan input pengguna menjadi alamat lengkap tanpa garis miring di akhir.
  ///
  /// - `192.168.0.13`          -> `http://192.168.0.13:3000`
  /// - `192.168.0.13:3000`     -> `http://192.168.0.13:3000`
  /// - `http://192.168.0.13/`  -> `http://192.168.0.13:3000`
  /// - `192.168.0.13:8080`     -> `http://192.168.0.13:8080` (port tidak ditimpa)
  static String normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return defaultBaseUrl;

    if (!value.contains('://')) {
      value = 'http://$value';
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    final uri = Uri.tryParse(value);
    // Biarkan apa adanya bila tidak valid, agar validator UI yang menolaknya.
    if (uri == null || uri.host.isEmpty) return value;

    if (!uri.hasPort) {
      value = '$value:$defaultPort';
    }
    return value;
  }

  /// True bila [input] menghasilkan alamat server yang layak dipakai.
  static bool isValid(String input) {
    if (input.trim().isEmpty) return false;
    final normalized = normalize(input);
    final uri = Uri.tryParse(normalized);
    return uri != null && uri.host.isNotEmpty;
  }
}
