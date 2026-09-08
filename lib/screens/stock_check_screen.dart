import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/formatter.dart';
import '../widgets/pos_app_bar_actions.dart';

class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen> {
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
            padding: const EdgeInsets.all(16),
            child: TextField(
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
          ),
          Expanded(child: _buildBody(productProvider)),
        ],
      ),
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

    return RefreshIndicator(
      onRefresh: () => provider.loadProducts(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: provider.products.length,
        itemBuilder: (context, index) {
          final product = provider.products[index];
          return _StockCard(product: product);
        },
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
    final (label, color, icon) = switch (status) {
      StockStatus.available => ('Tersedia', Colors.green, Icons.check_circle),
      StockStatus.low => ('Menipis', Colors.orange, Icons.warning_amber),
      StockStatus.out => ('Habis', Colors.red, Icons.cancel),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(product.name),
        subtitle: Text(
          '${product.sku} • ${product.category}\n'
          'Stok: ${product.stock} • Harga: ${formatRupiah(product.price.toInt())}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
