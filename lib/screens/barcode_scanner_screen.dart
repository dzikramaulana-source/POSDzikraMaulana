import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';

/// Hasil satu kali scan: sukses (produk masuk keranjang) atau gagal.
class BarcodeScanResult {
  final bool success;
  final String message;

  const BarcodeScanResult(this.success, this.message);
}

/// Layar kamera untuk memindai barcode produk.
///
/// Kamera sengaja tetap terbuka setelah scan berhasil supaya kasir dapat
/// memindai beberapa produk berturut-turut tanpa membuka layar berulang kali.
/// Setiap hasil scan dikirim ke [onScan] yang mengembalikan pesan status untuk
/// ditampilkan sebagai banner.
class BarcodeScannerScreen extends StatefulWidget {
  final Future<BarcodeScanResult> Function(String barcode) onScan;

  const BarcodeScannerScreen({super.key, required this.onScan});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Format barcode ritel/numerik (barcode produk yang dibuat server = EAN-13).
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
    ],
  );

  /// Mencegah satu barcode terproses berkali-kali dalam waktu singkat.
  bool _busy = false;
  bool _torchOn = false;
  String? _message;
  bool _messageOk = true;

  /// Plugin kamera tidak punya implementasi untuk Windows/Linux desktop.
  bool get _isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Perangkat tanpa flash: abaikan.
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_busy) return;

    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;

    setState(() => _busy = true);

    BarcodeScanResult result;
    try {
      result = await widget.onScan(code);
    } catch (e) {
      result = BarcodeScanResult(false, 'Gagal memproses barcode: $e');
    }

    if (!mounted) return;
    setState(() {
      _message = result.message;
      _messageOk = result.success;
    });

    // Beri jeda singkat agar pesan terbaca sebelum scan berikutnya diproses.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isSupported ? _buildScanner() : _buildUnsupported(),
    );
  }

  Widget _buildUnsupported() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  size: 56, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Scan barcode tidak tersedia di perangkat ini',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fitur scan kamera hanya berjalan di Android, iOS, atau browser. '
                'Gunakan pencarian manual atau tombol produk untuk menambah item.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _handleDetection,
          errorBuilder: (context, error) {
            final denied =
                error.errorCode == MobileScannerErrorCode.permissionDenied;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      denied ? Icons.no_photography_outlined : Icons.error_outline,
                      size: 52,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      denied
                          ? 'Izin kamera ditolak'
                          : 'Kamera tidak dapat dibuka',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      denied
                          ? 'Izinkan akses kamera untuk aplikasi ini di pengaturan perangkat, lalu coba lagi.'
                          : error.errorDetails?.message ??
                              'Pastikan kamera tidak sedang dipakai aplikasi lain.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Bingkai pandu scan
        Center(
          child: SizedBox(
            width: 260,
            height: 190,
            child: CustomPaint(
              painter: _ScanFramePainter(
                color: _busy ? AppColors.success : Colors.white,
              ),
            ),
          ),
        ),

        // Bar atas: judul, senter, tutup
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Barcode Produk',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _CircleIconButton(
                    icon: _torchOn
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    tooltip: 'Senter',
                    onPressed: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Banner pesan hasil scan + petunjuk
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _messageOk ? AppColors.success : AppColors.danger,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _messageOk
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Arahkan kamera ke barcode produk. Produk yang terbaca '
                    'langsung masuk ke keranjang — kamera tetap terbuka untuk '
                    'scan berikutnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Bingkai pandu scan: empat sudut siku.
class _ScanFramePainter extends CustomPainter {
  final Color color;

  const _ScanFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 28.0;

    // Kiri atas
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // Kanan atas
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    // Kiri bawah
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);
    // Kanan bawah
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) => oldDelegate.color != color;
}
