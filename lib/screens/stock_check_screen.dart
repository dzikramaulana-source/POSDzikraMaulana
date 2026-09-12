import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatter.dart';
import '../widgets/pos_app_bar_actions.dart';

class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

/// Opsi dropdown kategori pada layar Cek Stok.
const List<String> _categoryOptions = ['Semua', 'Makanan', 'Minuman', 'Camilan'];

/// Opsi dropdown pengurutan: berdasarkan stok (Terendah/Terbanyak) atau nama (A–Z/Z–A).
const List<String> _sortOptions = ['Terendah', 'Terbanyak', 'A–Z', 'Z–A'];

class _StockCheckScreenState extends State<StockCheckScreen> {
  final _searchController = TextEditingController();

  /// Kategori yang dipilih. 'Semua' berarti seluruh kategori.
  String _selectedCategory = 'Semua';

  /// Urutan yang dipilih.
  String _selectedSort = 'Terendah';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    context.read<ProductProvider>().loadProducts(search: query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cek Stok'),
        actions: const [PosAppBarActions()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildFilterBar(),
          ),
          Expanded(child: _buildBody(productProvider)),
        ],
      ),
    );
  }

  /// Bar filter: search bar diikuti dropdown Kategori & Urutkan.
  /// Saat layar sempit, dropdown turun ke baris kedua agar tidak overflow.
  Widget _buildFilterBar() {
    final searchField = TextField(
      controller: _searchController,
      onChanged: _search,
      decoration: InputDecoration(
        hintText: 'Cari nama / SKU produk...',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _search('');
                },
              ),
      ),
    );

    final categoryDropdown = _FilterDropdown(
      icon: Icons.category_outlined,
      value: _selectedCategory,
      items: _categoryOptions,
      onChanged: (value) => setState(() => _selectedCategory = value),
    );

    final sortDropdown = _FilterDropdown(
      icon: Icons.sort_rounded,
      value: _selectedSort,
      items: _sortOptions,
      onChanged: (value) => setState(() => _selectedSort = value),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(flex: 5, child: searchField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: categoryDropdown),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: sortDropdown),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchField,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: categoryDropdown),
                const SizedBox(width: 12),
                Expanded(child: sortDropdown),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(ProductProvider provider) {
    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(provider.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => provider.loadProducts(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (provider.products.isEmpty) {
      return const Center(
        child: Text('Produk tidak ditemukan'),
      );
    }

    final items = _applyFilter(provider.products);

    if (items.isEmpty) {
      return const Center(
        child: Text('Tidak ada produk untuk filter ini'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadProducts(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Target 5 produk per baris; kurangi hanya bila layar terlalu
          // sempit agar tiap card tetap rapi dan tidak terpotong.
          final width = constraints.maxWidth;
          final cols = width >= 950
              ? 5
              : (width >= 760 ? 4 : (width >= 560 ? 3 : 2));
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _StockCard(product: items[index]);
            },
          );
        },
      ),
    );
  }

  /// Terapkan filter kategori lalu urutkan sesuai pilihan dropdown Urutkan.
  List<Product> _applyFilter(List<Product> products) {
    final result = _selectedCategory == 'Semua'
        ? [...products]
        : products
            .where((p) =>
                p.category.toLowerCase() == _selectedCategory.toLowerCase())
            .toList();

    switch (_selectedSort) {
      case 'Terendah':
        result.sort((a, b) => a.stock.compareTo(b.stock));
      case 'Terbanyak':
        result.sort((a, b) => b.stock.compareTo(a.stock));
      case 'A–Z':
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 'Z–A':
        result.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
    }
    return result;
  }
}

/// Dropdown filter bergaya sama dengan search bar (putih, border membulat).
class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
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

class _StockCard extends StatelessWidget {
  final Product product;

  const _StockCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final status = product.stockStatus;
    final (label, color, bgColor, icon) = switch (status) {
      StockStatus.available => ('Tersedia', AppColors.success, AppColors.successLight, Icons.check_circle_rounded),
      StockStatus.low => ('Menipis', AppColors.warning, AppColors.warningLight, Icons.warning_amber_rounded),
      StockStatus.out => ('Habis', AppColors.danger, AppColors.dangerLight, Icons.cancel_rounded),
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar produk (diperbesar agar lebih jelas)
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFFF1F5F9),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholder(status),
                        )
                      : _buildPlaceholder(status),
                ),
                // Badge status stok di atas gambar
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama produk
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // SKU & kategori
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.sku,
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Jumlah stok & harga
                Row(
                  children: [
                    Text(
                      'Stok: ${product.stock}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        formatRupiah(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
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

  Widget _buildPlaceholder(StockStatus status) {
    final color = switch (status) {
      StockStatus.available => AppColors.primary,
      StockStatus.low => AppColors.warning,
      StockStatus.out => AppColors.textMuted,
    };
    return Center(
      child: Icon(Icons.inventory_2_outlined, size: 36, color: color),
    );
  }
}
