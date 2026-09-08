/// Ringkasan per metode pembayaran dalam satu shift.
class ShiftPaymentSummary {
  final String method;
  final int count;
  final double total;

  ShiftPaymentSummary({
    required this.method,
    required this.count,
    required this.total,
  });

  factory ShiftPaymentSummary.fromJson(Map<String, dynamic> json) {
    return ShiftPaymentSummary(
      method: json['method']?.toString() ?? 'cash',
      count: (json['count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Ringkasan transaksi selama shift.
class ShiftSummary {
  final int totalTransactions;
  final double totalSales;
  final double cashSales;
  final List<ShiftPaymentSummary> paymentSummary;

  ShiftSummary({
    required this.totalTransactions,
    required this.totalSales,
    required this.cashSales,
    required this.paymentSummary,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ShiftSummary(
        totalTransactions: 0,
        totalSales: 0,
        cashSales: 0,
        paymentSummary: [],
      );
    }

    List<ShiftPaymentSummary> paymentSummary = [];
    if (json['paymentSummary'] is List) {
      paymentSummary = (json['paymentSummary'] as List)
          .map((e) => ShiftPaymentSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ShiftSummary(
      totalTransactions: (json['totalTransactions'] as num?)?.toInt() ?? 0,
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0,
      cashSales: (json['cashSales'] as num?)?.toDouble() ?? 0,
      paymentSummary: paymentSummary,
    );
  }
}

/// Satu periode shift kasir: buka → tutup.
class Shift {
  final String id;
  final String kasirId;
  final String kasirName;
  final bool isOpen;
  final double openingCash;
  final double? closingCash;
  final DateTime openedAt;
  final DateTime? closedAt;
  final bool autoClosed;
  final ShiftSummary? summary;

  Shift({
    required this.id,
    required this.kasirId,
    required this.kasirName,
    required this.isOpen,
    required this.openingCash,
    required this.closingCash,
    required this.openedAt,
    required this.closedAt,
    required this.autoClosed,
    required this.summary,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    final kasir = json['kasir'];
    String kasirId = json['kasir']?.toString() ?? '';
    String kasirName = '';
    if (kasir is Map<String, dynamic>) {
      kasirId = kasir['_id']?.toString() ?? kasirId;
      kasirName = kasir['name']?.toString() ?? '';
    }

    final summaryJson = json['summary'] as Map<String, dynamic>?;
    final status = json['status']?.toString() ?? 'open';

    return Shift(
      id: json['_id']?.toString() ?? '',
      kasirId: kasirId,
      kasirName: kasirName,
      isOpen: status == 'open',
      openingCash: (json['openingCash'] as num?)?.toDouble() ?? 0,
      closingCash: (json['closingCash'] as num?)?.toDouble(),
      openedAt:
          DateTime.tryParse(json['openedAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      closedAt:
          DateTime.tryParse(json['closedAt']?.toString() ?? '')?.toLocal(),
      autoClosed: json['autoClosed'] == true,
      summary: summaryJson != null ? ShiftSummary.fromJson(summaryJson) : null,
    );
  }
}
