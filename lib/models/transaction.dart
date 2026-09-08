class CartItem {
  final String productId;
  final String name;
  final double price;
  int qty;
  final int maxStock;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.maxStock,
  });

  double get subtotal => price * qty;

  Map<String, dynamic> toJson() => {
        'product': productId,
        'qty': qty,
      };
}

class Transaction {
  final String id;
  final String invoiceNumber;
  final List<TransactionItem> items;
  final double total;
  final double profit;
  final String paymentMethod;
  final double cashReceived;
  final double change;
  final String createdByName;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.invoiceNumber,
    required this.items,
    required this.total,
    required this.profit,
    required this.paymentMethod,
    required this.cashReceived,
    required this.change,
    required this.createdByName,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    String createdByName = '';
    if (createdBy is Map<String, dynamic>) {
      createdByName = createdBy['name']?.toString() ?? '';
    }

    List<TransactionItem> items = [];
    if (json['items'] is List) {
      items = (json['items'] as List)
          .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Transaction(
      id: json['_id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      items: items,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      cashReceived: (json['cashReceived'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      createdByName: createdByName,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class TransactionItem {
  final String name;
  final double price;
  final int qty;
  final double subtotal;

  TransactionItem({
    required this.name,
    required this.price,
    required this.qty,
    required this.subtotal,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Satu halaman hasil pencarian Riwayat Transaksi (dari /transactions/history).
class TransactionHistoryPage {
  final List<Transaction> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  TransactionHistoryPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory TransactionHistoryPage.fromJson(Map<String, dynamic> json) {
    List<Transaction> items = [];
    if (json['transactions'] is List) {
      items = (json['transactions'] as List)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return TransactionHistoryPage(
      items: items,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class DailyReport {
  final String date;
  final int totalTransactions;
  final double totalRevenue;
  final double totalProfit;
  final double averageTransaction;
  final List<TopProduct> topProducts;
  final Map<String, PaymentSummary> paymentSummary;

  DailyReport({
    required this.date,
    required this.totalTransactions,
    required this.totalRevenue,
    required this.totalProfit,
    required this.averageTransaction,
    required this.topProducts,
    required this.paymentSummary,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};

    List<TopProduct> topProducts = [];
    if (json['topProducts'] is List) {
      topProducts = (json['topProducts'] as List)
          .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    Map<String, PaymentSummary> paymentSummary = {};
    if (json['paymentSummary'] is Map) {
      (json['paymentSummary'] as Map).forEach((key, value) {
        final v = value as Map<String, dynamic>;
        paymentSummary[key.toString()] = PaymentSummary(
          count: (v['count'] as num?)?.toInt() ?? 0,
          total: (v['total'] as num?)?.toDouble() ?? 0,
        );
      });
    }

    return DailyReport(
      date: json['date']?.toString() ?? '',
      totalTransactions: (summary['totalTransactions'] as num?)?.toInt() ?? 0,
      totalRevenue: (summary['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalProfit: (summary['totalProfit'] as num?)?.toDouble() ?? 0,
      averageTransaction:
          (summary['averageTransaction'] as num?)?.toDouble() ?? 0,
      topProducts: topProducts,
      paymentSummary: paymentSummary,
    );
  }
}

class TopProduct {
  final String name;
  final int qty;
  final double revenue;

  TopProduct({
    required this.name,
    required this.qty,
    required this.revenue,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      name: json['name']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PaymentSummary {
  final int count;
  final double total;

  PaymentSummary({
    required this.count,
    required this.total,
  });
}
