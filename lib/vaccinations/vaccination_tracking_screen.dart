import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';

class VaccinationService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get upcoming vaccinations (global - for all batches user has access to)
  Future<List<dynamic>> getUpcoming() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vaccinations/upcoming'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getUpcoming Error: $e');
      return [];
    }
  }

  // Get overdue vaccinations (global - for all batches user has access to)
  Future<List<dynamic>> getOverdue() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vaccinations/overdue'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getOverdue Error: $e');
      return [];
    }
  }

  // Get vaccination schedule for a specific batch
  Future<List<dynamic>> getSchedule(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vaccinations/batch/$batchId/schedule'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getSchedule Error: $e');
      return [];
    }
  }

  // Get vaccination records (history) for a specific batch
  Future<List<dynamic>> getRecords(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vaccinations/batch/$batchId/records'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getRecords Error: $e');
      return [];
    }
  }

  // Record a vaccination (mark a schedule as completed)
  Future<bool> recordVaccination(int scheduleId, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/vaccinations/record/$scheduleId'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ recordVaccination Error: $e');
      return false;
    }
  }

  // Get vaccination summary for a batch (used by monitoring screen)
  Future<Map<String, dynamic>> getVaccinationSummary(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vaccinations/batch/$batchId/summary'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ getVaccinationSummary Error: $e');
      return {};
    }
  }
}