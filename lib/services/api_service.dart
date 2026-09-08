import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const String _tokenKey = 'auth_token';

  // Simpan token JWT ke shared_preferences
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Ambil token tersimpan
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Hapus token (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Header dasar + token
  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<dynamic> get(String path, {bool withAuth = true}) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}$path');
    final response = await http
        .get(uri, headers: await _headers(withAuth: withAuth))
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body,
      {bool withAuth = true}) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}$path');
    final response = await http
        .post(uri,
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body,
      {bool withAuth = true}) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}$path');
    final response = await http
        .put(uri,
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body,
      {bool withAuth = true}) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}$path');
    final response = await http
        .patch(uri,
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String path, {bool withAuth = true}) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}$path');
    final response = await http
        .delete(uri, headers: await _headers(withAuth: withAuth))
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    // Ambil pesan error dari body
    String message = 'Terjadi kesalahan (${response.statusCode})';
    if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    } else if (response.statusCode == 401) {
      message = 'Sesi berakhir, silakan login ulang';
    }

    throw ApiException(message, statusCode: response.statusCode);
  }
}
