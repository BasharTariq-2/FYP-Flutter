import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../core/api_client.dart';
import '../core/debug_logger.dart';
import '../core/session_store.dart';

class ApiRepository {
  // ---------------- AUTH ----------------

  Future<void> login(String username, String password) async {
    final result = await ApiClient.post('auth/login', {
      'username': username,
      'password': password,
    });

    final token = result['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Token missing in login response');
    }

    await SessionStore.saveToken(token);

    final user = await ApiClient.get('users/me');
    if (user is Map<String, dynamic>) {
      await SessionStore.saveUser(user);
    }
  }

  Future<void> registerOwner(String username, String email, String password) async {
    await ApiClient.post('auth/register/owner', {
      'username': username,
      'email': email,
      'password': password,
    });

    await login(username, password);
  }

  Future<void> registerManager(
      String username,
      String email,
      String password,
      String ownerEmail,
      ) async {
    await ApiClient.post('auth/register/manager', {
      'username': username,
      'email': email,
      'password': password,
      'owner_email': ownerEmail,
    });

    await login(username, password);
  }

  Future<void> logout() async {
    await SessionStore.clear();
  }

  Future<Map<String, dynamic>?> me() async {
    final result = await ApiClient.get('users/me');
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  // ---------------- FARM ----------------

  Future<List<dynamic>> farms() async {
    final result = await ApiClient.get('farms/');
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> createFarm({
    required String farmName,
    required String location,
    int noOfSheds = 0,
  }) async {
    final result = await ApiClient.post('farms/', {
      'farm_name': farmName,
      'farm_img_url': null,
      'location': location,
      'no_of_sheds': noOfSheds,
    });

    return Map<String, dynamic>.from(result);
  }

  // ---------------- SHEDS ----------------

  Future<List<dynamic>> sheds({int? farmId}) async {
    final path = farmId != null ? 'farms/$farmId/sheds' : 'sheds/';
    final result = await ApiClient.get(path);
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> createShed({
    required int farmId,
    required String shedName,
    required int hensCapacity,
  }) async {
    final result = await ApiClient.post('sheds/', {
      'farm_id': farmId,
      'shed_name': shedName,
      'hens_capacity': hensCapacity,
    });

    return Map<String, dynamic>.from(result);
  }

  // ---------------- BATCH ----------------

  Future<List<dynamic>> batches({String? batchType}) async {
    final suffix =
    batchType == null ? '' : '?batch_type=${Uri.encodeQueryComponent(batchType)}';
    final result = await ApiClient.get('batches/$suffix');
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> createBatch({
    required int shedId,
    required int henCount,
    required String batchType,
  }) async {
    final result = await ApiClient.post('batches/', {
      'shed_id': shedId,
      'hen_count': henCount,
      'batch_type': batchType,
    });

    return Map<String, dynamic>.from(result);
  }

  // ---------------- EGG YIELD ----------------

  Future<void> createEggYield({
    required int batchId,
    required String grade,
    required int produced,
  }) async {
    await ApiClient.post('eggs/yield', {
      'batch_id': batchId,
      'grade': grade,
      'egg_date': null,
      'produced': produced,
    });
  }

  /// PATCH /eggs/yield/{yieldId} — update produced count for an existing record.
  Future<void> updateEggYield({
    required int yieldId,
    required int produced,
  }) async {
    await ApiClient.patch('eggs/yield/$yieldId', {
      'produced': produced,
    });
  }

  Future<List<dynamic>> eggYields(int batchId) async {
    final result = await ApiClient.get('eggs/yield/batch/$batchId');
    return result is List ? result : [];
  }

  Future<void> createEggSale({
    required int batchId,
    required String grade,
    required int eggsSold,
    required double pricePerEgg,
  }) async {
    await ApiClient.post('eggs/sale', {
      'batch_id': batchId,
      'grade': grade,
      'eggs_sold': eggsSold,
      'price_per_egg': pricePerEgg,
      'sale_date': null,
    });
  }

  Future<List<dynamic>> eggSales(int batchId) async {
    final result = await ApiClient.get('eggs/sale/batch/$batchId');
    return result is List ? result : [];
  }

  Future<Uint8List> gradeEggImageWithBoxes({
    required int batchId,
    required File image,
  }) async {
    final result = await ApiClient.multipartImageRaw(
      path: 'cv/eggs/grade-with-image',
      fieldName: 'file',
      filePath: image.path,
      fields: {
        'batch_id': batchId.toString(),
      },
    );

    return result; // ✅ backend returns IMAGE bytes
  }

  // ---------------- HEALTH ----------------

  Future<Map<String, dynamic>> healthInit(int batchId) async {
    final result = await ApiClient.get('health/batch/$batchId/monitor-init');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> assessHealth({
    required int batchId,
    required double weightGrams,
    required double temperatureC,
  }) async {
    final result = await ApiClient.post('health/assess-batch/$batchId', {
      'weight_grams': weightGrams,
      'temperature_c': temperatureC,
    });

    return Map<String, dynamic>.from(result);
  }

  // ---------------- VACCINATION ----------------

  Future<List<dynamic>> vaccinationUpcoming() async {
    final result = await ApiClient.get('vaccinations/upcoming');

    print(result);

    return result is List ? result : [];
  }

  Future<List<dynamic>> vaccinationOverdue() async {
    final result = await ApiClient.get('vaccinations/overdue');

    if (result is List) return result;

    if (result is Map && result['data'] is List) {
      return result['data'];
    }

    return [];
  }

  Future<List<dynamic>> vaccinationSchedule(int batchId) async {
    final result =
    await ApiClient.get('vaccinations/batch/$batchId/schedule');

    if (result is List) return result;

    if (result is Map && result['data'] is List) {
      return result['data'];
    }

    return [];
  }

  Future<List<dynamic>> vaccinationRecords(int batchId) async {
    final result =
    await ApiClient.get('vaccinations/batch/$batchId/records');

    if (result is List) return result;

    if (result is Map && result['data'] is List) {
      return result['data'];
    }

    return [];
  }
  Future<void> recordVaccination({
    required int scheduleId,
    required int hensVaccinated,
    String? batchNumber,
    String? notes,
  }) async {
    await ApiClient.post('vaccinations/record/$scheduleId', {
      'hens_vaccinated': hensVaccinated,
      'administered_date': null,
      'batch_number': batchNumber,
      'expiry_date': null,
      'notes': notes,
    });
  }// ================= FEED USAGE =================
  Future<void> recordFeedUsage({
    required int batchId,
    required int feedTypeId,
    required double quantityUsedKg,
  }) async {
    await ApiClient.post('feed/usage/batch/$batchId', {
      'feed_type_id': feedTypeId,
      'quantity_used_kg': quantityUsedKg,
    });
  }

// ================= FEED PURCHASE =================
  Future<void> createFeedPurchase({
    required int farmId,
    required int feedTypeId,
    required double quantityKg,
    required double pricePerKg,
    String? supplier,
  }) async {
    await ApiClient.post('feed/purchase/farm/$farmId', {
      'feed_type_id': feedTypeId,
      'quantity_kg': quantityKg,
      'price_per_kg': pricePerKg,
      if (supplier != null) 'supplier': supplier,
    });
  }
  Future<void> isolateBatch({
    required int batchId,
    required int hensCount,
    required String reason,
  }) async {
    await ApiClient.post('isolation/batch/$batchId', {
      'hens_count': hensCount,
      'reason': reason,
    });
  }

  Future<void> cullBatch({
    required int batchId,
    required int hensCount,
    required String reason,
    String source = 'active',
  }) async {
    await ApiClient.post('culling/batch/$batchId', {
      'hens_count': hensCount,
      'reason': reason,
      'source': source,
    });
  }

  Future<void> sellHens({
    required int batchId,
    required int hensSold,
    required double pricePerHen,
  }) async {
    await ApiClient.post('hen-sales/batch/$batchId', {
      'hens_sold': hensSold,
      'price_per_hen': pricePerHen,
    });
  }

  Future<Map<String, dynamic>?> checkReadyToSell(int batchId, String selectedDate) async {
    final result = await ApiClient.post('hen-sales/batch/$batchId/ready-to-sell?selected_date=$selectedDate', {});
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  Future<List<dynamic>> readyToSellBatches(String selectedDate) async {
    final result = await ApiClient.get('batches/ready-to-sell?selected_date=$selectedDate');
    return result is List ? result : [];
  }

  Future<void> sellAllHens({
    required int batchId,
    required int hensSold,
    required double pricePerHen,
    required String saleDate,
  }) async {
    await ApiClient.post('hen-sales/batch/$batchId/sell-all', {
      'hens_sold': hensSold,
      'price_per_hen': pricePerHen,
      'sale_date': saleDate,
    });
  }
  Future<List<dynamic>> isolationHistory(int batchId) async {
    final result = await ApiClient.get('isolation/batch/$batchId');

    if (result is List) return result;
    if (result is Map && result['data'] is List) return result['data'];
    if (result is Map && result['results'] is List) return result['results'];

    return [];
  }

  Future<List<dynamic>> cullingHistory(int batchId) async {
    final result = await ApiClient.get('culling/batch/$batchId/history');

    if (result is List) return result;
    if (result is Map && result['data'] is List) return result['data'];
    if (result is Map && result['results'] is List) return result['results'];

    return [];
  }

  Future<List<dynamic>> henSales(int batchId) async {
    final result = await ApiClient.get('hen-sales/batch/$batchId');

    if (result is List) return result;
    if (result is Map && result['data'] is List) return result['data'];
    if (result is Map && result['results'] is List) return result['results'];

    return [];
  }
  Future<List<dynamic>> feedStock(int farmId) async {
    final result =
    await ApiClient.get(
      'feed/stock/farm/$farmId',
    );

    debugPrint(
      "FEED STOCK API RESULT: $result",
    );

    if (result is List) {
      return result;
    }

    if (result is Map<String, dynamic>) {
      if (result['data'] is List) {
        return result['data'];
      }

      if (result['results'] is List) {
        return result['results'];
      }

      if (result['stock'] is List) {
        return result['stock'];
      }
    }

    return [];
  }
  /// POST /cv/eggs/grade-with-base64 — grades eggs and returns
  /// { success, batch_id, results: {A,B,C}, image: base64, yields: [...] }
  Future<Map<String, dynamic>> gradeEggBase64({
    required int batchId,
    required String imagePath,
  }) async {
    final result = await ApiClient.multipartImage(
      path: 'cv/eggs/grade-with-base64',
      fieldName: 'file',
      filePath: imagePath,
      fields: {
        'batch_id': batchId.toString(),
      },
    );

    return Map<String, dynamic>.from(result);
  }
}