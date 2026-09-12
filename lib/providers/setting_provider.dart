import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../services/setting_service.dart';

class SettingProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings(taxRate: AppSettings.defaultTaxRate);
  bool _isLoading = false;
  String? _error;

  AppSettings get settings => _settings;

  /// Tarif PPN dalam persen (mis. 10).
  double get taxRate => _settings.taxRate;

  /// Tarif PPN sebagai pecahan (mis. 0.10).
  double get taxRateFraction => _settings.taxRateFraction;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Muat pengaturan sistem dari backend
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await SettingService.getSettings();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // Simpan tarif PPN (khusus admin). Kembalikan true bila berhasil.
  Future<bool> saveTaxRate(double taxRate) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await SettingService.updateSettings(taxRate: taxRate);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
