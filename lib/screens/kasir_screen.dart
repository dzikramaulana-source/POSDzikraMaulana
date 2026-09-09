import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../services/transaction_service.dart';
import '../utils/formatter.dart';
import '../utils/payment_method.dart';
import '../utils/receipt_printer.dart';
import '../theme/app_colors.dart';
import '../widgets/pos_app_bar_actions.dart';

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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PaymentSheet(total: cart.total),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();

    // Lebar panel order menyesuaikan lebar layar, dibatasi 320–440.
    final cartWidth =
        (MediaQuery.sizeOf(context).width * 0.34).clamp(320.0, 440.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bar POS/Kasir di bagian atas (full-width)
          _buildHeaderBar(productProvider),
          // Di bawah bar: area produk (kiri, memanjang) + panel order (kanan)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildProductArea(productProvider),
                ),
                Container(
                  width: 2,
                  color: AppColors.border,
                ),
                _CartPanel(
                  cart: cart,
                  onCheckout: _checkout,
                  width: cartWidth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bar POS/Kasir: judul, pencarian, dan filter kategori (full-width).
  Widget _buildHeaderBar(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.point_of_sale, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kasir',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    'Pilih produk & buat order pelanggan',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              const PosAppBarActions(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Cari produk, SKU, atau nama...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textMuted),
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
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
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
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: _CategoryFilter(
                  categories: provider.categories,
                  selected: _selectedCategory,
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                ),
              ),
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
              const Text(
                'Daftar Produk',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemCount produk',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.grid_view_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
        Expanded(child: _buildProductGrid(provider, products)),
      ],
    );
  }

  Widget _buildProductGrid(ProductProvider provider, List<Product> products) {
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

    if (products.isEmpty) {
      return const Center(child: Text('Produk tidak ditemukan'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
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
    // "Semua" selalu tampil di depan.
    final visible = ['Semua', ...categories].take(5).toList();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = visible[index];
          final isSelected = category == selected;
          return GestureDetector(
            onTap: () => onChanged(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              AppColors.primary.withValues(alpha: 0.25),
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
                    const Icon(Icons.check, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    category,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
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

/// Kartu produk di grid tengah.
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock <= 0;
    final lowStock = !outOfStock && product.stock <= 10;
    final inCart = context.watch<CartProvider>().items
        .where((i) => i.productId == product.id)
        .fold<int>(0, (sum, i) => sum + i.qty);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: inCart > 0 ? AppColors.primary : AppColors.border,
              width: inCart > 0 ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto/ikon produk yang mengisi sisa tinggi kartu.
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: outOfStock
                              ? AppColors.background
                              : AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.inventory_2,
                            size: 42,
                            color: outOfStock
                                ? AppColors.textMuted
                                : AppColors.primary.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatRupiah(product.price),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: outOfStock ? AppColors.textMuted : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _StockChip(status: product.stockStatus, lowStock: lowStock)),
                        if (inCart > 0) ...[
                          const Spacer(),
                          Container(
                            constraints:
                                const BoxConstraints(minWidth: 22, minHeight: 22),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              '$inCart',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (outOfStock)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Habis',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

class _StockChip extends StatelessWidget {
  final StockStatus status;
  final bool lowStock;

  const _StockChip({required this.status, required this.lowStock});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      StockStatus.out => (AppColors.danger, 'Stok habis'),
      StockStatus.low when lowStock => (AppColors.warning, 'Stok menipis'),
      _ => (AppColors.success, 'Stok tersedia'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Panel kanan: daftar order, ringkasan, dan pembayaran.
class _CartPanel extends StatelessWidget {
  final CartProvider cart;
  final VoidCallback onCheckout;
  final double width;
  final double taxRate = 0.10;

  const _CartPanel({
    required this.cart,
    required this.onCheckout,
    required this.width,
  });

  double get _subtotal => cart.total;

  @override
  Widget build(BuildContext context) {
    final subtotal = _subtotal;
    final tax = subtotal * taxRate;
    final total = subtotal + tax;

    return Container(
      width: width,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header panel
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout,
                      size: 20, color: AppColors.primary),
                ),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                ),
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
          ),
          // Daftar item
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
          // Ringkasan + pembayaran
          Container(
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
                  label: 'Pajak PPN (10%)',
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
                    Text(
                      formatRupiah(total),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
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
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2,
                size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatRupiah(item.price)} / item',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () => cart.decrement(item.productId),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.qty}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _QtyButton(
                      icon: Icons.add,
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
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
                onPressed: () => cart.removeItem(item.productId),
              ),
              Text(
                formatRupiah(item.subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.textDark),
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

  double get _change {
    final cash = double.tryParse(_cashController.text.trim()) ?? 0;
    return cash - widget.total;
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_paymentMethod == 'cash' && _change < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uang yang diterima kurang dari total')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final cart = context.read<CartProvider>();

    try {
      final transaction = await TransactionService.createTransaction(
        items: cart.items,
        paymentMethod: _paymentMethod,
        cashReceived: double.tryParse(_cashController.text.trim()) ?? 0,
      );

      if (!mounted) return;
      cart.clear();
      Navigator.of(context).pop();

      // Tampilkan dialog sukses
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: const Text('Transaksi Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No. Invoice: ${transaction.invoiceNumber}'),
              const SizedBox(height: 8),
              Text('Total: ${formatRupiah(transaction.total)}'),
              if (transaction.change > 0) ...[
                const SizedBox(height: 8),
                Text('Kembalian: ${formatRupiah(transaction.change)}'),
              ],
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ReceiptPrinter.downloadReceipt(transaction);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Struk'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ReceiptPrinter.printReceipt(transaction);
              },
              icon: const Icon(Icons.print),
              label: const Text('Cetak Struk'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final ctx = context;
                final done = await sendReceiptToWhatsApp(ctx, transaction);
                if (done && ctx.mounted) Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.chat),
              label: const Text('Kirim ke WhatsApp'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );

      // Refresh stok produk setelah transaksi
      if (mounted) {
        context.read<ProductProvider>().loadProducts();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.payment, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Pembayaran',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${formatRupiah(widget.total)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Pilihan metode bayar (grid 2x2)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              _PaymentMethodTile(
                method: 'cash',
                label: paymentLabel('cash'),
                icon: paymentIcon('cash'),
                color: paymentColor('cash'),
                selected: _paymentMethod == 'cash',
                onTap: () => setState(() => _paymentMethod = 'cash'),
              ),
              _PaymentMethodTile(
                method: 'qris',
                label: paymentLabel('qris'),
                icon: paymentIcon('qris'),
                color: paymentColor('qris'),
                selected: _paymentMethod == 'qris',
                onTap: () => setState(() => _paymentMethod = 'qris'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_paymentMethod == 'cash') ...[
            TextField(
              controller: _cashController,
              decoration: const InputDecoration(
                labelText: 'Uang Diterima (Rp)',
                prefixIcon: Icon(Icons.payments),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Kembalian: ${formatRupiah(_change < 0 ? 0 : _change)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _change < 0 ? Colors.red : Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_paymentMethod == 'qris') ...[
            const Text(
              'Scan QRIS berikut untuk membayar:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/QR_Payment.jpeg',
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${formatRupiah(widget.total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pastikan nominal sesuai sebelum melakukan pembayaran.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: _isProcessing ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Proses Pembayaran'),
          ),
          const SizedBox(height: 8),
        ],
      ),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? color : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alur "Kirim ke WhatsApp" untuk struk transaksi.
///
/// Berdiri sendiri (top-level) karena dipanggil dari dialog "Transaksi
/// Berhasil" yang menumpuk di atas bottom sheet pembayaran yang sudah
/// ditutup, sehingga tidak aman bergantung pada State bottom sheet.
///
/// 1. Minta nomor WhatsApp pelanggan.
/// 2. Simpan struk PDF ke folder Downloads (bila tersedia).
/// 3. Buka chat WhatsApp ke nomor tersebut agar kasir melampirkan PDF.
///    Bila platform tak punya folder Downloads, tampilkan share sheet.
///
/// Mengembalikan `false` saat pengguna membatalkan (dialog sukses sebaiknya
/// tetap terbuka), dan `true` setelah alur selesai diproses.
Future<bool> sendReceiptToWhatsApp(
  BuildContext dialogContext,
  Transaction transaction,
) async {
  final phone = await promptWhatsAppNumber(dialogContext);
  if (phone == null || phone.isEmpty) return false;

  // Normalisasi nomor: buang spasi/tanda hubung/kurung lalu ubah 0x -> 62x.
  var digits = phone.replaceAll(RegExp(r'[\s\-().]'), '');
  if (digits.startsWith('+')) digits = digits.substring(1);
  if (digits.startsWith('0')) digits = '62${digits.substring(1)}';
  final waNumber = digits.replaceAll(RegExp(r'[^0-9]'), '');
  if (waNumber.isEmpty) {
    if (dialogContext.mounted) {
      _showSnack(dialogContext, 'Nomor WhatsApp tidak valid');
    }
    return false;
  }

  try {
    final savedPath =
        await ReceiptPrinter.saveReceiptPdfToDownloads(transaction);

    // Tak ada folder Downloads: serahkan ke share sheet OS agar kasir bisa
    // memilih WhatsApp sebagai tujuan berbagi file.
    if (savedPath == null) {
      final pdf = await ReceiptPrinter.generateReceiptPdf(transaction);
      await Printing.sharePdf(
        bytes: pdf,
        filename: 'Struk_${transaction.invoiceNumber}.pdf',
      );
      return true;
    }

    final uri = Uri.parse('https://wa.me/$waNumber');
    if (!await canLaunchUrl(uri)) {
      if (dialogContext.mounted) {
        _showSnack(
          dialogContext,
          'Struk tersimpan di: $savedPath\n'
          'Tidak bisa membuka WhatsApp otomatis. Silakan kirim file '
          'Struk_${transaction.invoiceNumber}.pdf dari folder tersebut.',
        );
      }
      return true;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  } catch (e) {
    if (dialogContext.mounted) {
      _showSnack(dialogContext, 'Gagal menyiapkan struk: $e');
    }
    return true;
  }
}

/// Dialog input nomor WhatsApp pelanggan.
Future<String?> promptWhatsAppNumber(BuildContext dialogContext) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: dialogContext,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.chat, color: Colors.green),
      title: const Text('Kirim ke WhatsApp'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan nomor WhatsApp pelanggan untuk mengirim struk PDF.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Nomor WhatsApp',
              hintText: '08xx / +62xxx',
              prefixIcon: Icon(Icons.phone),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: 8),
          Text(
            'Struk akan disimpan ke folder Downloads, lalu WhatsApp dibuka '
            'ke nomor tersebut. Lampirkan file PDF struk pada chat.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Kirim'),
        ),
      ],
    ),
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}