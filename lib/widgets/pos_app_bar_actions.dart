import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/notification_screen.dart';

/// Aksi global di pojok kanan atas setiap layar menu:
/// tombol Notifikasi (dengan badge jumlah belum dibaca) dan Logout.
class PosAppBarActions extends StatelessWidget {
  const PosAppBarActions({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    // AuthGate (home) otomatis menampilkan LoginScreen setelah _user = null.
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notifikasi (bel + badge jumlah belum dibaca)
        Builder(
          builder: (context) {
            final unread = context.watch<NotificationProvider>().unread;
            return IconButton(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
              tooltip: 'Notifikasi',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () => _logout(context),
        ),
      ],
    );
  }
}
