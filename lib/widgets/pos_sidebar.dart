import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Item navigasi sidebar.
class PosSidebarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const PosSidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}

/// Sidebar navigasi utama POS.
///
/// Menampilkan menu sesuai peran yang sedang login (admin vs kasir) di panel
/// kiri, lengkap dengan header berupa identitas pengguna. Menyusut menjadi
/// mode "compact" (ikon saja) saat lebar layar sempit agar tetap ringkas.
class PosSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<PosSidebarItem> items;

  const PosSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.name ?? 'Pengguna';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          const Text(
            'POS Kasir',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          Text(
            user?.role ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extended = MediaQuery.sizeOf(context).width >= 900;

    return NavigationRail(
      extended: extended,
      minExtendedWidth: 200,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      backgroundColor: AppColors.surface,
      leading: _buildHeader(context),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
      ],
    );
  }
}