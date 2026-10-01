import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'session_store.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'HTTP $statusCode: $message';
}

class ApiClient {
  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await SessionStore.getToken();
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/$path'),
      headers: await _headers(),
    ).timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  // ✅ ADD MULTIPART METHODS
  static Future<dynamic> multipartImage({
    required String path,
    required String fieldName,
    required String filePath,
    required Map<String, String> fields,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/$path');
    final request = http.MultipartRequest('POST', uri);

    final token = await SessionStore.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(fieldName, filePath),
    );

    final streamedResponse = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
  }

  // ✅ ADD RAW MULTIPART METHOD
  static Future<Uint8List> multipartImageRaw({
    required String path,
    required String fieldName,
    required String filePath,
    required Map<String, String> fields,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/$path');
    final request = http.MultipartRequest('POST', uri);

    final token = await SessionStore.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(fieldName, filePath),
    );

    final streamedResponse = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException('Failed to upload image', statusCode: response.statusCode);
  }

  // ✅ ADD HEALTH CHECK METHOD
  static Future<bool> pingHealth() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.healthUrl),
      ).timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static dynamic _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(
        decoded['detail'] ?? 'Request failed',
        statusCode: response.statusCode
    );
  }
}