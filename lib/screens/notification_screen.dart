import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';

/// Layar daftar notifikasi dengan dua kategori (tab):
/// - Transaksi (type = transaction)
/// - Stok (type = stock_low dan stock_out; stok menipis & habis digabung)
///
/// Admin menerima transaksi berhasil dari seluruh kasir, sedangkan kasir hanya
/// menerima transaksinya sendiri. Notifikasi bertipe broadcast (pengumuman
/// admin) tidak ditampilkan di layar ini. Item belum dibaca ditandai; tap untuk
/// menandai dibaca.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

/// Satu kategori tab pada layar Notifikasi. Satu tab bisa memuat beberapa tipe
/// (mis. tab Stok memuat stok menipis dan stok habis sekaligus).
class _NotificationTab {
  final String label;
  final List<NotificationType> types;
  final IconData icon;
  final String emptyMessage;

  const _NotificationTab({
    required this.label,
    required this.types,
    required this.icon,
    required this.emptyMessage,
  });
}

/// Kategori notifikasi beserta urutan tabnya.
const List<_NotificationTab> _tabs = [
  _NotificationTab(
    label: 'Transaksi',
    types: [NotificationType.transaction],
    icon: Icons.receipt_long_outlined,
    emptyMessage: 'Belum ada notifikasi\ntransaksi berhasil',
  ),
  _NotificationTab(
    label: 'Stok',
    types: [NotificationType.stockLow, NotificationType.stockOut],
    icon: Icons.inventory_2_outlined,
    emptyMessage: 'Belum ada notifikasi\nstok menipis atau habis',
  ),
];

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  List<NotificationType> get _activeTypes => _tabs[_tabIndex].types;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  // Bangun ulang layar saat tab berpindah agar aksi AppBar ("Tandai semua
  // dibaca") mengikuti tab yang sedang aktif.
  void _handleTabChange() {
    if (_tabController.index == _tabIndex) return;
    setState(() => _tabIndex = _tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.border),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  for (final tab in _tabs)
                    _TabLabel(
                      label: tab.label,
                      icon: tab.icon,
                      count: _unreadCount(provider, tab.types),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (_visibleItems(provider).isNotEmpty)
            _AppBarAction(
              icon: Icons.done_all_rounded,
              tooltip: 'Tandai semua dibaca',
              enabled: _unreadCount(provider, _activeTypes) > 0,
              onPressed: () => provider.markAllRead(types: _activeTypes),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in _tabs) _buildBody(context, provider, tab),
        ],
      ),
    );
  }

  /// Notifikasi pada tab aktif (broadcast tidak pernah ditampilkan).
  List<AppNotification> _visibleItems(NotificationProvider provider) {
    return [
      for (final n in provider.items)
        if (_activeTypes.contains(n.type)) n,
    ];
  }

  int _unreadCount(NotificationProvider provider, List<NotificationType> types) {
    return provider.items.where((n) => types.contains(n.type) && !n.read).length;
  }

  Widget _buildBody(
    BuildContext context,
    NotificationProvider provider,
    _NotificationTab tab,
  ) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.error != null && provider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 40, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            Text(
              provider.error!,
              style: const TextStyle(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final items = [
      for (final n in provider.items)
        if (tab.types.contains(n.type)) n,
    ];

    if (items.isEmpty) {
      final icon = tab.icon;
      final message = tab.emptyMessage;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => provider.refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _NotificationCard(notification: items[index]);
        },
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onPressed : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surfaceVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textMedium : AppColors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
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
      height: 48,
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
                color: AppColors.danger,
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

  (IconData, Color, Color) get _style {
    switch (notification.type) {
      case NotificationType.transaction:
        return (Icons.receipt_long_outlined, AppColors.success, AppColors.successLight);
      case NotificationType.stockLow:
        return (Icons.warning_amber_rounded, AppColors.warning, AppColors.warningLight);
      case NotificationType.stockOut:
        return (Icons.inventory_2_outlined, AppColors.danger, AppColors.dangerLight);
      case NotificationType.broadcast:
        return (Icons.campaign_outlined, AppColors.primary, AppColors.primaryLight);
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
    final (icon, fgColor, bgColor) = _style;
    final unread = !notification.read;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: unread ? bgColor : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unread
              ? fgColor.withValues(alpha: 0.25)
              : AppColors.border,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (unread) {
            context.read<NotificationProvider>().markAsRead(notification.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon kategori
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: fgColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: fgColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Konten
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight:
                            unread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeLabel(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status dot
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: fgColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
