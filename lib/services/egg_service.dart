import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';

class EggService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get egg yields for a batch
  Future<List<dynamic>> getEggYields(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/eggs/yield/batch/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getEggYields Error: $e');
      return [];
    }
  }

  // Create egg yield
  Future<bool> createEggYield(int batchId, String grade, int produced) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/eggs/yield'),
        headers: await _headers(),
        body: jsonEncode({
          'batch_id': batchId,
          'grade': grade,
          'produced': produced,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ createEggYield Error: $e');
      return false;
    }
  }

  // Get egg sales for a batch
  Future<List<dynamic>> getEggSales(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/eggs/sale/batch/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getEggSales Error: $e');
      return [];
    }
  }

  // Create egg sale
  Future<bool> createEggSale({
    required int batchId,
    required String grade,
    required int eggsSold,
    required double pricePerEgg,
    String? saleDate,
  }) async {
    try {
      final body = {
        'batch_id': batchId,
        'grade': grade,
        'eggs_sold': eggsSold,
        'price_per_egg': pricePerEgg,
      };
      if (saleDate != null) body['sale_date'] = saleDate;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/eggs/sale'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ createEggSale Error: $e');
      return false;
    }
  }

  // Create egg sale returning full response (for error messages)
  Future<Map<String, dynamic>?> createEggSaleWithResponse({
    required int batchId,
    required String grade,
    required int eggsSold,
    required double pricePerEgg,
    String? saleDate,
  }) async {
    try {
      final body = {
        'batch_id': batchId,
        'grade': grade,
        'eggs_sold': eggsSold,
        'price_per_egg': pricePerEgg,
      };
      if (saleDate != null) body['sale_date'] = saleDate;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/eggs/sale'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      // Return error detail from backend
      try {
        final err = jsonDecode(response.body);
        return {'__error': err['detail'] ?? 'Failed to record sale'};
      } catch (_) {
        return {'__error': 'Failed to record sale (${response.statusCode})'};
      }
    } catch (e) {
      print('❌ createEggSaleWithResponse Error: $e');
      return {'__error': e.toString()};
    }
  }

  // Grade eggs using CV (with image upload)
  Future<Map<String, dynamic>?> gradeEggsWithImage({
    required int batchId,
    required File imageFile,
  }) async {
    try {
      final token = await SessionStore.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/cv/eggs/grade-with-base64'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['batch_id'] = batchId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      }
      return null;
    } catch (e) {
      print('❌ gradeEggsWithImage Error: $e');
      return null;
    }
  }

  // Create egg yield returning full response
  Future<Map<String, dynamic>?> createEggYieldWithResponse(int batchId, String grade, int produced) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/eggs/yield'),
        headers: await _headers(),
        body: jsonEncode({
          'batch_id': batchId,
          'grade': grade,
          'produced': produced,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ createEggYieldWithResponse Error: $e');
      return null;
    }
  }

  // Update egg yield returning full response
  Future<Map<String, dynamic>?> updateEggYieldWithResponse(int yieldId, int produced) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/eggs/yield/$yieldId'),
        headers: await _headers(),
        body: jsonEncode({
          'produced': produced,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ updateEggYieldWithResponse Error: $e');
      return null;
    }
  }

  // Get grading (CV scan) history for a batch — each entry has the
  // captured/annotated image + the A/B/C counts detected at that time.
  Future<List<dynamic>> getBatchGradingHistory(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/eggs/grading-images/batch/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getBatchGradingHistory Error: $e');
      return [];
    }
  }

  // Correct a past grading-image entry's A/B/C counts.
  Future<Map<String, dynamic>?> updateGradingImage(
      int gradingImageId, {
        required int gradeA,
        required int gradeB,
        required int gradeC,
      }) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/eggs/grading-images/$gradingImageId'),
        headers: await _headers(),
        body: jsonEncode({
          'grade_a': gradeA,
          'grade_b': gradeB,
          'grade_c': gradeC,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ updateGradingImage Error: $e');
      return null;
    }
  }

  // Get all egg crates for a batch
  Future<List<dynamic>> getCratesByBatch(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/eggs/crates/batch/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getCratesByBatch Error: $e');
      return [];
    }
  }

  // Get batch crates summary breakdown
  Future<Map<String, dynamic>?> getCrateSummary(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/eggs/crates/summary/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ getCrateSummary Error: $e');
      return null;
    }
  }
}