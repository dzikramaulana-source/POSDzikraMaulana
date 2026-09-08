import '../models/shift.dart';
import 'api_service.dart';

class ShiftService {
  // Buka shift baru dengan kas awal
  static Future<Map<String, dynamic>> openShift({
    required double openingCash,
  }) async {
    final data = await ApiService.post('/shifts/open', {
      'openingCash': openingCash,
    });
    return (data as Map?)?.cast<String, dynamic>() ?? {};
  }

  // Ambil shift aktif milik kasir + ringkasan berjalan
  static Future<({Shift? shift, ShiftSummary? summary})> getCurrentShift() async {
    final data = await ApiService.get('/shifts/current');
    final shiftJson = data?['shift'] as Map<String, dynamic>?;
    final summaryJson = data?['summary'] as Map<String, dynamic>?;
    return (
      shift: shiftJson != null ? Shift.fromJson(shiftJson) : null,
      summary:
          summaryJson != null ? ShiftSummary.fromJson(summaryJson) : null,
    );
  }

  // Daftar shift (backend menyesuaikan role: kasir hanya miliknya, admin semua)
  static Future<List<Shift>> getShifts() async {
    final data = await ApiService.get('/shifts');
    final list = data?['shifts'] as List? ?? [];
    return list
        .map((e) => Shift.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Detail shift + ringkasan + rekap kas
  static Future<Map<String, dynamic>> getShiftDetail(String id) async {
    final data = await ApiService.get('/shifts/$id');
    return (data as Map?)?.cast<String, dynamic>() ?? {};
  }

  // Tutup shift dengan kas akhir (uang fisik)
  static Future<Map<String, dynamic>> closeShift(
    String id, {
    required double closingCash,
  }) async {
    final data = await ApiService.post('/shifts/close/$id', {
      'closingCash': closingCash,
    });
    return (data as Map?)?.cast<String, dynamic>() ?? {};
  }
}
