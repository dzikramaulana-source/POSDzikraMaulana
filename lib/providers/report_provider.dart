import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../services/report_service.dart';

class ReportProvider extends ChangeNotifier {
  PeriodReport? _report;
  bool _isLoading = false;
  String? _error;
  DateTime? _start;
  DateTime? _end;

  PeriodReport? get report => _report;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get start => _start;
  DateTime? get end => _end;

  // Muat laporan analisis untuk periode baru
  Future<void> load({required DateTime start, required DateTime end}) async {
    _isLoading = true;
    _error = null;
    _start = start;
    _end = end;
    notifyListeners();
    try {
      _report = await ReportService.getPeriodReport(start: start, end: end);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
  }
}
