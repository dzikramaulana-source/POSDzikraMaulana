import 'package:flutter/material.dart';

/// Palet warna modern & profesional untuk seluruh aplikasi POS.
///
/// Menggunakan kombinasi Slate Navy (#0F172A / #1E3A8A) dan Royal Blue (#2563EB)
/// serta aksen Emerald (#10B981) yang bersih, kontras tinggi, dan nyaman di mata.
class AppColors {
  AppColors._();

  /// Warna utama (brand) — Royal Blue profesional ala fintech/SaaS.
  static const Color primary = Color(0xFF2563EB);

  /// Deep Navy untuk navbar, sidebar, atau header elegan.
  static const Color primaryDark = Color(0xFF0F172A);

  /// Biru muda untuk latar belakang aktif / chip aktif.
  static const Color primaryLight = Color(0xFFEFF6FF);

  /// Warna aksen cerah (warm amber / orange).
  static const Color accent = Color(0xFFF59E0B);

  /// Latar belakang layar (soft crisp slate-50).
  static const Color background = Color(0xFFF8FAFC);

  /// Warna permukaan kartu / panel (putih bersih).
  static const Color surface = Colors.white;

  /// Teks utama / paling kontras (Slate-900).
  static const Color textDark = Color(0xFF0F172A);
  static const Color textPrimary = Color(0xFF0F172A);

  /// Teks menengah / judul sekunder (Slate-700).
  static const Color textMedium = Color(0xFF334155);

  /// Teks sekunder / redup (Slate-500).
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSecondary = Color(0xFF64748B);

  /// Warna permukaan varian halus (slate-50).
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  /// Warna border & pembatas halus (Slate-200).
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFE2E8F0);

  /// Warna border sedikit lebih tegas (Slate-300).
  static const Color borderStrong = Color(0xFFCBD5E1);

  /// Warna keberhasilan / pemasukan (Emerald).
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);

  /// Warna peringatan (Amber).
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);

  /// Warna bahaya / error (Rose Red).
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);

  /// Radius sudut standar.
  static const double radius = 14;

  /// Box shadow halus untuk card & container.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  /// Box shadow lebih melayang (dialog, modal, popover).
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}