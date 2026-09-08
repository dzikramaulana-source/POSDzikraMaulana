import 'package:flutter/foundation.dart';
import '../models/shift.dart';
import '../services/shift_service.dart';

class ShiftProvider extends ChangeNotifier {
  Shift? _activeShift;
  ShiftSummary? _activeSummary;
  List<Shift> _history = [];
  bool _isLoading = false;
  String? _error;

  Shift? get activeShift => _activeShift;
  ShiftSummary? get activeSummary => _activeSummary;
  List<Shift> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Muat shift aktif (kasir) beserta ringkasan berjalan
  Future<void> loadCurrent() async {
    _setLoading();
    try {
      final result = await ShiftService.getCurrentShift();
      _activeShift = result.shift;
      _activeSummary = result.summary;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // Muat riwayat shift (kasir: miliknya; admin: semua)
  Future<void> loadHistory() async {
    _setLoading();
    try {
      _history = await ShiftService.getShifts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.wait([loadCurrent(), loadHistory()]);
  }

  // Buka shift baru. Kembalikan Map respons (bisa berisi autoClosed).
  Future<Map<String, dynamic>?> openShift(double openingCash) async {
    try {
      final result = await ShiftService.openShift(openingCash: openingCash);
      await refresh();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Tutup shift dengan kas akhir. Kembalikan Map respons berisi rekap.
  Future<Map<String, dynamic>?> closeShift(
    String shiftId,
    double closingCash,
  ) async {
    try {
      final result = await ShiftService.closeShift(
        shiftId,
        closingCash: closingCash,
      );
      await refresh();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
  }

  void _setLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }
}
