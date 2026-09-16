import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_sop/utils/whatsapp_sender.dart';

void main() {
  group('lastFourDigitsOf', () {
    test('mengambil 4 digit terakhir dan mengabaikan tanda pemisah', () {
      expect(lastFourDigitsOf('0812-3456-7890'), '7890');
      expect(lastFourDigitsOf('+62 812 3456 7890'), '7890');
    });

    test('kosong sebelum 4 digit diketik', () {
      expect(lastFourDigitsOf('789'), '');
      expect(lastFourDigitsOf(''), '');
    });
  });

  group('formatWhatsAppNumber', () {
    test('menampilkan nomor dalam format lokal yang mudah dibaca', () {
      expect(formatWhatsAppNumber('6281234567890'), '0812-3456-7890');
      expect(formatWhatsAppNumber('08123456789'), '0812-3456-789');
    });
  });
}
