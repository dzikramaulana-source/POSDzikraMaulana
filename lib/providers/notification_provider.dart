import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  static const Duration pollingInterval = Duration(seconds: 25);

  List<AppNotification> _items = [];
  int _unread = 0;
  bool _isLoading = false;
  String? _error;
  Timer? _timer;

  List<AppNotification> get items => _items;
  int get unread => _unread;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Mulai polling berkala (real-time via refresh)
  void startPolling() {
    _timer ??= Timer.periodic(pollingInterval, (_) => refresh());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await NotificationService.getNotifications();
      _unread = await NotificationService.getUnreadCount();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    // Optimis: tandai lokal dulu
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final item = _items[index];
    if (item.read) return;

    _items[index] = AppNotification(
      id: item.id,
      type: item.type,
      title: item.title,
      body: item.body,
      read: true,
      relatedId: item.relatedId,
      createdAt: item.createdAt,
    );
    _unread = _unread > 0 ? _unread - 1 : 0;
    notifyListeners();

    try {
      await NotificationService.markRead(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllRead({NotificationType? type}) async {
    final typeName = type == null ? null : _typeName(type);
    try {
      await NotificationService.markAllRead(type: typeName);
      _items = [
        for (final n in _items)
          if (type == null || n.type == type)
            AppNotification(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              read: true,
              relatedId: n.relatedId,
              createdAt: n.createdAt,
            )
          else
            n,
      ];
      _unread = _items.where((n) => !n.read).length;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    final target = _items.where((n) => n.id == id).firstOrNull;
    if (target == null) return;

    _items = _items.where((n) => n.id != id).toList();
    if (!target.read && _unread > 0) {
      _unread -= 1;
    }
    notifyListeners();

    try {
      await NotificationService.deleteNotification(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Kirim pengumuman admin ke semua kasir. Kembalikan jumlah kasir penerima.
  Future<int?> broadcast({required String title, required String body}) async {
    try {
      final sent = await NotificationService.broadcast(title: title, body: body);
      return sent;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
  }
}

/// Konversi enum tipe notifikasi ke nilai string yang dipakai API.
String _typeName(NotificationType type) {
  switch (type) {
    case NotificationType.transaction:
      return 'transaction';
    case NotificationType.stock:
      return 'stock';
    case NotificationType.broadcast:
      return 'broadcast';
  }
}
