import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Dropdown filter bergaya sama dengan search bar (putih, border membulat).
///
/// Dipakai bersama oleh bar filter Cek Stok dan Manajemen Produk.
class PosFilterDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const PosFilterDropdown({
    super.key,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                items: [
                  for (final item in items)
                    DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (newValue) {
                  if (newValue != null) onChanged(newValue);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
