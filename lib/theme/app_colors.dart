import 'package:flutter/material.dart';

/// Palet warna sentral untuk seluruh aplikasi POS.
///
/// Dipakai konsisten di semua layar, menggantikan penggunaan warna
/// hardcoded satu per satu agar tampilan seragam dan mudah disesuaikan.
class AppColors {
  AppColors._();

  /// Warna utama (brand) — jamak dipakai untuk tombol, aksen, dan highlight.
  static const Color primary = Color(0xFF1E88E5);

  /// Latar belakang layar / area konten.
  static const Color background = Color(0xFFF4F6F8);

  /// Warna permukaan kartu / panel (putih).
  static const Color surface = Colors.white;

  /// Teks utama / gelap.
  static const Color textDark = Color(0xFF1F2937);

  /// Teks sekunder / redup.
  static const Color textMuted = Color(0xFF6B7280);

  /// Warna garis / border (stroke).
  static const Color border = Color(0xFFE5E7EB);

  /// Warna keberhasilan (mis. harga, stok tersedia).
  static const Color success = Color(0xFF16A34A);

  /// Warna peringatan (mis. stok menipis).
  static const Color warning = Color(0xFFF59E0B);

  /// Warna bahaya / error (mis. stok habis, hapus).
  static const Color danger = Color(0xFFDC2626);

  /// Radius sudut default untuk kartu & container.
  static const double radius = 14;
}