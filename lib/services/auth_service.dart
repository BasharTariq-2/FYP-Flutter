import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await SessionStore.saveToken(data['access_token']);
      return data;
    }
    throw Exception('Login failed');
  }

  Future<void> registerOwner(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register/owner'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    if (response.statusCode != 200) throw Exception('Registration failed');
  }

  Future<void> registerManager(String username, String email, String password, String ownerEmail) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register/manager'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'owner_email': ownerEmail,
      }),
    );
    if (response.statusCode != 200) throw Exception('Registration failed');
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await SessionStore.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get user');
  }
  Future<List<Map<String, dynamic>>> listManagers() async {
    final token = await SessionStore.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/managers'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
}