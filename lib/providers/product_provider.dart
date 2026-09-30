import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Daftar kategori unik dari semua produk (untuk filter di kasir).
  List<String> get categories {
    final seen = <String>{};
    final result = <String>[];
    for (final p in _products) {
      final c = p.category;
      if (c.isNotEmpty && seen.add(c)) result.add(c);
    }
    return result;
  }

  Future<void> loadProducts({String? search}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _products = await ProductService.getProducts(search: search);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Cari produk dari barcode (fitur scan di Kasir).
  /// `null` = barcode tidak terdaftar; melempar error bila koneksi bermasalah.
  /// Tidak mengubah daftar produk yang sedang tampil.
  Future<Product?> findByBarcode(String barcode) {
    return ProductService.getProductByBarcode(barcode);
  }

  Future<bool> addProduct({
    required String name,
    required String sku,
    required double price,
    required double cost,
    required int stock,
    required String category,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      await ProductService.createProduct(
        name: name,
        sku: sku,
        price: price,
        cost: cost,
        stock: stock,
        category: category,
        imageBytes: imageBytes,
        imageName: imageName,
      );
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(
    Product product, {
    required String name,
    required String sku,
    required double price,
    required double cost,
    required int stock,
    required String category,
    String? image,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      await ProductService.updateProduct(
        product.id,
        name: name,
        sku: sku,
        price: price,
        cost: cost,
        stock: stock,
        category: category,
        image: image ?? product.image,
        imageBytes: imageBytes,
        imageName: imageName,
      );
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(Product product) async {
    try {
      await ProductService.deleteProduct(product.id);
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
