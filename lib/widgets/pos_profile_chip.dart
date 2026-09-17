import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/whatsapp_sender.dart';

/// Nomor WhatsApp admin yang bisa dihubungi kasir dari menu Profil.
const String _adminWhatsApp = '082263078191';

/// Label peran yang ramah ditampilkan, mis. "admin" -> "Admin".
String _roleLabel(String? role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'kasir':
      return 'Kasir';
    default:
      return role ?? 'Pengguna';
  }
}

/// Bagian profil pengguna di pojok kanan atas dengan desain modern.
/// Klik untuk membuka dropdown berisi "Profil Kasir" dan "Keluar".
class PosProfileChip extends StatelessWidget {
  const PosProfileChip({super.key});

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

  Future<void> _chatAdmin(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/${normalizeWhatsAppNumber(_adminWhatsApp)}',
    );
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
      );
    }
  }

  void _showProfile(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final name = user?.name ?? 'Pengguna';
    final role = _roleLabel(user?.role);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isAdmin = user?.role == 'admin';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: CircleAvatar(
          radius: 26,
          backgroundColor: isAdmin
              ? const Color(0xFF1D4ED8)
              : const Color(0xFF047857),
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isAdmin ? AppColors.primaryLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isAdmin ? AppColors.primary : AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    size: 22,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WhatsApp Admin',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '0822-6307-8191',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () => _chatAdmin(context),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Chat Admin'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.name ?? 'Pengguna';
    final role = _roleLabel(user?.role);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isAdmin = user?.role == 'admin';

    final badgeBg = isAdmin ? AppColors.primaryLight : AppColors.successLight;
    final badgeTextColor = isAdmin ? AppColors.primary : AppColors.success;

    final showText = MediaQuery.sizeOf(context).width >= 820;

    return PopupMenuButton<String>(
      tooltip: 'Menu Profil',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'profil') {
          _showProfile(context);
        } else if (value == 'keluar') {
          _logout(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profil',
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Profil $role'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'keluar',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Keluar', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(left: 6, top: 4, bottom: 4, right: 12),
        padding: EdgeInsets.fromLTRB(showText ? 8 : 4, 4, showText ? 12 : 4, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAdmin
                          ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                          : [const Color(0xFF10B981), const Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            if (showText) ...[
              const SizedBox(width: 9),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
