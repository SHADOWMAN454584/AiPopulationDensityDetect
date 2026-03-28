import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Service for communicating with FastAPI crowd prediction backend.
class ApiService {
  static final String _baseUrl = AppConstants.apiBaseUrl;

  // ──────────────────────────────────────────────────────────
  // Health Check
  // ──────────────────────────────────────────────────────────

  /// Health check - checks if API is available
  static Future<bool> isApiAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('API health check failed: $e');
      return false;
    }
  }

  /// Get full health status including service configuration
  static Future<Map<String, dynamic>?> getHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Health API Error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Locations
  // ──────────────────────────────────────────────────────────

  /// Get all monitored locations with their baseline crowd profiles
  static Future<List<Map<String, dynamic>>?> getLocations() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/locations'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('Locations API Error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Predictions
  // ──────────────────────────────────────────────────────────

  /// Get bulk predictions for all locations at a specific hour
  static Future<Map<String, dynamic>?> getBulkPredictions({int? hour}) async {
    try {
      final uri = hour != null
          ? Uri.parse('$_baseUrl/predictions/bulk?hour=$hour')
          : Uri.parse('$_baseUrl/predictions/bulk');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Bulk Predictions API Error: $e');
    }
    return null;
  }

  /// Get crowd prediction from ML model (legacy endpoint)
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
      print('Prediction API Error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Real-time Data
  // ──────────────────────────────────────────────────────────

  /// Check if real-time Google Maps data collection is available
  static Future<Map<String, dynamic>?> getRealtimeStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/realtime/status'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Realtime status API Error: $e');
    }
    return null;
  }

  /// Trigger collection of live crowd data from Google Maps API
  static Future<Map<String, dynamic>?> collectRealtimeData() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/realtime/collect'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Realtime collect API Error: $e');
    }
    return null;
  }

  /// Get the most recently collected real-time data from cache
  static Future<Map<String, dynamic>?> getCachedRealtimeData() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/realtime/cached'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Realtime cached API Error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Google Maps Integration
  // ──────────────────────────────────────────────────────────

  /// Get nearby places from Google Maps API
  static Future<Map<String, dynamic>?> getNearbyPlaces({
    required double latitude,
    required double longitude,
    int radius = 1000,
    String? placeType,
  }) async {
    try {
      final params = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
        if (placeType != null) 'place_type': placeType,
      };

      final uri = Uri.parse(
        '$_baseUrl/maps/nearby',
      ).replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Nearby Places API Error: $e');
    }
    return null;
  }

  /// Get nearby smart-route payload for the Smart Route screen.
  ///
  /// The screen expects:
  /// - radius_km
  /// - nearby_locations
  /// - suggestions
  ///
  /// Some backends only expose /maps/nearby. In that case, this method
  /// adapts the payload shape so the UI can still render nearby data and
  /// gracefully fallback for suggestions.
  static Future<Map<String, dynamic>?> getNearbySmartRoute({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      final radiusMeters = (radiusKm * 1000).round();
      final nearbyResponse = await getNearbyPlaces(
        latitude: latitude,
        longitude: longitude,
        radius: radiusMeters,
      );

      if (nearbyResponse == null) {
        return null;
      }

      final nearbyLocations =
          _extractMapList(nearbyResponse['nearby_locations']).isNotEmpty
          ? _extractMapList(nearbyResponse['nearby_locations'])
          : _extractMapList(nearbyResponse['places']).isNotEmpty
          ? _extractMapList(nearbyResponse['places'])
          : _extractMapList(nearbyResponse['results']);

      final suggestions = _extractMapList(nearbyResponse['suggestions']);

      return {
        ...nearbyResponse,
        'radius_km': _toDoubleOrNull(nearbyResponse['radius_km']) ?? radiusKm,
        'nearby_locations': nearbyLocations,
        'suggestions': suggestions,
      };
    } catch (e) {
      print('Nearby Smart Route API Error: $e');
    }
    return null;
  }

  /// Get directions with traffic between origin and destination
  static Future<Map<String, dynamic>?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/maps/directions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'origin': {'lat': originLat, 'lng': originLng},
          'destination': {'lat': destLat, 'lng': destLng},
          'mode': mode,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Directions API Error: $e');
    }
    return null;
  }

  /// Get details for a specific place
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/maps/place/$placeId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Place Details API Error: $e');
    }
    return null;
  }

  /// Estimate crowd level based on Google Maps traffic and place popularity
  static Future<Map<String, dynamic>?> estimateCrowdFromMaps({
    required String locationId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/maps/estimate-crowd/$locationId')
          .replace(
            queryParameters: {
              'latitude': latitude.toString(),
              'longitude': longitude.toString(),
            },
          );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Estimate Crowd API Error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // AI Insights (Gemini-compatible)
  // ──────────────────────────────────────────────────────────

  /// Generate AI-powered insights about current crowd conditions
  static Future<Map<String, dynamic>?> getAiInsights({
    List<Map<String, dynamic>>? crowdData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai/insights'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({if (crowdData != null) 'crowdData': crowdData}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('AI Insights API Error: $e');
    }
    return null;
  }

  /// Get AI-powered route and timing recommendations
  static Future<Map<String, dynamic>?> getAiRouteAdvice({
    required List<Map<String, dynamic>> crowdData,
    String? origin,
    String? destination,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ai/route-advice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'crowdData': crowdData,
          if (origin != null) 'origin': origin,
          if (destination != null) 'destination': destination,
        }),
      );

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        final advice = (data['advice'] ?? data['summary'] ?? '').toString();
        if (advice.isNotEmpty) {
          data['advice'] = advice;
          data['summary'] = advice;
        }
        return data;
      }
    } catch (e) {
      print('AI Route Advice API Error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Place Search (Nominatim Geocoding)
  // ──────────────────────────────────────────────────────────

  /// Search for places worldwide using Nominatim OpenStreetMap geocoding.
  /// Returns a list of {display_name, name, lat, lng} maps.
  static Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? latitude,
    double? longitude,
    int limit = 6,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/maps/search').replace(
        queryParameters: {
          'q': query,
          'limit': limit.toString(),
          if (latitude != null) 'latitude': latitude.toString(),
          if (longitude != null) 'longitude': longitude.toString(),
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> results = decoded is List
            ? decoded
            : (decoded['results'] as List<dynamic>? ??
                  decoded['places'] as List<dynamic>? ??
                  decoded['data'] as List<dynamic>? ??
                  <dynamic>[]);

        return results.map((item) {
          return <String, dynamic>{
            'display_name': item['display_name'] ?? '',
            'name': item['name'] ?? item['display_name'] ?? '',
            'lat': _toDoubleOrNull(item['lat']) ?? 0.0,
            'lng':
                _toDoubleOrNull(item['lng']) ??
                _toDoubleOrNull(item['lon']) ??
                0.0,
            'type': item['type'] ?? '',
            'class': item['class'] ?? '',
          };
        }).toList();
      }
    } catch (e) {
      print('Backend maps search error: $e');
    }

    return _searchPlacesDirectNominatim(query, limit: limit);
  }

  static Future<List<Map<String, dynamic>>> _searchPlacesDirectNominatim(
    String query, {
    int limit = 6,
  }) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(
            queryParameters: {
              'q': query,
              'format': 'json',
              'limit': limit.toString(),
              'addressdetails': '1',
            },
          );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'CrowdSenseAI/1.0 (crowdsense.ai)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        return results.map((item) {
          return <String, dynamic>{
            'display_name': item['display_name'] ?? '',
            'name': item['name'] ?? item['display_name'] ?? '',
            'lat': _toDoubleOrNull(item['lat']) ?? 0.0,
            'lng':
                _toDoubleOrNull(item['lng']) ??
                _toDoubleOrNull(item['lon']) ??
                0.0,
            'type': item['type'] ?? '',
            'class': item['class'] ?? '',
          };
        }).toList();
      }
    } catch (e) {
      print('Nominatim search fallback error: $e');
    }
    return [];
  }

  /// Get crowd density estimation for arbitrary coordinates.
  /// Tries /maps/estimate-crowd/custom first, then falls back to /maps/nearby.
  static Future<Map<String, dynamic>?> getCrowdDensityForLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Try estimate-crowd with a generic location id
      final estimateResult = await estimateCrowdFromMaps(
        locationId: 'custom',
        latitude: latitude,
        longitude: longitude,
      );
      if (estimateResult != null) {
        return estimateResult;
      }
    } catch (_) {
      // Fall through to nearby
    }

    // Fallback: use /maps/nearby to find monitored places near these coords
    try {
      final nearbyResult = await getNearbyPlaces(
        latitude: latitude,
        longitude: longitude,
        radius: 2000, // 2km radius
      );
      if (nearbyResult != null) {
        return nearbyResult;
      }
    } catch (e) {
      print('Crowd density fallback error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Utility Methods
  // ──────────────────────────────────────────────────────────

  /// Get best travel time recommendation
  static Future<Map<String, dynamic>?> getBestTravelTime({
    required String fromLocationId,
    required String toLocationId,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/best-time',
      ).replace(queryParameters: {'from': fromLocationId, 'to': toLocationId});
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Best Time API Error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Real-time Training (Admin)
  // ──────────────────────────────────────────────────────────

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
        return jsonDecode(response.body);
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
      if (response.statusCode == 200) {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body));
        payload['status_code'] ??= response.statusCode;
        return payload;
      }
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
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        final training = data['training'];
        if (training is Map) {
          return Map<String, dynamic>.from(training);
        }
        return data;
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
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Realtime training-data API Error: $e');
    }
    return null;
  }

  static List<Map<String, dynamic>> _extractMapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
