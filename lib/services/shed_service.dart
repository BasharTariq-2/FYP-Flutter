import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';
import '../models/shed_performance_summary.dart';

class ShedService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<List<dynamic>> getShedsByFarm(int farmId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/farms/$farmId/sheds'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    }
    return [];
  }

  Future<bool> createShed({required int farmId, required String shedName, required int hensCapacity}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/sheds/'),
      headers: await _headers(),
      body: jsonEncode({'farm_id': farmId, 'shed_name': shedName, 'hens_capacity': hensCapacity}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<List<ShedPerformanceSummary>> getShedPerformanceSummary(int farmId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/sheds/farm-summary?farm_id=$farmId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((e) => ShedPerformanceSummary.fromJson(e)).toList();
      }
    }
    return [];
  }
}
