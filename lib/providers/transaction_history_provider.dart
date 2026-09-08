import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

/// State untuk halaman Riwayat Transaksi: hasil pencarian + pagination.
class TransactionHistoryProvider extends ChangeNotifier {
  List<Transaction> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;

  // Filter aktif
  String _invoice = '';
  DateTime? _start;
  DateTime? _end;
  String? _kasirId;
  String? _payment;

  List<Transaction> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  int get total => _total;
  bool get hasMore => _page < _totalPages;

  void setInvoice(String value) => _invoice = value.trim();
  void setStart(DateTime? value) => _start = value;
  void setEnd(DateTime? value) => _end = value;
  void setKasirId(String? value) => _kasirId = value;
  void setPayment(String? value) => _payment = value;

  // Muat halaman pertama dengan filter aktif (reset list)
  Future<void> search({int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await TransactionService.searchTransactions(
        invoice: _invoice.isEmpty ? null : _invoice,
        start: _start,
        end: _end,
        kasirId: _kasirId,
        payment: _payment,
        page: page,
      );
      _items = result.items;
      _page = result.page;
      _total = result.total;
      _totalPages = result.totalPages;
    } catch (e) {
      _error = e.toString();
      _items = [];
      _total = 0;
      _totalPages = 1;
      _page = 1;
    }
    _isLoading = false;
    notifyListeners();
  }

  // Muat halaman berikutnya (append)
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final result = await TransactionService.searchTransactions(
        invoice: _invoice.isEmpty ? null : _invoice,
        start: _start,
        end: _end,
        kasirId: _kasirId,
        payment: _payment,
        page: _page + 1,
      );
      _items = [..._items, ...result.items];
      _page = result.page;
      _total = result.total;
      _totalPages = result.totalPages;
    } catch (e) {
      _error = e.toString();
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
  }
}
