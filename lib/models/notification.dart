/// Jenis notifikasi.
enum NotificationType { transaction, stock, broadcast }

NotificationType _parseType(String? value) {
  switch (value) {
    case 'stock':
      return NotificationType.stock;
    case 'broadcast':
      return NotificationType.broadcast;
    default:
      return NotificationType.transaction;
  }
}

/// Satu notifikasi untuk kasir (transaksi, stok, atau pengumuman).
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool read;
  final String relatedId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.relatedId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id']?.toString() ?? '',
      type: _parseType(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      read: json['read'] == true,
      relatedId: json['relatedId']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}
