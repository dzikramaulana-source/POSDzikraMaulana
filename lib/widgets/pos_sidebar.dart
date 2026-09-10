import 'package:flutter/material.dart';
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
/// kiri, dengan branding POS di bagian atas. Menyusut menjadi mode "compact"
/// (ikon saja) saat lebar layar sempit agar tetap ringkas.
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.point_of_sale, size: 30, color: AppColors.primary),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POS Kasir',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Panel Penjualan Cepat',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
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