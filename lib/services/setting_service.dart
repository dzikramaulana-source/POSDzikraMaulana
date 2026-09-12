import '../models/app_settings.dart';
import 'api_service.dart';

class SettingService {
  // Ambil pengaturan sistem
  static Future<AppSettings> getSettings() async {
    final data = await ApiService.get('/settings');
    final map = (data?['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    return AppSettings.fromJson(map);
  }

  // Perbarui pengaturan sistem (khusus admin)
  static Future<AppSettings> updateSettings({required double taxRate}) async {
    final data = await ApiService.put('/settings', {'taxRate': taxRate});
    final map = (data?['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    return AppSettings.fromJson(map);
  }
}
