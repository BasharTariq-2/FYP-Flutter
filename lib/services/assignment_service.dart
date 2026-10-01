// lib/services/assignment_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';
import '../models/assignment.dart';

class AssignmentService {
  Future<ShedAssignment> assignManager(int shedId, String managerUsername) async {
    final token = await SessionStore.getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/assignments/assign-manager'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'shed_id': shedId,
        'manager_username': managerUsername,
      }),
    );

    if (response.statusCode == 200) {
      return ShedAssignment.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body)['detail'];
    throw Exception(error ?? 'Failed to assign manager');
  }

  Future<ShedAssignment?> getShedManager(int shedId) async {
    final token = await SessionStore.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/assignments/shed/$shedId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return ShedAssignment.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<void> revokeAssignment(int assignmentId) async {
    final token = await SessionStore.getToken();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/assignments/revoke/$assignmentId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to revoke assignment');
    }
  }
}
