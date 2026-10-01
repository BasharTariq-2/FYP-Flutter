// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../core/api_config.dart';
// import '../core/session_store.dart';
//
// class HealthService {
//   Future<Map<String, String>> _headers() async {
//     final token = await SessionStore.getToken();
//     return {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     };
//   }
//
//   Future<Map<String, dynamic>> getMonitorInit(int batchId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/health/batch/$batchId/monitor-init'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ getMonitorInit Error: $e');
//       return {};
//     }
//   }
//
//   Future<Map<String, dynamic>> assessHealth(int batchId, double weightGrams, double temperatureC) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl}/health/assess-batch/$batchId'),
//         headers: await _headers(),
//         body: jsonEncode({
//           'weight_grams': weightGrams,
//           'temperature_c': temperatureC,
//         }),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ assessHealth Error: $e');
//       return {};
//     }
//   }
//
//   Future<Map<String, dynamic>> startMonitoring(int batchId, {String mode = 'active', int? isolationId}) async {
//     try {
//       String urlStr = '${ApiConfig.baseUrl}/hardware/monitor/start?batch_id=$batchId&mode=$mode';
//       if (mode == 'isolated' && isolationId != null) {
//         urlStr += '&isolation_id=$isolationId';
//       }
//       final response = await http.post(
//         Uri.parse(urlStr),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ startMonitoring Error: $e');
//       return {};
//     }
//   }
//
//   Future<List<dynamic>> getActiveSessions() async {
//     try {
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/monitor/active-sessions'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return [];
//     } catch (e) {
//       print('❌ getActiveSessions Error: $e');
//       return [];
//     }
//   }
//
//   Future<bool> pauseMonitoring(String sessionId) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/monitor/pause?session_id=$sessionId'),
//         headers: await _headers(),
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       print('❌ pauseMonitoring Error: $e');
//       return false;
//     }
//   }
//
//   Future<bool> resumeMonitoring(String sessionId) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/monitor/resume?session_id=$sessionId'),
//         headers: await _headers(),
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       print('❌ resumeMonitoring Error: $e');
//       return false;
//     }
//   }
//
//   Future<bool> completeMonitoring(String sessionId) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/monitor/complete?session_id=$sessionId'),
//         headers: await _headers(),
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       print('❌ completeMonitoring Error: $e');
//       return false;
//     }
//   }
//
//   Future<Map<String, dynamic>> getSessionChickCount(int batchId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/health/session-count/$batchId'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ getSessionChickCount Error: $e');
//       return {};
//     }
//   }
//
//   Future<bool> controlMotor(int batchId, String direction) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/motor/$batchId?direction=$direction'),
//         headers: await _headers(),
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       print('❌ controlMotor Error: $e');
//       return false;
//     }
//   }
//
//   Future<Map<String, dynamic>> getLatestHealth(int batchId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/health/latest/$batchId'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ getLatestHealth Error: $e');
//       return {};
//     }
//   }
//
//   Future<Map<String, dynamic>> getCategorizedChicks(int batchId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/health/categorized-chicks/$batchId'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ getCategorizedChicks Error: $e');
//       return {};
//     }
//   }
//
//   Future<List<dynamic>> getStandards() async {
//     try {
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/health/standards'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return [];
//     } catch (e) {
//       print('❌ getStandards Error: $e');
//       return [];
//     }
//   }
//
//   Future<Map<String, dynamic>> getSensorOffsets(int batchId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/sensor-offset/$batchId'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ getSensorOffsets Error: $e');
//       return {};
//     }
//   }
//
//   Future<Map<String, dynamic>> updateSensorOffsets(int batchId, double weightOffset, double temperatureOffset) async {
//     try {
//       final response = await http.put(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/sensor-offset/$batchId'),
//         headers: await _headers(),
//         body: jsonEncode({
//           'weight_offset': weightOffset,
//           'temperature_offset': temperatureOffset,
//         }),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ updateSensorOffsets Error: $e');
//       return {};
//     }
//   }
//
//   Future<Map<String, dynamic>> handleCriticalChicks({
//     required String sessionId,
//     required int batchId,
//     required String action,
//     required int count,
//     required String reason,
//   }) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl}/hardware/monitor/handle-criticals'),
//         headers: await _headers(),
//         body: jsonEncode({
//           'session_id': sessionId,
//           'batch_id': batchId,
//           'action': action,
//           'count': count,
//           'reason': reason,
//         }),
//       );
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       }
//       return {};
//     } catch (e) {
//       print('❌ handleCriticalChicks Error: $e');
//       return {};
//     }
//   }
//
//   Future<List<dynamic>> getIsolatedChicks({int? batchId}) async {
//     try {
//       final queryParam = batchId != null ? '?batch_id=$batchId' : '';
//       final response = await http.get(
//         Uri.parse('${ApiConfig.baseUrl}/isolation/isolated$queryParam'),
//         headers: await _headers(),
//       );
//       if (response.statusCode == 200) {
//         final decoded = jsonDecode(response.body);
//         if (decoded is List) {
//           return decoded;
//         } else if (decoded is Map && decoded.containsKey('isolations')) {
//           return List<dynamic>.from(decoded['isolations'] ?? []);
//         }
//       }
//       return [];
//     } catch (e) {
//       print('❌ getIsolatedChicks Error: $e');
//       return [];
//     }
//   }
// }
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';

class HealthService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── GET /health/batch/{id}/monitor-init ──────────────────────────────────
  Future<Map<String, dynamic>> getMonitorInit(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health/batch/$batchId/monitor-init'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ getMonitorInit Error: $e');
      return {};
    }
  }

  // ── POST /health/assess-batch/{id} ───────────────────────────────────────
  Future<Map<String, dynamic>> assessHealth(
      int batchId, double weightGrams, double temperatureC) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/health/assess-batch/$batchId'),
        headers: await _headers(),
        body: jsonEncode({
          'weight_grams': weightGrams,
          'temperature_c': temperatureC,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ assessHealth Error: $e');
      return {};
    }
  }

  // ── GET /health/batch/{id}/logs ── (Next.js: getHealthLogs) ─────────────
  Future<List<dynamic>> getHealthLogs(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health/batch/$batchId/logs'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('❌ getHealthLogs Error: $e');
      return [];
    }
  }

  // ── GET /health/batch/{id}/summary ── (Next.js: getSummary) ─────────────
  Future<Map<String, dynamic>> getHealthSummary(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health/batch/$batchId/summary'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ getHealthSummary Error: $e');
      return {};
    }
  }

  // ── POST /hardware/monitor/start ─────────────────────────────────────────
  Future<Map<String, dynamic>> startMonitoring(int batchId,
      {String mode = 'active', int? isolationId}) async {
    try {
      String urlStr =
          '${ApiConfig.baseUrl}/hardware/monitor/start?batch_id=$batchId&mode=$mode';
      if (mode == 'isolated' && isolationId != null) {
        urlStr += '&isolation_id=$isolationId';
      }
      final response = await http.post(
        Uri.parse(urlStr),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ startMonitoring Error: $e');
      return {};
    }
  }

  // ── GET /hardware/monitor/active-sessions ────────────────────────────────
  Future<List<dynamic>> getActiveSessions() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/hardware/monitor/active-sessions'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('❌ getActiveSessions Error: $e');
      return [];
    }
  }

  // ── POST /hardware/monitor/next ── (Next.js: monitorNextChick) ──────────
  Future<Map<String, dynamic>> monitorNextChick(
      String sessionId, double weightGrams, double temperatureC) async {
    try {
      final urlStr = '${ApiConfig.baseUrl}/hardware/monitor/next'
          '?session_id=$sessionId&weight_grams=$weightGrams&temperature_c=$temperatureC';
      final response = await http.post(
        Uri.parse(urlStr),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ monitorNextChick Error: $e');
      return {};
    }
  }

  // ── POST /hardware/monitor/pause ─────────────────────────────────────────
  Future<bool> pauseMonitoring(String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/hardware/monitor/pause?session_id=$sessionId'),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ pauseMonitoring Error: $e');
      return false;
    }
  }

  // ── POST /hardware/monitor/resume ────────────────────────────────────────
  Future<bool> resumeMonitoring(String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/hardware/monitor/resume?session_id=$sessionId'),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ resumeMonitoring Error: $e');
      return false;
    }
  }

  // ── POST /hardware/monitor/complete ──────────────────────────────────────
  Future<bool> completeMonitoring(String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/hardware/monitor/complete?session_id=$sessionId'),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ completeMonitoring Error: $e');
      return false;
    }
  }

  // ── POST /hardware/monitor/handle-criticals ──────────────────────────────
  Future<Map<String, dynamic>> handleCriticalChicks({
    required String sessionId,
    required int batchId,
    String action = 'none',
    int count = 0,
    String? reason,
    int? lowWeightCount,
    int? highFeverCount,
    String? lowWeightAction,
    String? highFeverAction,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/hardware/monitor/handle-criticals'),
        headers: await _headers(),
        body: jsonEncode({
          'session_id': sessionId,
          'batch_id': batchId,
          'action': action,
          'count': count,
          'reason': reason ??
              'Critical condition: Low weight / High fever detected during monitoring',
          'low_weight_count': lowWeightCount,
          'high_fever_count': highFeverCount,
          'low_weight_action': lowWeightAction ?? 'none',
          'high_fever_action': highFeverAction ?? 'none',
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(
          'handleCriticalChicks failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      print('❌ handleCriticalChicks Error: $e');
      rethrow;
    }
  }

  // ── GET /hardware/health/session-count/{batch_id}?session_id= ───────────
  // Next.js passes session_id as query param — Flutter version was missing it
  Future<Map<String, dynamic>> getSessionChickCount(int batchId,
      {String? sessionId}) async {
    try {
      String urlStr =
          '${ApiConfig.baseUrl}/hardware/health/session-count/$batchId';
      if (sessionId != null && sessionId.isNotEmpty) {
        urlStr += '?session_id=$sessionId';
      }
      final response = await http.get(
        Uri.parse(urlStr),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ getSessionChickCount Error: $e');
      return {};
    }
  }

  // ── POST /hardware/motor/{batch_id} ──────────────────────────────────────
  Future<bool> controlMotor(int batchId, String direction) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/hardware/motor/$batchId?direction=$direction'),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ controlMotor Error: $e');
      return false;
    }
  }

  // ── GET /hardware/health/latest/{batch_id} ───────────────────────────────
  Future<Map<String, dynamic>> getLatestHealth(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/hardware/health/latest/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ getLatestHealth Error: $e');
      return {};
    }
  }

  // ── GET /hardware/health/categorized-chicks/{batch_id} ──────────────────
  Future<Map<String, dynamic>> getCategorizedChicks(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/hardware/health/categorized-chicks/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ getCategorizedChicks Error: $e');
      return {};
    }
  }

  // ── GET /health/standards ────────────────────────────────────────────────
  Future<List<dynamic>> getStandards() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health/standards'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('❌ getStandards Error: $e');
      return [];
    }
  }

  // ── GET /hardware/sensor-offset/{batch_id} ── ❗ WAS MISSING ─────────────
  Future<Map<String, dynamic>> getSensorOffsets(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/hardware/sensor-offset/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ getSensorOffsets Error: $e');
      return {};
    }
  }

  // ── PUT /hardware/sensor-offset/{batch_id} ── ❗ WAS MISSING ─────────────
  Future<bool> updateSensorOffsets(
      int batchId, double weightOffset, double temperatureOffset) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/hardware/sensor-offset/$batchId'),
        headers: await _headers(),
        body: jsonEncode({
          'weight_offset': weightOffset,
          'temperature_offset': temperatureOffset,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ updateSensorOffsets Error: $e');
      return false;
    }
  }
}