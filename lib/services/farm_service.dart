import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';

class FarmService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getAll() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/farms/'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('Error loading farms: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> create(String farmName, String location) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/farms/'),
      headers: await _headers(),
      body: jsonEncode({
        'farm_name': farmName,
        'location': location,
        'no_of_sheds': 0,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create farm');
  }
}