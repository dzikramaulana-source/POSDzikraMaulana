import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';

class WhatsAppService {
  // Cari nomor pelanggan yang pernah dikirimi struk berdasarkan 4 digit
  // terakhirnya lewat backend (endpoint GET /whatsapp/recipients).
  static Future<List<String>> searchRecipientsByLast4(String last4) async {
    final data = await ApiService.get('/whatsapp/recipients?last4=$last4');
    if (data is! List) return const <String>[];
    return data
        .whereType<Map>()
        .map((row) => row['phone']?.toString() ?? '')
        .where((phone) => phone.isNotEmpty)
        .toList();
  }

  // Kirim PDF struk ke nomor WhatsApp pelanggan lewat backend
  // (endpoint POST /whatsapp/send-document).
  static Future<Map<String, dynamic>> sendReceiptDocument({
    required String phone,
    required Uint8List pdfBytes,
    required String filename,
    String? caption,
  }) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}/whatsapp/send-document');
    final request = http.MultipartRequest('POST', uri);

    final token = await ApiService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['phone'] = phone;
    if (caption != null && caption.isNotEmpty) {
      request.fields['caption'] = caption;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        pdfBytes,
        filename: filename,
        // Wajib diisi agar server mengenali file sebagai PDF (bukan
        // application/octet-stream).
        contentType: http.MediaType('application', 'pdf'),
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final data = ApiService.handleResponse(response);
    return data as Map<String, dynamic>;
  }
}
