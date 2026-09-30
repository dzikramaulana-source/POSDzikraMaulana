import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';

/// Gambar barcode EAN-13 milik sebuah produk.
///
/// Gambar dibentuk sepenuhnya dari [Product.barcode] yang tersimpan di MongoDB,
/// bukan dari data acak. Untuk angka barcode yang sama, bentuk yang dihasilkan
/// selalu identik (permanen) di setiap halaman, sesi, maupun perangkat.
class ProductBarcode extends StatelessWidget {
  final Product product;

  /// Tinggi area batang barcode (tanpa angka di bawahnya).
  final double height;

  const ProductBarcode({super.key, required this.product, this.height = 78});

  /// Hanya barcode EAN-13 valid (13 digit dengan check digit benar) yang
  /// digambar, sehingga widget tidak pernah gagal render.
  bool get _isValid =>
      product.hasBarcode && Barcode.ean13().isValid(product.barcode);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_2, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text(
                'Barcode Produk',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isValid)
            Center(
              child: BarcodeWidget(
                barcode: Barcode.ean13(),
                data: product.barcode,
                height: height,
                drawText: true,
                color: AppColors.textDark,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                style: const TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            )
          else
            const _BarcodeUnavailable(),
        ],
      ),
    );
  }
}

class _BarcodeUnavailable extends StatelessWidget {
  const _BarcodeUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Barcode belum tersedia untuk produk ini.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
