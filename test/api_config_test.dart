import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_sop/config/api_config.dart';

void main() {
  group('ApiConfig.normalize', () {
    test('menambahkan http:// dan port bawaan pada IP saja', () {
      expect(
        ApiConfig.normalize('192.168.0.13'),
        'http://192.168.0.13:3000',
      );
    });

    test('menambahkan http:// pada host:port', () {
      expect(
        ApiConfig.normalize('192.168.0.13:3000'),
        'http://192.168.0.13:3000',
      );
    });

    test('membuang garis miring di akhir', () {
      expect(
        ApiConfig.normalize('http://192.168.0.13:3000/'),
        'http://192.168.0.13:3000',
      );
      expect(
        ApiConfig.normalize('http://192.168.0.13:3000///'),
        'http://192.168.0.13:3000',
      );
    });

    test('membuang spasi di awal dan akhir', () {
      expect(
        ApiConfig.normalize('  192.168.0.13  '),
        'http://192.168.0.13:3000',
      );
    });

    test('tidak menimpa port yang sudah ditentukan', () {
      expect(
        ApiConfig.normalize('192.168.0.13:8080'),
        'http://192.168.0.13:8080',
      );
    });

    test('mempertahankan localhost dengan port eksplisit', () {
      expect(
        ApiConfig.normalize('http://localhost:3000'),
        'http://localhost:3000',
      );
    });

    test('melengkapi port pada localhost tanpa port', () {
      expect(ApiConfig.normalize('localhost'), 'http://localhost:3000');
    });

    test('mengembalikan alamat bawaan saat input kosong', () {
      expect(ApiConfig.normalize(''), ApiConfig.defaultBaseUrl);
      expect(ApiConfig.normalize('   '), ApiConfig.defaultBaseUrl);
    });
  });

  group('ApiConfig.isValid', () {
    test('menerima IP dan hostname', () {
      expect(ApiConfig.isValid('192.168.0.13'), isTrue);
      expect(ApiConfig.isValid('localhost'), isTrue);
      expect(ApiConfig.isValid('http://192.168.0.13:3000'), isTrue);
    });

    test('menolak input kosong', () {
      expect(ApiConfig.isValid(''), isFalse);
      expect(ApiConfig.isValid('   '), isFalse);
    });
  });

  group('ApiConfig.baseUrl', () {
    test('memakai alamat bawaan sebelum pengguna menyimpan apa pun', () {
      expect(ApiConfig.isCustom, isFalse);
      expect(ApiConfig.baseUrl, ApiConfig.defaultBaseUrl);
      expect(ApiConfig.apiUrl, '${ApiConfig.defaultBaseUrl}/api');
    });
  });
}
