import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/notification_screen.dart';
import '../theme/app_colors.dart';
import 'pos_profile_chip.dart';

/// Aksi global di pojok kanan atas setiap layar menu:
/// tombol Notifikasi (dengan badge jumlah belum dibaca), tombol Logout (dengan konfirmasi),
/// dan profil chip pengguna.
class PosAppBarActions extends StatelessWidget {
  const PosAppBarActions({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 36),
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Pastikan seluruh transaksi aktif telah selesai atau shift telah ditutup sebelum keluar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
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
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 22, color: AppColors.textMuted),
          tooltip: 'Logout',
          onPressed: () => _logout(context),
        ),
        const PosProfileChip(),
      ],
    );
  }
}
