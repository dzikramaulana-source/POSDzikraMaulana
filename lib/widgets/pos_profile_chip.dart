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
      return role ?? 'Pengguna';
  }
}

/// Bagian profil pengguna di pojok kanan atas dengan desain modern.
class PosProfileChip extends StatelessWidget {
  const PosProfileChip({super.key});

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

    return Container(
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
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
        ],
      ),
    );
  }
}
