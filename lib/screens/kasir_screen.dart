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
import '../utils/receipt_printer.dart';
import '../widgets/pos_app_bar_actions.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: const [PosAppBarActions()],
      ),
      body: Column(
        children: [
          // Pencarian produk
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
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
          // Grid produk (2/3 tinggi)
          Expanded(
            flex: 3,
            child: _buildProductGrid(productProvider, cart),
          ),
          const Divider(height: 1),
          // Keranjang (1/3 tinggi)
          Expanded(flex: 2, child: _buildCart(cart)),
        ],
      ),
    );
  }

  Widget _buildProductGrid(ProductProvider provider, CartProvider cart) {
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
      return const Center(child: Text('Produk tidak ditemukan'));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: provider.products.length,
      itemBuilder: (context, index) {
        final product = provider.products[index];
        return _ProductCard(
          product: product,
          onTap: () => cart.addItem(product),
        );
      },
    );
  }

  Widget _buildCart(CartProvider cart) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, size: 20),
              const SizedBox(width: 8),
              Text(
                'Keranjang (${cart.itemCount} item)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (!cart.isEmpty)
                TextButton(
                  onPressed: cart.clear,
                  child: const Text('Kosongkan'),
                ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? const Center(
                  child: Text('Keranjang kosong.\nPilih produk untuk mulai transaksi.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return _CartItemTile(item: item);
                  },
                ),
        ),
        // Total + tombol bayar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total'),
                    Text(
                      formatRupiah(cart.total),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: cart.isEmpty ? null : _checkout,
                icon: const Icon(Icons.payment),
                label: const Text('Bayar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.inventory_2,
                color: outOfStock ? Colors.grey : Colors.blue,
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                formatRupiah(product.price),
                style: TextStyle(
                  color: outOfStock ? Colors.grey : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                outOfStock ? 'Stok habis' : 'Stok: ${product.stock}',
                style: TextStyle(
                  fontSize: 12,
                  color: outOfStock ? Colors.red : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.name),
        subtitle: Text('${formatRupiah(item.price)} x ${item.qty}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => cart.decrement(item.productId),
            ),
            Text('${item.qty}'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => cart.increment(item.productId),
            ),
            SizedBox(
              width: 90,
              child: Text(
                formatRupiah(item.subtotal),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
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
          Text(
            'Pembayaran',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Total: ${formatRupiah(widget.total)}'),
          const SizedBox(height: 16),
          // Pilihan metode bayar
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'cash',
                label: Text('Tunai'),
                icon: Icon(Icons.payments),
              ),
              ButtonSegment(
                value: 'qris',
                label: Text('QRIS'),
                icon: Icon(Icons.qr_code),
              ),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (selection) {
              setState(() => _paymentMethod = selection.first);
            },
          ),
          const SizedBox(height: 16),
          if (_paymentMethod == 'cash') ...[
            TextField(
              controller: _cashController,
              decoration: const InputDecoration(
                labelText: 'Uang Diterima (Rp)',
                prefixIcon: Icon(Icons.payments),
                border: OutlineInputBorder(),
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
                      width: 220,
                      height: 220,
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
              border: OutlineInputBorder(),
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
