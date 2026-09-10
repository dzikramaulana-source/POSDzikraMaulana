import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Label peran yang ramah ditampilkan, mis. "admin" -> "Admin".
String _roleLabel(String? role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'kasir':
      return 'Kasir';
    default:
      return role ?? '';
  }
}

/// Warna aksen per peran (dipakai untuk avatar & teks role).
Color _roleColor(String? role) {
  return role == 'admin' ? AppColors.primary : const Color(0xFF0D9488);
}

/// Bagian profil pengguna di pojok kanan atas (hanya tampilan).
///
/// Menampilkan avatar (inisial), nama pengguna, dan role. Tanpa ikon maupun
/// menu dropdown — murni informasi identitas pengguna yang sedang login.
class PosProfileChip extends StatelessWidget {
  const PosProfileChip({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.name ?? 'Pengguna';
    final role = _roleLabel(user?.role);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _roleColor(user?.role);

    // Sembunyikan teks (nama & role) di layar sempit agar tidak overflow.
    final showText = MediaQuery.sizeOf(context).width >= 820;

    return Container(
      // Margin atas & bawah simetris agar chip sejajar (di tengah) dengan
      // ikon notifikasi/logout di kanan atas; kanan diberi jarak lebih lega.
      margin: const EdgeInsets.only(left: 4, top: 4, bottom: 4, right: 12),
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: showText ? 14 : 12,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: showText ? 12 : 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 8),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
