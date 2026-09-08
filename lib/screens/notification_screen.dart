import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart';
import '../providers/notification_provider.dart';

/// Layar daftar notifikasi dengan dua kategori (tab):
/// - Transaksi Berhasil (type = transaction)
/// - Stok Habis (type = stock)
///
/// Notifikasi bertipe broadcast (pengumuman admin) tidak ditampilkan di layar
/// ini. Item belum dibaca ditandai; tap untuk menandai dibaca.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Tab 0 = transaction, tab 1 = stock.
  NotificationType get _activeType =>
      _tabController.index == 0 ? NotificationType.transaction : NotificationType.stock;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            _TabLabel(
              label: 'Transaksi Berhasil',
              icon: Icons.receipt_long,
              count: _unreadCount(provider, NotificationType.transaction),
            ),
            _TabLabel(
              label: 'Stok Habis',
              icon: Icons.inventory,
              count: _unreadCount(provider, NotificationType.stock),
            ),
          ],
        ),
        actions: [
          if (_visibleItems(provider).isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Tandai semua dibaca',
              onPressed:
                  _unreadCount(provider, _activeType) > 0
                      ? () => provider.markAllRead(type: _activeType)
                      : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Hapus semua',
              onPressed: () => _confirmClearAll(context),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBody(context, provider, NotificationType.transaction),
                _buildBody(context, provider, NotificationType.stock),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Notifikasi pada tab aktif (broadcast tidak pernah ditampilkan).
  List<AppNotification> _visibleItems(NotificationProvider provider) {
    return [
      for (final n in provider.items)
        if (n.type == _activeType) n,
    ];
  }

  int _unreadCount(NotificationProvider provider, NotificationType type) {
    return provider.items.where((n) => n.type == type && !n.read).length;
  }

  Widget _buildBody(
    BuildContext context,
    NotificationProvider provider,
    NotificationType type,
  ) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Center(child: Text(provider.error!)),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: () => provider.refresh(),
              child: const Text('Coba Lagi'),
            ),
          ),
        ],
      );
    }

    final items = [
      for (final n in provider.items)
        if (n.type == type) n,
    ];

    if (items.isEmpty) {
      final message = type == NotificationType.transaction
          ? 'Belum ada notifikasi transaksi berhasil'
          : 'Belum ada notifikasi stok habis';
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            type == NotificationType.transaction
                ? Icons.receipt_long
                : Icons.inventory,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Center(child: Text(message)),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final notification = items[index];
          return _NotificationCard(notification: notification);
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final type = _activeType;
    final label = type == NotificationType.transaction
        ? 'Transaksi Berhasil'
        : 'Stok Habis';

    // Ambil provider sebelum async gap agar tidak memakai context setelah await
    final provider = context.read<NotificationProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Notifikasi'),
        content: Text('Yakin ingin menghapus semua notifikasi $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.clearAll(type: type);
    }
  }
}

/// Label tab dengan ikon & badge jumlah belum dibaca.
class _TabLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;

  const _TabLabel({
    required this.label,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  (IconData, Color) get _style {
    switch (notification.type) {
      case NotificationType.transaction:
        return (Icons.receipt_long, Colors.green);
      case NotificationType.stock:
        return (Icons.inventory, Colors.orange);
      case NotificationType.broadcast:
        return (Icons.campaign, Colors.blue);
    }
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;
    final unread = !notification.read;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: unread ? color.withValues(alpha: 0.06) : null,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: unread ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              _timeLabel(notification.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: unread
            ? Icon(Icons.circle, size: 12, color: color)
            : const Icon(Icons.check_circle_outline,
                size: 16, color: Colors.grey),
        onTap: () {
          if (unread) {
            context.read<NotificationProvider>().markAsRead(notification.id);
          }
        },
      ),
    );
  }
}
