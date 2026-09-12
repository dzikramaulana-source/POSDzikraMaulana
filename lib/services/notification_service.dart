import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  // Daftar notifikasi milik user yang login.
  // [type] opsional: 'transaction', 'stock', atau 'broadcast'.
  static Future<List<AppNotification>> getNotifications({
    String? type,
  }) async {
    var path = '/notifications';
    if (type != null) path = '$path?type=$type';
    final data = await ApiService.get(path);
    final list = data?['notifications'] as List? ?? [];
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Jumlah notifikasi belum dibaca
  static Future<int> getUnreadCount() async {
    final data = await ApiService.get('/notifications/unread-count');
    return (data?['unread'] as num?)?.toInt() ?? 0;
  }

  // Tandai satu notifikasi sudah dibaca
  static Future<void> markRead(String id) async {
    await ApiService.patch('/notifications/$id/read', {});
  }

  // Tandai semua notifikasi sudah dibaca.
  // [type] opsional: batasi ke tipe tertentu (transaction/stock/broadcast).
  static Future<void> markAllRead({String? type}) async {
    var path = '/notifications/read-all';
    if (type != null) path = '$path?type=$type';
    await ApiService.post(path, {});
  }

  // Hapus satu notifikasi
  static Future<void> deleteNotification(String id) async {
    await ApiService.delete('/notifications/$id');
  }

  // Kirim pengumuman ke semua kasir (khusus admin)
  static Future<int> broadcast({
    required String title,
    required String body,
  }) async {
    final data = await ApiService.post('/notifications/broadcast', {
      'title': title,
      'body': body,
    });
    return (data?['sent'] as num?)?.toInt() ?? 0;
  }
}
