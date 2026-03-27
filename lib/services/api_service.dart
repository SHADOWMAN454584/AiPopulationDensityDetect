import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Service for communicating with FastAPI crowd prediction backend.
class ApiService {
  static final String _baseUrl = AppConstants.apiBaseUrl;

  static Map<String, dynamic>? _decodeResponse(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

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

  /// Realtime status check
  static Future<Map<String, dynamic>?> getRealtimeStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/realtime/status'));
      if (response.statusCode == 200) {
        return _decodeResponse(response);
      }
    } catch (e) {
      print('Realtime status API Error: $e');
    }
    return null;
  }

  /// Collect realtime maps signals
  static Future<Map<String, dynamic>?> collectRealtimeData() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/realtime/collect'));
      if (response.statusCode == 200) {
        return _decodeResponse(response);
      }
    } catch (e) {
      print('Realtime collect API Error: $e');
    }
    return null;
  }

  /// Read cached realtime data as fallback
  static Future<Map<String, dynamic>?> getCachedRealtimeData() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/realtime/cached'));
      if (response.statusCode == 200) {
        return _decodeResponse(response);
      }
    } catch (e) {
      print('Realtime cached API Error: $e');
    }
    return null;
  }

  /// Realtime-aware single location prediction
  static Future<Map<String, dynamic>?> getRealtimePrediction({
    required String locationId,
    int? hour,
  }) async {
    try {
      final query = <String, String>{'location_id': locationId};
      if (hour != null) {
        query['hour'] = hour.toString();
      }
      final uri = Uri.parse(
        '$_baseUrl/realtime/predict',
      ).replace(queryParameters: query);
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        return _decodeResponse(response);
      }
    } catch (e) {
      print('Realtime predict API Error: $e');
    }
    return null;
  }

  /// Trigger realtime model training from Maps data
  static Future<Map<String, dynamic>?> startRealtimeTraining({
    required int hoursToSample,
    required bool blendWithOriginal,
    required double weightMaps,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/realtime/train'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hours_to_sample': hoursToSample,
          'blend_with_original': blendWithOriginal,
          'weight_maps': weightMaps,
        }),
      );
      final payload = _decodeResponse(response) ?? <String, dynamic>{};
      payload['status_code'] = response.statusCode;
      return payload;
    } catch (e) {
      print('Realtime train API Error: $e');
    }
    return null;
  }

  /// Realtime training progress status
  static Future<Map<String, dynamic>?> getRealtimeTrainingStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/realtime/train/status'),
      );
      if (response.statusCode == 200) {
        return _decodeResponse(response);
      }
    } catch (e) {
      print('Realtime train status API Error: $e');
    }
    return null;
  }

  /// Optional training dataset diagnostics
  static Future<Map<String, dynamic>?> getRealtimeTrainingData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/realtime/training-data'),
      );
      if (response.statusCode == 200) {
        return _decodeResponse(response);
      }
    } catch (e) {
      print('Realtime training-data API Error: $e');
    }
    return null;
  }
}
