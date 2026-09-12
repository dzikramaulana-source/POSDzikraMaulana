/// Pengaturan sistem aplikasi POS.
///
/// [taxRate] adalah tarif PPN dalam satuan persen (mis. 10 = 10%).
class AppSettings {
  static const double defaultTaxRate = 10;

  final double taxRate;

  const AppSettings({required this.taxRate});

  /// Tarif PPN sebagai pecahan (mis. 0.10) untuk perhitungan.
  double get taxRateFraction => taxRate / 100;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? defaultTaxRate,
    );
  }

  Map<String, dynamic> toJson() => {'taxRate': taxRate};
}
