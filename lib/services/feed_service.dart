import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/session_store.dart';

class FeedService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get feed stock for a farm
  Future<List<dynamic>> getStock(int farmId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/feed/stock/farm/$farmId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getStock Error: $e');
      return [];
    }
  }

  // Get feed usage for a batch
  Future<List<dynamic>> getUsage(int batchId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/feed/usage/batch/$batchId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getUsage Error: $e');
      return [];
    }
  }

  // Get feed purchases for a farm
  Future<List<dynamic>> getPurchases(int farmId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/feed/purchase/farm/$farmId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print('❌ getPurchases Error: $e');
      return [];
    }
  }

  // Record feed usage
  Future<bool> recordUsage(int batchId, int feedTypeId, double quantityUsedKg) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/feed/usage/batch/$batchId'),
        headers: await _headers(),
        body: jsonEncode({
          'feed_type_id': feedTypeId,
          'quantity_used_kg': quantityUsedKg,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ recordUsage Error: $e');
      return false;
    }
  }

  // Create feed purchase
  Future<bool> createPurchase(int farmId, int feedTypeId, double quantityKg, double pricePerKg, {String? supplier}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/feed/purchase/farm/$farmId'),
        headers: await _headers(),
        body: jsonEncode({
          'feed_type_id': feedTypeId,
          'quantity_kg': quantityKg,
          'price_per_kg': pricePerKg,
          if (supplier != null) 'supplier': supplier,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ createPurchase Error: $e');
      return false;
    }
  }
}