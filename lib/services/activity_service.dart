// lib/services/activity_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';
import '../models/activity.dart';

class ActivityService {
  Future<List<ActivityLog>> getRecentActivities({int limit = 10}) async {
    final token = await SessionStore.getToken();
    print('DEBUG: Fetching activities from ${ApiConfig.baseUrl}/activities/recent');
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/activities/recent?limit=$limit'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('DEBUG: Response status: ${response.statusCode}');
    print('DEBUG: Response body: ${response.body}');

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((json) => ActivityLog.fromJson(json)).toList();
    }
    throw Exception('Failed to load activities');
  }
}
