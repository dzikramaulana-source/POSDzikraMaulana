import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/report_provider.dart';
import '../providers/setting_provider.dart';
import '../providers/shift_provider.dart';
import '../services/transaction_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/formatter.dart';
import '../utils/payment_method.dart';
import '../utils/receipt_printer.dart';
import '../utils/whatsapp_sender.dart';
import '../theme/app_colors.dart';
import '../widgets/pos_app_bar_actions.dart';

/// Besaran PPN dari suatu subtotal (dibulatkan ke rupiah penuh).
/// [rate] adalah tarif PPN sebagai pecahan (mis. 0.10), diambil dari pengaturan sistem.
double _ppnOf(double subtotal, double rate) => (subtotal * rate).roundToDouble();

/// Total yang harus dibayar = subtotal + PPN.
double _totalWithPpn(double subtotal, double rate) => subtotal + _ppnOf(subtotal, rate);

/// Format tarif PPN (pecahan) menjadi label persen, mis. 0.10 -> "10".
String _formatTaxPercent(double rate) {
  final percent = rate * 100;
  if (percent == percent.roundToDouble()) return percent.toStringAsFixed(0);
  return percent
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Lebar minimum area konten agar daftar produk dan panel pesanan dapat
/// ditampilkan berdampingan. Di bawah nilai ini panel pesanan dipindahkan ke
/// bawah daftar produk (tata letak mobile) supaya keduanya tetap terbaca.
const double _kSideBySideMinWidth = 760;

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      context.read<SettingProvider>().load();
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

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;

    final taxRate = context.read<SettingProvider>().taxRateFraction;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PaymentSheet(total: _totalWithPpn(cart.total, taxRate)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();
    final taxRate = context.watch<SettingProvider>().taxRateFraction;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Layar sempit (mobile): pakai tata letak bertumpuk.
          final narrow = constraints.maxWidth < _kSideBySideMinWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bar POS/Kasir di bagian atas (full-width)
              _buildHeaderBar(productProvider, narrow: narrow),
              // Di bawah bar: area produk & panel pesanan.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, contentConstraints) => narrow
                      ? _buildNarrowBody(
                          productProvider, cart, taxRate, contentConstraints)
                      : _buildWideBody(
                          productProvider, cart, taxRate, contentConstraints),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Tata letak layar lebar: daftar produk (kiri) + panel pesanan (kanan).
  Widget _buildWideBody(
    ProductProvider provider,
    CartProvider cart,
    double taxRate,
    BoxConstraints constraints,
  ) {
    // Lebar panel order menyesuaikan lebar area konten, dibatasi 320–440.
    final cartWidth =
        (constraints.maxWidth * 0.34).clamp(320.0, 440.0).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildProductArea(provider),
        ),
        Container(
          width: 2,
          color: AppColors.border,
        ),
        _CartPanel(
          cart: cart,
          onCheckout: _checkout,
          width: cartWidth,
          taxRate: taxRate,
        ),
      ],
    );
  }

  /// Tata letak layar sempit (mobile): daftar produk tetap di atas, panel
  /// pesanan turun ke bawah dengan tinggi terbatas supaya daftar produk tetap
  /// terlihat. Isi panel pesanan dapat di-scroll bila melebihi batas tinggi.
  Widget _buildNarrowBody(
    ProductProvider provider,
    CartProvider cart,
    double taxRate,
    BoxConstraints constraints,
  ) {
    final cartMaxHeight =
        (constraints.maxHeight * 0.55).clamp(0.0, 460.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildProductArea(provider),
        ),
        Container(
          height: 2,
          color: AppColors.border,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cartMaxHeight),
          child: _CartPanel(
            cart: cart,
            onCheckout: _checkout,
            width: double.infinity,
            taxRate: taxRate,
            compact: true,
          ),
        ),
      ],
    );
  }

  /// Bar POS/Kasir: judul, pencarian, dan filter kategori (full-width).
  /// Pada layar sempit kolom pencarian dan filter kategori ditumpuk, dan
  /// subjudul disembunyikan, supaya judul beserta aksi kanan tetap muat.
  Widget _buildHeaderBar(ProductProvider provider, {required bool narrow}) {
    final searchField = TextField(
      controller: _searchController,
      onChanged: _search,
      decoration: InputDecoration(
        hintText: 'Cari produk, SKU, atau nama...',
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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

    final categoryFilter = _CategoryFilter(
      categories: provider.categories,
      selected: _selectedCategory,
      onChanged: (value) => setState(() => _selectedCategory = value),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        narrow ? 14 : 20,
        narrow ? 10 : 14,
        narrow ? 14 : 20,
        narrow ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(narrow ? 6 : 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.point_of_sale, color: AppColors.primary),
              ),
              SizedBox(width: narrow ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kasir',
                      style: TextStyle(
                        fontSize: narrow ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (!narrow)
                      const Text(
                        'Pilih produk & buat order pelanggan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const PosAppBarActions(),
            ],
          ),
          SizedBox(height: narrow ? 10 : 12),
          if (narrow) ...[
            searchField,
            const SizedBox(height: 10),
            categoryFilter,
          ] else
            Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                Flexible(flex: 2, child: categoryFilter),
              ],
            ),
        ],
      ),
    );
  }

  /// Area produk di kiri, memanjang penuh hingga batas panel order.
  Widget _buildProductArea(ProductProvider provider) {
    final products = _selectedCategory == 'Semua'
        ? provider.products
        : provider.products
            .where((p) => p.category == _selectedCategory)
            .toList();

    final itemCount = products.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            children: [
              // Judul & jumlah produk dibuat fleksibel agar tetap muat saat
              // ruang sempit tanpa memicu overflow.
              Expanded(
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Daftar Produk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$itemCount produk',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.grid_view_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
        Expanded(child: _buildProductGrid(provider, products)),
      ],
    );
  }  Widget _buildProductGrid(ProductProvider provider, List<Product> products) {
    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.products.isEmpty) {
      return _ScrollableCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(provider.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => provider.loadProducts(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return _ScrollableCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text(
              'Produk tidak ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Coba gunakan kata kunci pencarian lain atau ganti kategori',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Jumlah kolom menyesuaikan lebar area; layar sangat sempit memakai
        // satu kolom agar kartu tetap proporsional dan tidak meluber.
        final cols = width >= 1150
            ? 4
            : (width >= 800 ? 3 : (width >= 300 ? 2 : 1));
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductCard(
              product: product,
              onTap: () => context.read<CartProvider>().addItem(product),
            );
          },
        );
      },
    );
  }
}

/// Kartu produk di grid kasir dengan gaya modern e-commerce POS.
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock <= 0;
    final lowStock = !outOfStock && product.stock <= 5;
    final inCart = context.watch<CartProvider>().items
        .where((i) => i.productId == product.id)
        .fold<int>(0, (sum, i) => sum + i.qty);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: inCart > 0 ? AppColors.primary : AppColors.border,
              width: inCart > 0 ? 1.8 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: inCart > 0
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : AppColors.cardShadow,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gambar / Thumbnail produk
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: product.imageUrl != null
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    size: 38,
                                    color: outOfStock ? AppColors.textMuted : AppColors.primary,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 38,
                                  color: outOfStock ? AppColors.textMuted : AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Kategori & SKU kecil
                    Text(
                      '${product.category} • ${product.sku}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Nama Produk
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        fontSize: 13.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Harga
                    Text(
                      formatRupiah(product.price),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: outOfStock ? AppColors.textMuted : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Baris Status Stok & Tombol Tambah Cepat
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _StockChip(
                            status: product.stockStatus,
                            lowStock: lowStock,
                            stock: product.stock,
                          ),
                        ),
                        if (!outOfStock)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: inCart > 0 ? AppColors.primary : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: inCart > 0 ? Colors.white : AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Badge Jumlah di Keranjang (Pojok Kanan Atas)
              if (inCart > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x302563EB),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$inCart x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

              // Overlay Habis jika stok 0
              if (outOfStock)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30EF4444),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Stok Habis',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip status stok dengan indikator dot berwarna.
class _StockChip extends StatelessWidget {
  final StockStatus status;
  final bool lowStock;
  final int stock;

  const _StockChip({
    required this.status,
    required this.lowStock,
    required this.stock,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, label) = switch (status) {
      StockStatus.out => (AppColors.dangerLight, AppColors.danger, 'Habis'),
      StockStatus.low when lowStock => (AppColors.warningLight, AppColors.warning, '$stock Menipis'),
      _ => (AppColors.successLight, AppColors.success, '$stock Tersedia'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menengahkan konten di area yang tersedia, namun tetap dapat di-scroll bila
/// area tersebut lebih pendek dari kontennya sehingga tidak terjadi overflow.
class _ScrollableCenter extends StatelessWidget {
  final Widget child;

  const _ScrollableCenter({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter urutan kategori produk.
class _CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allCategories = ['Semua', ...categories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = category == selected;
          return InkWell(
            onTap: () => onChanged(category),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Panel kanan: daftar order, ringkasan, dan pembayaran.
class _CartPanel extends StatelessWidget {
  final CartProvider cart;
  final VoidCallback onCheckout;
  final double width;

  /// Tarif PPN sebagai pecahan (mis. 0.10) dari pengaturan sistem.
  final double taxRate;

  /// true = panel ditampilkan di bawah daftar produk pada layar sempit: isi
  /// panel mengalir (dapat di-scroll) dan header dipadatkan.
  final bool compact;

  const _CartPanel({
    required this.cart,
    required this.onCheckout,
    required this.width,
    required this.taxRate,
    this.compact = false,
  });

  double get _subtotal => cart.total;

  @override
  Widget build(BuildContext context) {
    final subtotal = _subtotal;
    final tax = _ppnOf(subtotal, taxRate);
    final total = _totalWithPpn(subtotal, taxRate);

    final content = Column(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        // Daftar item: mode compact mengalir mengikuti tinggi konten,
        // mode lebar memakai Expanded + ListView agar dapat di-scroll.
        if (compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: cart.isEmpty
                ? _buildCompactEmptyCart()
                : Column(
                    children: [
                      for (final item in cart.items)
                        _OrderItemTile(item: item),
                    ],
                  ),
          )
        else
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _OrderItemTile(item: item);
                    },
                  ),
          ),
        _buildSummary(subtotal, tax, total),
      ],
    );

    return Container(
      width: width,
      color: AppColors.surface,
      child: compact ? SingleChildScrollView(child: content) : content,
    );
  }

  /// Header panel. Mode compact memakai judul fleksibel dan tombol
  /// "Kosongkan" berupa ikon supaya tidak meluber di layar sempit.
  Widget _buildHeader() {
    final icon = Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.shopping_cart_checkout,
          size: 20, color: AppColors.primary),
    );
    final countBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${cart.itemCount} item',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pesanan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            countBadge,
            if (!cart.isEmpty)
              IconButton(
                icon: const Icon(Icons.remove_shopping_cart_outlined,
                    size: 20, color: AppColors.textMuted),
                tooltip: 'Kosongkan keranjang',
                visualDensity: VisualDensity.compact,
                onPressed: cart.clear,
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          const Text(
            'Pesanan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 8),
          countBadge,
          const Spacer(),
          if (!cart.isEmpty)
            TextButton(
              onPressed: cart.clear,
              child: const Text(
                'Kosongkan',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// Keranjang kosong versi ringkas (tinggi mengikuti konten, tanpa Center)
  /// agar aman berada di dalam SingleChildScrollView pada mode compact.
  Widget _buildCompactEmptyCart() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            'Keranjang masih kosong',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih produk di atas untuk mulai membuat pesanan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Ringkasan nilai pesanan dan tombol pembayaran.
  Widget _buildSummary(double subtotal, double tax, double total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(
            label: 'Subtotal',
            value: formatRupiah(subtotal),
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: taxRate > 0
                ? 'Pajak PPN (${_formatTaxPercent(taxRate)}%)'
                : 'Pajak PPN',
            value: formatRupiah(tax),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.border,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Pembayaran',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Sudah termasuk pajak',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Nilai total menyusut otomatis bila ruang tidak cukup,
              // sehingga nominal panjang tidak memicu overflow.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatRupiah(total),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Tombol Bayar besar
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: cart.isEmpty ? null : onCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.payment, size: 22),
              label: const Text(
                'Bayar Sekarang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Keranjang masih kosong',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih produk di sebelah kiri\nuntuk mulai membuat pesanan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Baris item di panel order kanan.
class _OrderItemTile extends StatelessWidget {
  final CartItem item;

  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatRupiah(item.price),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () => cart.decrement(item.productId),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${item.qty}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () => cart.increment(item.productId),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
                tooltip: 'Hapus item',
                onPressed: () => cart.removeItem(item.productId),
              ),
              const SizedBox(height: 4),
              Text(
                formatRupiah(item.subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 16, color: AppColors.textDark),
        ),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  final double total;

  const _PaymentSheet({required this.total});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _paymentMethod = 'cash';
  final _cashController = TextEditingController();
  bool _isProcessing = false;

  double get _cashAmount {
    if (_paymentMethod != 'cash') return widget.total;
    return double.tryParse(_cashController.text.trim()) ?? 0;
  }

  double get _change {
    if (_paymentMethod != 'cash') return 0;
    return _cashAmount - widget.total;
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _quickCash(int amount) {
    setState(() {
      _cashController.text = amount.toString();
    });
  }

  Future<void> _submit() async {
    if (_paymentMethod == 'cash' && _change < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Nominal uang tunai kurang dari total belanja'),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final cart = context.read<CartProvider>();
    // Simpan referensi provider & navigator sebelum bottom sheet ditutup,
    // supaya pembaruan data tetap berjalan setelah context sheet tidak aktif.
    final productProvider = context.read<ProductProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    final reportProvider = context.read<ReportProvider>();
    final navigator = Navigator.of(context);

    try {
      final transaction = await TransactionService.createTransaction(
        items: cart.items,
        paymentMethod: _paymentMethod,
        cashReceived: _cashAmount,
      );

      if (!mounted) return;
      cart.clear();
      navigator.pop();

      // Tampilkan dialog sukses
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PaymentSuccessDialog(transaction: transaction),
      );

      // Perbarui otomatis data Kas/Shift, Laporan, dan stok produk
      await _refreshAfterTransaction(
        navigator: navigator,
        productProvider: productProvider,
        shiftProvider: shiftProvider,
        reportProvider: reportProvider,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dapat di-scroll agar seluruh isi tetap terjangkau saat layar pendek
    // atau saat keyboard muncul, sehingga tidak terjadi overflow.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selesaikan Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Pilih metode dan masukkan jumlah bayar',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tagihan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatRupiah(widget.total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pilihan metode bayar
          Row(
            children: [
              Expanded(
                child: _PaymentMethodTile(
                  method: 'cash',
                  label: 'Tunai',
                  icon: Icons.payments_rounded,
                  color: AppColors.success,
                  selected: _paymentMethod == 'cash',
                  onTap: () => setState(() => _paymentMethod = 'cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentMethodTile(
                  method: 'qris',
                  label: 'QRIS',
                  icon: Icons.qr_code_rounded,
                  color: const Color(0xFF0284C7),
                  selected: _paymentMethod == 'qris',
                  onTap: () => setState(() => _paymentMethod = 'qris'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mode Cash: input & quick buttons & kembalian
          if (_paymentMethod == 'cash') ...[
            TextFormField(
              controller: _cashController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Uang Diterima',
                hintText: '0',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.money_rounded),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Tombol Cepat Nominal Uang
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                  label: const Text('Uang Pas'),
                  onPressed: () => _quickCash(widget.total.toInt()),
                ),
                for (final amt in [10000, 20000, 50000, 100000, 200000])
                  if (amt >= widget.total || amt == 50000 || amt == 100000)
                    ActionChip(
                      label: Text(formatRupiah(amt)),
                      onPressed: () => _quickCash(amt),
                    ),
              ],
            ),
            const SizedBox(height: 14),

            // Banner Kembalian / Kurang
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _change < 0 ? AppColors.dangerLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _change < 0 ? AppColors.danger.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _change < 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _change < 0 ? AppColors.danger : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _change < 0 ? 'Kurang Bayar:' : 'Uang Kembalian:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _change < 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatRupiah(_change < 0 ? -_change : _change),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _change < 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Mode QRIS
          if (_paymentMethod == 'qris') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/QR_Payment.jpeg',
                      width: 170,
                      height: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total Tagihan: ${formatRupiah(widget.total)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Minta pelanggan memindai QR di atas lewat GoPay, OVO, Dana, BCA, dll.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Tombol Proses Pembayaran
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _isProcessing ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Konfirmasi Pembayaran',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSuccessDialog extends StatefulWidget {
  final Transaction transaction;

  const _PaymentSuccessDialog({required this.transaction});

  @override
  State<_PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<_PaymentSuccessDialog> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isSending = false;
  // Penanda permintaan saran terakhir agar permintaan lama yang selesai
  // belakangan tidak menimpa hasil yang lebih baru.
  int _searchToken = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<Iterable<String>> _suggestNumbers(String input) async {
    final suffix = lastFourDigitsOf(input);
    if (suffix.isEmpty) return const <String>[];

    final token = ++_searchToken;
    // Beri jeda singkat supaya pencarian tidak dipanggil tiap ketikan.
    await Future.delayed(const Duration(milliseconds: 250));
    if (token != _searchToken) return const <String>[];

    try {
      return await WhatsAppService.searchRecipientsByLast4(suffix);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _sendToWhatsApp() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    await sendReceiptToWhatsApp(
      context,
      transaction: widget.transaction,
      phone: _phoneController.text,
    );
    if (mounted) setState(() => _isSending = false);
  }

  Widget _buildPrintButton(Transaction transaction) {
    return OutlinedButton.icon(
      onPressed: () {
        ReceiptPrinter.printReceipt(transaction);
      },
      icon: const Icon(Icons.print_rounded, size: 18),
      label: const Text('Cetak'),
    );
  }

  Widget _buildPdfButton(Transaction transaction) {
    return OutlinedButton.icon(
      onPressed: () {
        ReceiptPrinter.downloadReceipt(transaction);
      },
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('PDF'),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return FilledButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Selesai'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 52),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transaksi Berhasil!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No. Invoice: ${transaction.invoiceNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // Financial Recap Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pembayaran', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      Text(formatRupiah(transaction.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Metode', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      Text(paymentLabel(transaction.paymentMethod), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  if (transaction.change > 0) ...[
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kembalian', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(formatRupiah(transaction.change), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kirim WhatsApp (nomor yang pernah dipakai muncul otomatis
            // setelah 4 digit terakhirnya diketik)
            Autocomplete<String>(
              textEditingController: _phoneController,
              focusNode: _phoneFocusNode,
              displayStringForOption: formatWhatsAppNumber,
              optionsBuilder: (TextEditingValue value) =>
                  _suggestNumbers(value.text),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                  ],
                  onSubmitted: (_) => onFieldSubmitted(),
                  decoration: InputDecoration(
                    labelText: 'Kirim Struk ke WhatsApp Pelanggan',
                    hintText: 'Contoh: 08123456789',
                    prefixIcon: const Icon(Icons.chat_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: _isSending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: AppColors.success),
                      onPressed: _isSending ? null : _sendToWhatsApp,
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final suggestions = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: AppColors.surface,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 360),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final number = suggestions[index];
                          return InkWell(
                            onTap: () => onSelected(number),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.history_rounded, size: 18, color: AppColors.textMuted),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      formatWhatsAppNumber(number),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Text(
                                    'Gunakan',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        // Layar sempit: tombol ditumpuk vertikal agar label tidak terpotong.
        // Layar lebar: tetap tiga tombol sejajar memenuhi lebar dialog.
        if (MediaQuery.sizeOf(context).width < 480)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPrintButton(transaction),
              const SizedBox(height: 8),
              _buildPdfButton(transaction),
              const SizedBox(height: 8),
              _buildDoneButton(context),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildPrintButton(transaction)),
              const SizedBox(width: 8),
              Expanded(child: _buildPdfButton(transaction)),
              const SizedBox(width: 8),
              Expanded(child: _buildDoneButton(context)),
            ],
          ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String method;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : AppColors.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected ? color : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Memperbarui data Kas/Shift, Laporan, dan stok produk setelah transaksi
/// berhasil, sambil menampilkan animasi loading selama proses berlangsung.
Future<void> _refreshAfterTransaction({
  required NavigatorState navigator,
  required ProductProvider productProvider,
  required ShiftProvider shiftProvider,
  required ReportProvider reportProvider,
}) async {
  BuildContext? overlayContext;

  showDialog<void>(
    context: navigator.context,
    barrierDismissible: false,
    builder: (context) {
      overlayContext = context;
      return const _DataRefreshDialog();
    },
  );

  await Future.wait([
    productProvider.loadProducts(),
    shiftProvider.refresh(),
    reportProvider.refresh(),
    // Minimal tampil sebentar agar animasi loading terlihat jelas.
    Future<void>.delayed(const Duration(milliseconds: 700)),
  ]);

  if (overlayContext != null && overlayContext!.mounted) {
    Navigator.of(overlayContext!).pop();
  }
}

/// Dialog loading saat data Kas/Shift & Laporan diperbarui otomatis.
class _DataRefreshDialog extends StatelessWidget {
  const _DataRefreshDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                'Memperbarui Data',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Kas/Shift, Laporan, dan stok produk...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

