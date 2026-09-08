import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../utils/formatter.dart';
import '../widgets/pos_app_bar_actions.dart';
import 'kasir_screen.dart';
import 'product_form_screen.dart';
import 'report_screen.dart';
import 'shift_screen.dart';
import 'stock_check_screen.dart';
import 'transaction_history_screen.dart';
import 'user_management_screen.dart';

/// Definisi satu item navigasi sidebar.
class _RailItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const _RailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}

/// Shell utama POS.
///
/// Menampilkan sidebar vertikal di kiri berisi seluruh menu utama sesuai
/// peran (admin vs kasir), sedangkan tombol Notifikasi & Logout tetap berada
/// di pojok kanan atas setiap layar (via PosAppBarActions). Menu yang dipilih
/// dirender di area konten; layar detail/form tetap dibuka full-screen.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final bool _isAdmin;
  late final List<_RailItem> _items;
  final List<Widget?> _pageCache = List.filled(5, null);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.role == 'admin';
    _items = _buildItems(_isAdmin);
    // Cache halaman dengan instance yang sama dari _items (bukan duplikat),
    // supaya state halaman awal tidak dibuat dua kali.
    for (var i = 0; i < _pageCache.length; i++) {
      _pageCache[i] = _items[i].page;
    }
  }

  List<_RailItem> _buildItems(bool isAdmin) {
    if (isAdmin) {
      return const [
        _RailItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Manajemen Produk',
          page: _ProductHomePage(),
        ),
        _RailItem(
          icon: Icons.assessment_outlined,
          selectedIcon: Icons.assessment,
          label: 'Laporan',
          page: ReportScreen(),
        ),
        _RailItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Riwayat Transaksi',
          page: TransactionHistoryScreen(),
        ),
        _RailItem(
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
          label: 'Manajemen Kasir',
          page: UserManagementScreen(),
        ),
        _RailItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          label: 'Kas / Shift',
          page: ShiftScreen(),
        ),
      ];
    }
    return const [
      _RailItem(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        label: 'Kas / Shift',
        page: ShiftScreen(),
      ),
      _RailItem(
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        label: 'Kasir',
        page: KasirScreen(),
      ),
      _RailItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Riwayat Transaksi',
        page: TransactionHistoryScreen(),
      ),
      _RailItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Cek Stok',
        page: StockCheckScreen(),
      ),
      _RailItem(
        icon: Icons.assessment_outlined,
        selectedIcon: Icons.assessment,
        label: 'Laporan',
        page: ReportScreen(),
      ),
    ];
  }

  void _selectDestination(int index) {
    setState(() => _index = index);
  }

  Widget _buildRailHeader(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.name ?? 'Pengguna';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          const Text(
            'POS Kasir',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          CircleAvatar(
            radius: 20,
            child: Text(
              initial,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            user?.role ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            selectedIndex: _index,
            onDestinationSelected: _selectDestination,
            leading: _buildRailHeader(context),
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                for (final cached in _pageCache)
                  cached ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Halaman Manajemen Produk admin: pencarian & daftar produk.
class _ProductHomePage extends StatefulWidget {
  const _ProductHomePage();

  @override
  State<_ProductHomePage> createState() => _ProductHomePageState();
}

class _ProductHomePageState extends State<_ProductHomePage> {
  final _searchController = TextEditingController();

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

  Future<void> _addProduct() async {
    final provider = context.read<ProductProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (mounted) {
      provider.loadProducts();
    }
  }

  Future<void> _openEditSheet(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductEditSheet(product: product),
    );
    if (mounted) {
      context.read<ProductProvider>().loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Produk',
            onPressed: _addProduct,
          ),
          const PosAppBarActions(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _search,
          decoration: InputDecoration(
            hintText: 'Cari nama / SKU produk...',
            prefixIcon: const Icon(Icons.search),
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
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildProductList(productProvider)),
      ],
    );
  }

  Widget _buildProductList(ProductProvider provider) {
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
        child: Text(
          'Belum ada produk.\nTekan ikon + di kanan atas untuk menambahkan.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadProducts(),
      child: ListView.builder(
        itemCount: provider.products.length,
        itemBuilder: (context, index) {
          final product = provider.products[index];
          return _buildProductCard(context, product);
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
        title: Text(product.name),
        subtitle: Text(
          '${product.sku} • Stok: ${product.stock}\n'
          'Harga: ${formatRupiah(product.price.toInt())}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 2),
            Text(
              'Edit',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        onTap: () => _openEditSheet(product),
      ),
    );
  }
}

class ProductEditSheet extends StatefulWidget {
  final Product product;

  const ProductEditSheet({super.key, required this.product});

  @override
  State<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<ProductEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late final TextEditingController _categoryController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _skuController = TextEditingController(text: p.sku);
    _priceController = TextEditingController(text: p.price.toStringAsFixed(0));
    _costController = TextEditingController(text: p.cost.toStringAsFixed(0));
    _stockController = TextEditingController(text: p.stock.toString());
    _categoryController = TextEditingController(text: p.category);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<ProductProvider>();

    final success = await provider.updateProduct(
      widget.product,
      name: _nameController.text.trim(),
      sku: _skuController.text.trim().toUpperCase(),
      price: double.parse(_priceController.text.trim()),
      cost: double.parse(
          _costController.text.trim().isEmpty ? '0' : _costController.text.trim()),
      stock: int.parse(
          _stockController.text.trim().isEmpty ? '0' : _stockController.text.trim()),
      category: _categoryController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk diperbarui')),
      );
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Gagal menyimpan produk')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Yakin ingin menghapus "${widget.product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<ProductProvider>();
    final success = await provider.deleteProduct(widget.product);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk dihapus')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Gagal hapus produk')),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Produk',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU (kode produk)',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'SKU wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual (Rp)',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Harga wajib diisi';
                            }
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'Harga tidak valid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(
                            labelText: 'Modal (Rp)',
                            prefixIcon: Icon(Icons.savings),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(
                            labelText: 'Stok',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan Perubahan'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus Produk'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
