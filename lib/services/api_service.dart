import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Service for communicating with FastAPI crowd prediction backend.
class ApiService {
  static final String _baseUrl = AppConstants.apiBaseUrl;

  /// Get crowd prediction from ML model
  static Future<Map<String, dynamic>?> getPrediction({
    required String locationId,
    required int hour,
    required int dayOfWeek,
    required bool isWeekend,
    required bool isHoliday,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'location_id': locationId,
          'hour': hour,
          'day_of_week': dayOfWeek,
          'is_weekend': isWeekend ? 1 : 0,
          'is_holiday': isHoliday ? 1 : 0,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Falls back to dummy data if API unavailable
      print('API Error: $e');
    }
    return null;
  }

  /// Get bulk predictions for all locations
  static Future<List<Map<String, dynamic>>?> getBulkPredictions({
    required int hour,
    required int dayOfWeek,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict/bulk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'hour': hour, 'day_of_week': dayOfWeek}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['predictions']);
      }
    } catch (e) {
      print('Bulk API Error: $e');
    }
    return null;
  }

  /// Get best travel time recommendation
  static Future<Map<String, dynamic>?> getBestTravelTime({
    required String fromLocationId,
    required String toLocationId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/best-time?from=$fromLocationId&to=$toLocationId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Best Time API Error: $e');
    }
    return null;
  }

  /// Health check
  static Future<bool> isApiAvailable() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
