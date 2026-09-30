import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';
import 'api_service.dart';

class ProductService {
  // Petakan ekstensi nama file ke MIME type (untuk validasi upload di server).
  static http.MediaType _imageMediaType(String? imageName) {
    final ext = (imageName ?? '').split('.').last.toLowerCase();
    return switch (ext) {
      'png' => http.MediaType('image', 'png'),
      'webp' => http.MediaType('image', 'webp'),
      'gif' => http.MediaType('image', 'gif'),
      'jpg' || 'jpeg' => http.MediaType('image', 'jpeg'),
      // Fallback aman: kebanyakan file hasil kamera/gallery adalah JPEG.
      _ => http.MediaType('image', 'jpeg'),
    };
  }

  // Kirim form produk (bisa disertai file gambar) via multipart.
  static Future<Map<String, dynamic>> _sendProductForm(
    String method,
    String path,
    Map<String, String> fields, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}$path');
    final request = http.MultipartRequest(method, uri);

    final token = await ApiService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    if (imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageName ?? 'produk.jpg',
          // Wajib diisi agar server mengenali file sebagai gambar;
          // tanpa ini server menerima "application/octet-stream" dan menolak.
          contentType: _imageMediaType(imageName),
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final data = ApiService.handleResponse(response);
    return data as Map<String, dynamic>;
  }

  // Ambil semua produk (opsional search)
  static Future<List<Product>> getProducts({String? search}) async {
    final query = search != null && search.isNotEmpty
        ? '?search=${Uri.encodeQueryComponent(search)}'
        : '';
    final data = await ApiService.get('/products$query');
    final list = data['products'] as List? ?? [];
    return list
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Ambil detail produk
  static Future<Product> getProduct(String id) async {
    final data = await ApiService.get('/products/$id');
    return Product.fromJson(data['product'] as Map<String, dynamic>);
  }

  // Cari produk berdasarkan barcode (untuk fitur scan di Kasir).
  // Mengembalikan null bila barcode tidak terdaftar.
  static Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final data = await ApiService.get(
        '/products/barcode/${Uri.encodeComponent(barcode)}',
      );
      return Product.fromJson(data['product'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // Tambah produk baru (opsional sertakan gambar)
  static Future<Product> createProduct({
    required String name,
    required String sku,
    required double price,
    required double cost,
    required int stock,
    required String category,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final data = await _sendProductForm(
      'POST',
      '/products',
      {
        'name': name,
        'sku': sku,
        'price': price.toString(),
        'cost': cost.toString(),
        'stock': stock.toString(),
        'category': category,
      },
      imageBytes: imageBytes,
      imageName: imageName,
    );
    return Product.fromJson(data['product'] as Map<String, dynamic>);
  }

  // Update produk (opsional sertakan gambar baru / kirim image lama)
  static Future<Product> updateProduct(
    String id, {
    required String name,
    required String sku,
    required double price,
    required double cost,
    required int stock,
    required String category,
    String image = '',
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final data = await _sendProductForm(
      'PUT',
      '/products/$id',
      {
        'name': name,
        'sku': sku,
        'price': price.toString(),
        'cost': cost.toString(),
        'stock': stock.toString(),
        'category': category,
        'image': image,
      },
      imageBytes: imageBytes,
      imageName: imageName,
    );
    return Product.fromJson(data['product'] as Map<String, dynamic>);
  }

  // Hapus produk
  static Future<void> deleteProduct(String id) async {
    await ApiService.delete('/products/$id');
  }
}
