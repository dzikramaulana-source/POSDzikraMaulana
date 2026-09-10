import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
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
          foregroundImage: product.imageUrl != null
              ? NetworkImage(product.imageUrl!)
              : null,
          onForegroundImageError: product.imageUrl != null
              ? (_, _) {}
              : null,
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
                  _buildImagePicker(),
                  const SizedBox(height: 12),
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
