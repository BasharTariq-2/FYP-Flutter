import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';
import '';
class VaccinationService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<List<dynamic>> getSchedule(int batchId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/vaccinations/batch/$batchId/schedule'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    }
    return [];
  }

  Future<List<dynamic>> getRecords(int batchId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/vaccinations/batch/$batchId/records'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    }
    return [];
  }

  // ── NEW: dashboard alerts for a selected date ──────────────────────
  // GET /vaccinations/for-date?selected_date=YYYY-MM-DD&shed_id=optional
  Future<List<dynamic>> getAlertsForDate({
    required String selectedDate,
    int? shedId,
  }) async {
    final queryParams = <String, String>{
      'selected_date': selectedDate,
      if (shedId != null) 'shed_id': shedId.toString(),
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/vaccinations/for-date')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    }
    return [];
  }

  Future<bool> recordVaccination(int scheduleId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/vaccinations/record/$scheduleId'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
}