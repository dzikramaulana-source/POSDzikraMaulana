/// Status ketersediaan stok produk
enum StockStatus { available, low, out }

class Product {
  final String id;
  final String name;
  final String sku;
  final double price;
  final double cost;
  final int stock;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.cost,
    required this.stock,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'Umum',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sku': sku,
        'price': price,
        'cost': cost,
        'stock': stock,
        'category': category,
      };

  Product copyWith({int? stock}) {
    return Product(
      id: id,
      name: name,
      sku: sku,
      price: price,
      cost: cost,
      stock: stock ?? this.stock,
      category: category,
    );
  }

  /// Status ketersediaan stok: habis (0), menipis (1–10), tersedia (>10)
  StockStatus get stockStatus {
    if (stock <= 0) return StockStatus.out;
    if (stock <= 10) return StockStatus.low;
    return StockStatus.available;
  }
}
