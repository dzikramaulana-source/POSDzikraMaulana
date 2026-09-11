import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatter.dart';
import '../widgets/pos_app_bar_actions.dart';
import '../widgets/pos_sidebar.dart';
import 'kasir_screen.dart';
import 'product_form_screen.dart';
import 'report_screen.dart';
import 'shift_screen.dart';
import 'stock_check_screen.dart';
import 'transaction_history_screen.dart';
import 'user_management_screen.dart';

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
  late final List<PosSidebarItem> _items;
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

  List<PosSidebarItem> _buildItems(bool isAdmin) {
    if (isAdmin) {
      return const [
        PosSidebarItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Manajemen Produk',
          page: _ProductHomePage(),
        ),
        PosSidebarItem(
          icon: Icons.assessment_outlined,
          selectedIcon: Icons.assessment,
          label: 'Laporan',
          page: ReportScreen(),
        ),
        PosSidebarItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Riwayat Transaksi',
          page: TransactionHistoryScreen(),
        ),
        PosSidebarItem(
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
          label: 'Manajemen Kasir',
          page: UserManagementScreen(),
        ),
        PosSidebarItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          label: 'Kas / Shift',
          page: ShiftScreen(),
        ),
      ];
    }
    return const [
      PosSidebarItem(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        label: 'Kas / Shift',
        page: ShiftScreen(),
      ),
      PosSidebarItem(
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        label: 'Kasir',
        page: KasirScreen(),
      ),
      PosSidebarItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Riwayat Transaksi',
        page: TransactionHistoryScreen(),
      ),
      PosSidebarItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Cek Stok',
        page: StockCheckScreen(),
      ),
      PosSidebarItem(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PosSidebar(
            selectedIndex: _index,
            onSelected: _selectDestination,
            items: _items,
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

/// Halaman Manajemen Produk admin: pencarian & daftar produk dengan ringkasan KPI.
class _ProductHomePage extends StatefulWidget {
  const _ProductHomePage();

  @override
  State<_ProductHomePage> createState() => _ProductHomePageState();
}

class _ProductHomePageState extends State<_ProductHomePage> {
  final _searchController = TextEditingController();
  String _stockFilter = 'Semua';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manajemen Produk'),
        actions: [
          FilledButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah Produk'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          const PosAppBarActions(),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.products;

    // Filter lokal berdasarkan status stok
    final filtered = products.where((p) {
      if (_stockFilter == 'Stok Tersedia') return p.stock > 5;
      if (_stockFilter == 'Stok Menipis') return p.stock > 0 && p.stock <= 5;
      if (_stockFilter == 'Stok Habis') return p.stock <= 0;
      return true;
    }).toList();

    // Hitung KPI
    final totalProducts = products.length;
    final totalAssetValue = products.fold<double>(0, (sum, p) => sum + (p.price * p.stock));
    final lowStockCount = products.where((p) => p.stock > 0 && p.stock <= 5).length;
    final outOfStockCount = products.where((p) => p.stock <= 0).length;

    return RefreshIndicator(
      onRefresh: () => productProvider.loadProducts(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // KPI Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cols = width >= 900 ? 4 : (width >= 600 ? 2 : 1);
              const spacing = 12.0;
              final cardWidth = (width - spacing * (cols - 1)) / cols;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _buildKpiCard(
                    width: cardWidth,
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.primary,
                    bgColor: AppColors.primaryLight,
                    title: 'Total Produk',
                    value: '$totalProducts SKU',
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.success,
                    bgColor: AppColors.successLight,
                    title: 'Nilai Aset Stok',
                    value: formatRupiah(totalAssetValue),
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    bgColor: AppColors.warningLight,
                    title: 'Stok Menipis',
                    value: '$lowStockCount Produk',
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    icon: Icons.remove_circle_outline_rounded,
                    color: AppColors.danger,
                    bgColor: AppColors.dangerLight,
                    title: 'Stok Habis',
                    value: '$outOfStockCount Produk',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Toolbar: Search + Stock Status Filter
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk, SKU, atau kategori...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in ['Semua', 'Stok Tersedia', 'Stok Menipis', 'Stok Habis'])
                      ChoiceChip(
                        label: Text(filter),
                        selected: _stockFilter == filter,
                        onSelected: (_) => setState(() => _stockFilter = filter),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Product List Section
          if (productProvider.isLoading && products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (productProvider.error != null && products.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(productProvider.error!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => productProvider.loadProducts(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tidak ada produk yang cocok',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Coba ubah kata kunci atau filter status stok',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = filtered[index];
                return _buildProductCard(context, product);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required double width,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String value,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final outOfStock = product.stock <= 0;
    final lowStock = !outOfStock && product.stock <= 5;
    final margin = product.price > 0 && product.cost > 0
        ? ((product.price - product.cost) / product.price * 100).toStringAsFixed(0)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: product.imageUrl != null
              ? Image.network(
                  product.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                )
              : const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textDark),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                product.sku,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Jual: ${formatRupiah(product.price)}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 13),
              ),
              if (product.cost > 0)
                Text(
                  'Modal: ${formatRupiah(product.cost)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              if (margin != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+$margin% Laba',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: outOfStock ? AppColors.danger : (lowStock ? AppColors.warning : AppColors.success),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Stok: ${product.stock}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: outOfStock ? AppColors.danger : (lowStock ? AppColors.warning : AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: FilledButton.tonal(
          onPressed: () => _openEditSheet(product),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, size: 15),
              SizedBox(width: 4),
              Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
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

  // Gambar produk: byte hasil pick (jika baru dipilih) atau gambar lama.
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _clearImage = false;

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

  /// Buka galeri/file picker untuk memilih gambar produk (maks 2MB).
  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 80,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 2 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran gambar maksimal 2MB')),
        );
        return;
      }

      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = file.name;
        _clearImage = false;
      });
    } catch (e) {
      if (mounted) {
        final cause = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cause.contains('MissingPluginException')
                  ? 'Plugin kamera/file belum aktif. Hentikan lalu jalankan ulang aplikasi (flutter run) agar fitur gambar berfungsi.'
                  : 'Gagal memilih gambar: $cause',
            ),
          ),
        );
      }
    }
  }

  /// Area preview + tombol pilih/hapus gambar produk.
  Widget _buildImagePicker() {
    final existingUrl =
        !_clearImage ? widget.product.imageUrl : null;
    final hasImage = _pickedImageBytes != null || existingUrl != null;

    Widget placeholder = Container(
      color: const Color(0xFFF1F5F9),
      child: const Icon(Icons.add_photo_alternate_outlined,
          size: 32, color: Colors.grey),
    );

    Widget preview;
    if (_pickedImageBytes != null) {
      preview = Image.memory(_pickedImageBytes!, fit: BoxFit.cover);
    } else if (existingUrl != null) {
      preview = Image.network(
        existingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      preview = placeholder;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 96, height: 96, child: preview),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gambar Produk',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PNG/JPG/WebP/GIF • maks 2MB',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Pilih Gambar'),
                    ),
                    if (hasImage)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _pickedImageBytes = null;
                            _pickedImageName = null;
                            _clearImage = true;
                          });
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
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
      image: _clearImage ? '' : null,
      imageBytes: _pickedImageBytes,
      imageName: _pickedImageName,
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
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
                  child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Informasi Produk',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Perbarui data harga, stok, atau SKU produk',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU (Kode Produk)',
                      prefixIcon: Icon(Icons.tag_rounded),
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
                            prefixIcon: Icon(Icons.payments_outlined),
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
                            prefixIcon: Icon(Icons.savings_outlined),
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
                            labelText: 'Jumlah Stok',
                            prefixIcon: Icon(Icons.numbers_rounded),
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
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Hapus Produk Ini', style: TextStyle(fontWeight: FontWeight.w600)),
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
