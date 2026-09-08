/// Ringkasan penjualan untuk satu periode (dari endpoint /reports/period).
class ReportSummary {
  final double totalRevenue;
  final int totalTransactions;
  final int unitsSold;
  final double averageTransaction;
  final double totalCost;
  final double totalProfit;
  final double margin; // persen

  ReportSummary({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.unitsSold,
    required this.averageTransaction,
    required this.totalCost,
    required this.totalProfit,
    required this.margin,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalTransactions: (json['totalTransactions'] as num?)?.toInt() ?? 0,
      unitsSold: (json['unitsSold'] as num?)?.toInt() ?? 0,
      averageTransaction:
          (json['averageTransaction'] as num?)?.toDouble() ?? 0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
      margin: (json['margin'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Satu titik data grafik: label (tanggal atau jam) + total penjualan.
class ChartPoint {
  final String label;
  final double total;

  ChartPoint({required this.label, required this.total});

  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    return ChartPoint(
      label: json['label']?.toString() ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Produk terlaris: nama, jumlah terjual, omzet, dan laba.
class TopSellingProduct {
  final String name;
  final int qty;
  final double revenue;
  final double profit;

  TopSellingProduct({
    required this.name,
    required this.qty,
    required this.revenue,
    required this.profit,
  });

  factory TopSellingProduct.fromJson(Map<String, dynamic> json) {
    return TopSellingProduct(
      name: json['name']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Ringkasan per metode pembayaran: jumlah transaksi + total omzet.
class PaymentMethodSummary {
  final String method;
  final int count;
  final double total;

  PaymentMethodSummary({
    required this.method,
    required this.count,
    required this.total,
  });
}

/// Laporan analisis periode dari endpoint /reports/period.
///
/// Berisi ringkasan penjualan, perbandingan periode, grafik, produk terlaris,
/// dan metode pembayaran. Daftar transaksi individual ditangani terpisah oleh
/// halaman Riwayat Transaksi.
class PeriodReport {
  final String start;
  final String end;
  final ReportSummary summary;
  final ReportSummary? previousSummary;
  final List<ChartPoint> chartData;
  final List<TopSellingProduct> topProducts;
  final List<PaymentMethodSummary> paymentSummary;

  PeriodReport({
    required this.start,
    required this.end,
    required this.summary,
    required this.previousSummary,
    required this.chartData,
    required this.topProducts,
    required this.paymentSummary,
  });

  factory PeriodReport.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final prevJson = json['previousSummary'] as Map<String, dynamic>?;

    List<ChartPoint> chartData = [];
    if (json['chartData'] is List) {
      chartData = (json['chartData'] as List)
          .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<TopSellingProduct> topProducts = [];
    if (json['topProducts'] is List) {
      topProducts = (json['topProducts'] as List)
          .map((e) => TopSellingProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<PaymentMethodSummary> paymentSummary = [];
    if (json['paymentSummary'] is Map) {
      (json['paymentSummary'] as Map).forEach((key, value) {
        final v = value as Map<String, dynamic>;
        paymentSummary.add(PaymentMethodSummary(
          method: key.toString(),
          count: (v['count'] as num?)?.toInt() ?? 0,
          total: (v['total'] as num?)?.toDouble() ?? 0,
        ));
      });
      paymentSummary.sort((a, b) => b.total.compareTo(a.total));
    }

    return PeriodReport(
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      summary: ReportSummary.fromJson(summaryJson),
      previousSummary:
          prevJson != null ? ReportSummary.fromJson(prevJson) : null,
      chartData: chartData,
      topProducts: topProducts,
      paymentSummary: paymentSummary,
    );
  }
}
