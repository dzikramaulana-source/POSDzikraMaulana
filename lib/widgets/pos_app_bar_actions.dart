import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../screens/notification_screen.dart';
import '../theme/app_colors.dart';
import 'pos_profile_chip.dart';

/// Aksi global di pojok kanan atas setiap layar menu:
/// tombol Notifikasi (dengan badge jumlah belum dibaca) dan profil chip pengguna
/// yang membuka dropdown "Profil"/"Keluar".
class PosAppBarActions extends StatelessWidget {
  const PosAppBarActions({super.key});

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
                backgroundColor: AppColors.danger,
                label: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                child: const Icon(Icons.notifications_outlined, size: 22),
              ),
              tooltip: 'Notifikasi',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        const PosProfileChip(),
      ],
    );
  }
}
