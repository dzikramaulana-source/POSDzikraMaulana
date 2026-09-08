import '../models/transaction.dart';
import 'api_service.dart';

class TransactionService {
  // Buat transaksi baru
  static Future<Transaction> createTransaction({
    required List<CartItem> items,
    required String paymentMethod,
    required double cashReceived,
  }) async {
    final data = await ApiService.post('/transactions', {
      'items': items.map((e) => e.toJson()).toList(),
      'paymentMethod': paymentMethod,
      'cashReceived': cashReceived,
    });
    return Transaction.fromJson(data['transaction'] as Map<String, dynamic>);
  }

  // Ambil daftar transaksi (opsional filter tanggal YYYY-MM-DD)
  static Future<List<Transaction>> getTransactions({String? date}) async {
    final query = date != null ? '?date=$date' : '';
    final data = await ApiService.get('/transactions$query');
    final list = data['transactions'] as List? ?? [];
    return list
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Cari riwayat transaksi: filter nomor invoice, rentang tanggal, kasir, metode bayar
  static Future<TransactionHistoryPage> searchTransactions({
    String? invoice,
    DateTime? start,
    DateTime? end,
    String? kasirId,
    String? payment,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (invoice != null && invoice.trim().isNotEmpty) {
      params['invoice'] = invoice.trim();
    }
    if (start != null) {
      params['start'] = start.toIso8601String().split('T').first;
    }
    if (end != null) {
      params['end'] = end.toIso8601String().split('T').first;
    }
    if (kasirId != null && kasirId.isNotEmpty) {
      params['kasirId'] = kasirId;
    }
    if (payment != null && payment.isNotEmpty) {
      params['payment'] = payment;
    }

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final data = await ApiService.get('/transactions/history?$queryString');
    return TransactionHistoryPage.fromJson(data as Map<String, dynamic>);
  }

  // Ambil detail transaksi
  static Future<Transaction> getTransaction(String id) async {
    final data = await ApiService.get('/transactions/$id');
    return Transaction.fromJson(data['transaction'] as Map<String, dynamic>);
  }
}
