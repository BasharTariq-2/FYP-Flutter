import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';

class BatchService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<List<dynamic>> getBatchesByFarm(int farmId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/batches/?farm_id=$farmId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getBatchesByFarm Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> getReadyToSellBatches(String selectedDate) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/batches/ready-to-sell?selected_date=$selectedDate'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getReadyToSellBatches Error: $e');
      return [];
    }
  }

  // ✅ ADD THIS METHOD
  Future<Map<String, dynamic>?> getBatchById(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/batches/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ getBatchById Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createBatch({
    required int shedId,
    required int henCount,
    required String batchType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/batches/'),
        headers: await _headers(),
        body: jsonEncode({
          'shed_id': shedId,
          'hen_count': henCount,
          'batch_type': batchType,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ createBatch Error: $e');
      return null;
    }
  }

  // ✅ ADD ISOLATE HENS METHOD
  Future<bool> isolateHens(int batchId, int hensCount, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/isolation/batch/$batchId'),
        headers: await _headers(),
        body: jsonEncode({
          'hens_count': hensCount,
          'reason': reason,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ isolateHens Error: $e');
      return false;
    }
  }

  // ✅ ADD CULL HENS METHOD
  Future<bool> cullHens(int batchId, int hensCount, String reason, {String source = 'active'}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/culling/batch/$batchId'),
        headers: await _headers(),
        body: jsonEncode({
          'hens_count': hensCount,
          'reason': reason,
          'source': source,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ cullHens Error: $e');
      return false;
    }
  }

  // ✅ ADD SELL HENS METHOD (partial sale)
  Future<bool> sellHens(int batchId, int hensSold, double pricePerHen) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/hen-sales/batch/$batchId'),
        headers: await _headers(),
        body: jsonEncode({
          'hens_sold': hensSold,
          'price_per_hen': pricePerHen,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ sellHens Error: $e');
      return false;
    }
  }

  // ✅ NEW: check whether a batch is ready to sell for the selected date
  // POST /hen-sales/batch/{batch_id}/ready-to-sell?selected_date=YYYY-MM-DD
  Future<Map<String, dynamic>?> checkReadyToSell(int batchId, String selectedDate) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/hen-sales/batch/$batchId/ready-to-sell')
          .replace(queryParameters: {'selected_date': selectedDate});
      final response = await http.post(uri, headers: await _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ checkReadyToSell Error: $e');
      return null;
    }
  }

  // ✅ NEW: sell the entire remaining batch at once
  // POST /hen-sales/batch/{batch_id}/sell-all
  Future<bool> sellAllHens({
    required int batchId,
    required int hensSold,
    required double pricePerHen,
    required String saleDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/hen-sales/batch/$batchId/sell-all'),
        headers: await _headers(),
        body: jsonEncode({
          'hens_sold': hensSold,
          'price_per_hen': pricePerHen,
          'sale_date': saleDate,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ sellAllHens Error: $e');
      return false;
    }
  }

  Future<bool> updateBatch(int batchId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/batches/$batchId'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ updateBatch Error: $e');
      return false;
    }
  }
}