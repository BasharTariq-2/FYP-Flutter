import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';
import '../models/isolation.dart';
import 'dart:async'; // ← yeh add karo

class IsolationService {
  // ── shared client with timeout ──────────────────────────────
  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  IsolationService({http.Client? client}) : _client = client ?? http.Client();

  // ── shared headers helper ───────────────────────────────────
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found. Please login again.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ── shared error handler ────────────────────────────────────
  Never _handleError(http.Response response, String context) {
    debugPrint('[$context] Status: ${response.statusCode}');
    debugPrint('[$context] Body: ${response.body}');

    switch (response.statusCode) {
      case 401:
        throw Exception('Session expired. Please login again.');
      case 403:
        throw Exception('Access denied.');
      case 404:
        throw Exception('Resource not found.');
      case 500:
        throw Exception('Server error (500). Please try again later.');
      default:
        throw Exception('Failed ($context): ${response.statusCode}');
    }
  }

  // ── GET isolation history ───────────────────────────────────
  Future<List<IsolationRecord>> getIsolationHistory(int batchId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/isolation/batch/$batchId'),
            headers: await _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => IsolationRecord.fromJson(item)).toList();
      } else {
        _handleError(response, 'getIsolationHistory');
      }
    } on SocketException {
      throw Exception('No internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Check your connection.');
    } catch (e) {
      debugPrint('getIsolationHistory error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getIsolatedGroups({int? batchId}) async {
    try {
      final query = batchId != null ? '?batch_id=$batchId' : '';
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/isolation/isolated$query'),
            headers: await _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded;
        }
        if (decoded is Map && decoded.containsKey('isolations')) {
          return List<dynamic>.from(decoded['isolations'] ?? []);
        }
        return [];
      } else {
        _handleError(response, 'getIsolatedGroups');
      }
    } on SocketException {
      throw Exception('No internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Check your connection.');
    } catch (e) {
      debugPrint('getIsolatedGroups error: $e');
      rethrow;
    }
  }

  // ── GET active isolations ───────────────────────────────────
  Future<List<dynamic>> getActiveIsolations(int batchId) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/isolation/isolated?batch_id=$batchId',
            ),
            headers: await _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List data = json.decode(
          response.body,
        ); // ← Map<String, dynamic> ki jagah List
        return data; // ← data['isolations'] ki jagah seedha List return
      } else {
        _handleError(response, 'getActiveIsolations');
      }
    } on SocketException {
      throw Exception('No internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Check your connection.');
    } catch (e) {
      debugPrint('getActiveIsolations error: $e');
      rethrow;
    }
  }

  // ── dispose ─────────────────────────────────────────────────
  void dispose() => _client.close();
}
