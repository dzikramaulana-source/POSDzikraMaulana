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

/// Sidebar navigasi utama POS dengan desain modern profesional.
class PosSidebar extends StatelessWidget {
  /// Lebar rail saat menu diringkas (hanya ikon).
  static const double _collapsedWidth = 72;

  /// Lebar rail saat menu diperluas (ikon + label).
  static const double _extendedWidth = 230;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<PosSidebarItem> items;

  const PosSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  Widget _buildHeader(BuildContext context, bool extended) {
    if (!extended) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.cardShadow,
          ),
          child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 24),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x252563EB),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'POS Kasir Pro',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Flexible(
                      child: Text(
                        'Store Online',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, bool extended) {
    if (!extended) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Mode Operasional',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extended = MediaQuery.sizeOf(context).width >= 960;

    return SizedBox(
      width: extended ? _extendedWidth : _collapsedWidth,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: NavigationRail(
          extended: extended,
          minWidth: _collapsedWidth,
          minExtendedWidth: _extendedWidth,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          backgroundColor: Colors.transparent,
          leading: _buildHeader(context, extended),
          trailing: _buildTrailing(context, extended),
          indicatorColor: AppColors.primary.withValues(alpha: 0.1),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          destinations: [
            for (final item in items)
              NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon, color: AppColors.primary),
                label: Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
      ),
    );
  }
}