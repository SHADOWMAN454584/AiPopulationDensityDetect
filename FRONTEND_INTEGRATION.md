# 🔌 CrowdSense AI - Frontend Integration Guide

Complete API reference for integrating the Flutter frontend with the FastAPI backend.

---

## 📍 Base URL Configuration

### Local Development
```dart
// lib/constants/app_constants.dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);
```

### Production (After Vercel Deployment)
```bash
# Run Flutter app with production URL
flutter run --dart-define=API_BASE_URL=https://your-backend.vercel.app
```

Or hardcode in `app_constants.dart`:
```dart
static const String apiBaseUrl = 'https://your-backend.vercel.app';
```

---

## 🚀 Quick Start Integration

### 1. Update API Service

```dart
// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.apiBaseUrl;

  static Future<bool> isApiAvailable() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // See detailed methods below...
}
```

### 2. Check Backend Health on App Start

```dart
// In your AppState or main.dart
Future<void> checkBackendConnection() async {
  final isAvailable = await ApiService.isApiAvailable();
  if (isAvailable) {
    print('✅ Backend connected');
  } else {
    print('❌ Backend unavailable - using offline mode');
  }
}
```

---

## 📡 API Endpoints Reference

### 🏥 Health & Status

#### `GET /health`

Check if backend is alive and which services are configured.

**Request:**
```dart
Future<Map<String, dynamic>> getHealth() async {
  final response = await http.get(Uri.parse('$baseUrl/health'));
  return json.decode(response.body);
}
```

**Response:**
```json
{
  "status": "ok",
  "service": "CrowdSense AI Backend",
  "openAiConfigured": true,
  "googleMapsConfigured": true,
  "mapProvider": "google_maps",
  "realtimeEnabled": true,
  "allowedOrigins": ["*"]
}
```

**Flutter Model:**
```dart
class HealthResponse {
  final String status;
  final String service;
  final bool openAiConfigured;
  final bool googleMapsConfigured;
  final String mapProvider;
  final bool realtimeEnabled;

  HealthResponse({
    required this.status,
    required this.service,
    required this.openAiConfigured,
    required this.googleMapsConfigured,
    required this.mapProvider,
    required this.realtimeEnabled,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'],
      service: json['service'],
      openAiConfigured: json['openAiConfigured'],
      googleMapsConfigured: json['googleMapsConfigured'],
      mapProvider: json['mapProvider'],
      realtimeEnabled: json['realtimeEnabled'],
    );
  }
}
```

---

### 📍 Locations

#### `GET /locations`

Get all monitored locations with their baseline crowd profiles.

**Request:**
```dart
Future<List<Map<String, dynamic>>> getLocations() async {
  final response = await http.get(Uri.parse('$baseUrl/locations'));

  if (response.statusCode == 200) {
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }
  throw Exception('Failed to load locations');
}
```

**Response:**
```json
[
  {
    "id": "loc-central-station",
    "name": "Central Railway Station",
    "latitude": 23.8103,
    "longitude": 90.4125,
    "category": "transport",
    "tags": ["commuter", "transit", "station"],
    "baselineDensityProfile": {
      "0": 18.0, "1": 18.0, ..., "23": 30.0
    }
  },
  {
    "id": "loc-gulshan-circle",
    "name": "Gulshan Circle",
    "latitude": 23.7925,
    "longitude": 90.4078,
    "category": "commercial",
    "tags": ["business", "shopping", "traffic"],
    "baselineDensityProfile": {...}
  }
  // ... more locations
]
```

**Flutter Model:**
```dart
class LocationModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final List<String> tags;
  final Map<int, double> baselineDensityProfile;

  LocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.tags,
    required this.baselineDensityProfile,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      category: json['category'],
      tags: List<String>.from(json['tags']),
      baselineDensityProfile: Map<int, double>.from(
        (json['baselineDensityProfile'] as Map).map(
          (k, v) => MapEntry(int.parse(k.toString()), v.toDouble()),
        ),
      ),
    );
  }
}
```

---

### 🔮 Predictions

#### `GET /predictions/bulk?hour={hour}`

Get crowd density predictions for all locations at a specific hour.

**Parameters:**
- `hour` (optional): Hour of day (0-23). If not provided, uses current hour.

**Request:**
```dart
Future<Map<String, dynamic>> getBulkPredictions({int? hour}) async {
  final uri = hour != null
      ? Uri.parse('$baseUrl/predictions/bulk?hour=$hour')
      : Uri.parse('$baseUrl/predictions/bulk');

  final response = await http.get(uri);

  if (response.statusCode == 200) {
    return json.decode(response.body);
  }
  throw Exception('Failed to load predictions');
}
```

**Response:**
```json
{
  "hour": 14,
  "data": [
    {
      "locationId": "loc-central-station",
      "locationName": "Central Railway Station",
      "latitude": 23.8103,
      "longitude": 90.4125,
      "crowdCount": 310,
      "crowdDensity": 62.0,
      "status": "high",
      "timestamp": "2026-03-27T14:30:00Z",
      "predictedNextHour": 68.5
    },
    {
      "locationId": "loc-gulshan-circle",
      "locationName": "Gulshan Circle",
      "latitude": 23.7925,
      "longitude": 90.4078,
      "crowdCount": 355,
      "crowdDensity": 71.0,
      "status": "high",
      "timestamp": "2026-03-27T14:30:00Z",
      "predictedNextHour": 58.2
    }
    // ... more predictions
  ]
}
```

**Your Existing CrowdData Model Works Perfectly:**
```dart
class CrowdData {
  final String locationId;
  final String locationName;
  final double latitude;
  final double longitude;
  final int crowdCount;
  final double crowdDensity;
  final String status;
  final DateTime timestamp;
  final double? predictedNextHour;

  // Your existing model matches the API response! ✅
}
```

**Integration Example:**
```dart
// In your AppState
Future<void> refreshCrowdData() async {
  try {
    // Get current hour predictions
    final currentHour = DateTime.now().hour;
    final response = await ApiService.getBulkPredictions(hour: currentHour);

    // Get next hour predictions
    final nextHour = (currentHour + 1) % 24;
    final nextResponse = await ApiService.getBulkPredictions(hour: nextHour);

    // Parse to your CrowdData model
    final crowdDataList = (response['data'] as List)
        .map((item) => CrowdData.fromJson(item))
        .toList();

    // Update state
    setState(() {
      this.crowdDataList = crowdDataList;
    });

    notifyListeners();
  } catch (e) {
    print('Error fetching predictions: $e');
  }
}
```

---

### 🔴 Real-time Data

#### `GET /realtime/status`

Check if real-time Google Maps data collection is available.

**Request:**
```dart
Future<Map<String, dynamic>> getRealtimeStatus() async {
  final response = await http.get(Uri.parse('$baseUrl/realtime/status'));
  return json.decode(response.body);
}
```

**Response:**
```json
{
  "enabled": true,
  "provider": "google_maps",
  "lastUpdated": "2026-03-27T14:25:00Z"
}
```

#### `POST /realtime/collect`

Trigger collection of live crowd data from Google Maps API.

**Request:**
```dart
Future<Map<String, dynamic>> collectRealtimeData() async {
  final response = await http.post(
    Uri.parse('$baseUrl/realtime/collect'),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  }
  throw Exception('Failed to collect realtime data');
}
```

**Response:**
```json
{
  "provider": "google_maps",
  "collectedAt": "2026-03-27T14:30:00Z",
  "data": [
    {
      "locationId": "loc-central-station",
      "locationName": "Central Railway Station",
      "latitude": 23.8103,
      "longitude": 90.4125,
      "crowdCount": 315,
      "crowdDensity": 63.0,
      "status": "high",
      "timestamp": "2026-03-27T14:30:00Z",
      "predictedNextHour": 68.0
    }
    // ... more real-time data
  ]
}
```

#### `GET /realtime/cached`

Get the most recently collected real-time data from cache (no API call made).

**Request:**
```dart
Future<Map<String, dynamic>> getCachedRealtimeData() async {
  final response = await http.get(Uri.parse('$baseUrl/realtime/cached'));
  return json.decode(response.body);
}
```

**Response:** Same format as `/realtime/collect`

**Integration Flow:**
```dart
// Your AppState.refreshCrowdData() implementation:
Future<void> refreshCrowdData() async {
  // 1. Get predictions
  final predictions = await ApiService.getBulkPredictions();

  // 2. Check if real-time is available
  final status = await ApiService.getRealtimeStatus();

  // 3. If Maps is enabled, try to get live data
  if (status['enabled'] == true) {
    try {
      final realtimeData = await ApiService.collectRealtimeData();
      // Use real-time data (more accurate)
      updateCrowdData(realtimeData['data']);
    } catch (e) {
      // Fallback to cached or predictions
      final cached = await ApiService.getCachedRealtimeData();
      if (cached['data'].isNotEmpty) {
        updateCrowdData(cached['data']);
      } else {
        updateCrowdData(predictions['data']);
      }
    }
  } else {
    // Use ML predictions only
    updateCrowdData(predictions['data']);
  }
}
```

---

### 🗺️ Google Maps Integration

#### `GET /maps/nearby`

Get nearby places from Google Maps API.

**Parameters:**
- `latitude` (required): Center latitude
- `longitude` (required): Center longitude
- `radius` (optional): Search radius in meters (100-50000, default: 1000)
- `place_type` (optional): Type of place (e.g., "restaurant", "park")

**Request:**
```dart
Future<Map<String, dynamic>> getNearbyPlaces({
  required double latitude,
  required double longitude,
  int radius = 1000,
  String? placeType,
}) async {
  final params = {
    'latitude': latitude.toString(),
    'longitude': longitude.toString(),
    'radius': radius.toString(),
    if (placeType != null) 'place_type': placeType,
  };

  final uri = Uri.parse('$baseUrl/maps/nearby').replace(queryParameters: params);
  final response = await http.get(uri);

  return json.decode(response.body);
}
```

**Response:**
```json
{
  "status": "success",
  "places": [
    {
      "placeId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
      "name": "Shopping Mall",
      "location": {
        "lat": 23.8105,
        "lng": 90.4127
      },
      "rating": 4.5,
      "userRatingsTotal": 2340,
      "types": ["shopping_mall", "point_of_interest"]
    }
    // ... more places
  ]
}
```

#### `POST /maps/directions`

Get directions with traffic between origin and destination.

**Request:**
```dart
Future<Map<String, dynamic>> getDirections({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  String mode = 'driving',
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/maps/directions'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'origin': {'lat': originLat, 'lng': originLng},
      'destination': {'lat': destLat, 'lng': destLng},
      'mode': mode, // driving, walking, bicycling, transit
    }),
  );

  return json.decode(response.body);
}
```

**Response:**
```json
{
  "status": "success",
  "routes": [
    {
      "summary": "Via Main Road",
      "distance": 5230,
      "duration": 720,
      "durationInTraffic": 1080,
      "polyline": "encoded_polyline_string..."
    },
    {
      "summary": "Via Highway",
      "distance": 6100,
      "duration": 660,
      "durationInTraffic": 840,
      "polyline": "encoded_polyline_string..."
    }
  ]
}
```

#### `GET /maps/place/{place_id}`

Get details for a specific place.

**Request:**
```dart
Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
  final response = await http.get(
    Uri.parse('$baseUrl/maps/place/$placeId'),
  );
  return json.decode(response.body);
}
```

#### `GET /maps/estimate-crowd/{location_id}`

Estimate crowd level based on Google Maps traffic and place popularity.

**Parameters:**
- `location_id` (path): Location identifier
- `latitude` (query): Location latitude
- `longitude` (query): Location longitude

**Request:**
```dart
Future<Map<String, dynamic>> estimateCrowdFromMaps({
  required String locationId,
  required double latitude,
  required double longitude,
}) async {
  final uri = Uri.parse('$baseUrl/maps/estimate-crowd/$locationId')
      .replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

  final response = await http.get(uri);
  return json.decode(response.body);
}
```

**Response:**
```json
{
  "locationId": "loc-central-station",
  "crowdEstimate": 64.5,
  "nearbyPlacesCount": 15,
  "source": "google_maps"
}
```

---

### 🤖 AI Insights (OpenAI)

#### `POST /ai/insights`

Generate AI-powered insights about current crowd conditions.

**Request:**
```dart
Future<Map<String, dynamic>> getAiInsights({
  List<Map<String, dynamic>>? crowdData,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/ai/insights'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      if (crowdData != null) 'crowdData': crowdData,
    }),
  );

  return json.decode(response.body);
}
```

**Response:**
```json
{
  "summary": "🚨 High crowd alert! Central Railway Station and Gulshan Circle are experiencing heavy crowds (62-71% density). Consider visiting Dhanmondi Lake Park (39% density) for a more relaxed experience. Best time to visit busy areas: after 8 PM when crowds typically reduce by 40%.",
  "dataPoints": 7
}
```

**Usage Example:**
```dart
// In your analytics or home screen
Future<void> loadAiInsights() async {
  final currentData = crowdDataList.map((c) => c.toJson()).toList();
  final insights = await ApiService.getAiInsights(crowdData: currentData);

  setState(() {
    aiGeneratedInsights = insights['summary'];
  });
}
```

#### `POST /ai/route-advice`

Get AI-powered route and timing recommendations.

**Request:**
```dart
Future<Map<String, dynamic>> getAiRouteAdvice({
  required List<Map<String, dynamic>> crowdData,
  String? origin,
  String? destination,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/ai/route-advice'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'crowdData': crowdData,
      if (origin != null) 'origin': origin,
      if (destination != null) 'destination': destination,
    }),
  );

  return json.decode(response.body);
}
```

**Response:**
```json
{
  "advice": "🛣️ Route from Central Railway Station to Gulshan Circle: Both locations are crowded right now. Recommended departure: 7:00 PM when density drops to ~45%. Alternative: Take Dhanmondi Lake route for scenic, less crowded journey. Estimated time savings: 15 minutes by avoiding peak hours.",
  "recommendedDepartureTime": "19:00",
  "alternativeRoutes": [
    "Via Dhanmondi Lake Park",
    "Via University Campus"
  ]
}
```

---

## 🔄 Complete Integration Example

### Complete ApiService Implementation

```dart
// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../models/crowd_data.dart';

class ApiService {
  static const String baseUrl = AppConstants.apiBaseUrl;

  // ──────────────────────────────────────────────────────────
  // Health Check
  // ──────────────────────────────────────────────────────────

  static Future<bool> isApiAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('API health check failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    return json.decode(response.body);
  }

  // ──────────────────────────────────────────────────────────
  // Locations
  // ──────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await http.get(Uri.parse('$baseUrl/locations'));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load locations');
  }

  // ──────────────────────────────────────────────────────────
  // Predictions
  // ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getBulkPredictions({int? hour}) async {
    final uri = hour != null
        ? Uri.parse('$baseUrl/predictions/bulk?hour=$hour')
        : Uri.parse('$baseUrl/predictions/bulk');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load predictions');
  }

  // ──────────────────────────────────────────────────────────
  // Real-time Data
  // ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRealtimeStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/realtime/status'));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> collectRealtimeData() async {
    final response = await http.post(
      Uri.parse('$baseUrl/realtime/collect'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to collect realtime data');
  }

  static Future<Map<String, dynamic>> getCachedRealtimeData() async {
    final response = await http.get(Uri.parse('$baseUrl/realtime/cached'));
    return json.decode(response.body);
  }

  // ──────────────────────────────────────────────────────────
  // Google Maps
  // ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    int radius = 1000,
    String? placeType,
  }) async {
    final params = {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'radius': radius.toString(),
      if (placeType != null) 'place_type': placeType,
    };

    final uri = Uri.parse('$baseUrl/maps/nearby')
        .replace(queryParameters: params);
    final response = await http.get(uri);

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/maps/directions'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'origin': {'lat': originLat, 'lng': originLng},
        'destination': {'lat': destLat, 'lng': destLng},
        'mode': mode,
      }),
    );

    return json.decode(response.body);
  }

  // ──────────────────────────────────────────────────────────
  // AI Insights
  // ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAiInsights({
    List<Map<String, dynamic>>? crowdData,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/insights'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        if (crowdData != null) 'crowdData': crowdData,
      }),
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> getAiRouteAdvice({
    required List<Map<String, dynamic>> crowdData,
    String? origin,
    String? destination,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/route-advice'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'crowdData': crowdData,
        if (origin != null) 'origin': origin,
        if (destination != null) 'destination': destination,
      }),
    );

    return json.decode(response.body);
  }
}
```

### AppState Integration

```dart
// lib/providers/app_state.dart
class AppState with ChangeNotifier {
  List<CrowdData> crowdDataList = [];
  bool isLoading = false;
  bool backendAvailable = false;
  String? aiInsights;

  // Called on app start
  Future<void> initialize() async {
    backendAvailable = await ApiService.isApiAvailable();
    if (backendAvailable) {
      await refreshCrowdData();
    } else {
      // Use dummy data service
      crowdDataList = DummyDataService.generateDummyData();
    }
    notifyListeners();
  }

  // Main data refresh method
  Future<void> refreshCrowdData() async {
    if (!backendAvailable) return;

    isLoading = true;
    notifyListeners();

    try {
      // 1. Get current hour predictions
      final currentHour = DateTime.now().hour;
      final predictions = await ApiService.getBulkPredictions(
        hour: currentHour,
      );

      // 2. Check real-time status
      final status = await ApiService.getRealtimeStatus();

      // 3. Try to get live data if available
      Map<String, dynamic> data;
      if (status['enabled'] == true) {
        try {
          final realtime = await ApiService.collectRealtimeData();
          data = realtime;
        } catch (e) {
          // Fallback to cached
          final cached = await ApiService.getCachedRealtimeData();
          data = cached['data'].isNotEmpty ? cached : predictions;
        }
      } else {
        data = predictions;
      }

      // 4. Parse to CrowdData models
      crowdDataList = (data['data'] as List)
          .map((item) => CrowdData.fromJson(item))
          .toList();

      // 5. Check alerts
      checkAlerts();

      // 6. Get AI insights
      loadAiInsights();

    } catch (e) {
      print('Error refreshing crowd data: $e');
      // Fallback to dummy data
      crowdDataList = DummyDataService.generateDummyData();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAiInsights() async {
    try {
      final crowdJson = crowdDataList.map((c) => c.toJson()).toList();
      final insights = await ApiService.getAiInsights(crowdData: crowdJson);
      aiInsights = insights['summary'];
      notifyListeners();
    } catch (e) {
      print('Error loading AI insights: $e');
    }
  }
}
```

---

## 🎯 Status Codes & Error Handling

### HTTP Status Codes

- **200 OK**: Request successful
- **400 Bad Request**: Invalid parameters
- **404 Not Found**: Endpoint not found
- **500 Internal Server Error**: Backend error

### Error Handling Template

```dart
Future<T> safeApiCall<T>(Future<T> Function() apiCall, T fallback) async {
  try {
    return await apiCall();
  } on http.ClientException catch (e) {
    print('Network error: $e');
    return fallback;
  } on FormatException catch (e) {
    print('JSON parsing error: $e');
    return fallback;
  } catch (e) {
    print('Unexpected error: $e');
    return fallback;
  }
}

// Usage:
final predictions = await safeApiCall(
  () => ApiService.getBulkPredictions(),
  {'hour': null, 'data': []},
);
```

---

## 🧪 Testing Your Integration

### 1. Test Health Endpoint

```dart
void testHealthEndpoint() async {
  final health = await ApiService.getHealth();
  print('Backend status: ${health['status']}');
  print('OpenAI configured: ${health['openAiConfigured']}');
  print('Google Maps configured: ${health['googleMapsConfigured']}');
}
```

### 2. Test Predictions

```dart
void testPredictions() async {
  final predictions = await ApiService.getBulkPredictions(hour: 14);
  print('Predictions for hour ${predictions['hour']}:');
  for (var item in predictions['data']) {
    print('${item['locationName']}: ${item['crowdDensity']}% density');
  }
}
```

### 3. Test AI Insights

```dart
void testAiInsights() async {
  final predictions = await ApiService.getBulkPredictions();
  final insights = await ApiService.getAiInsights(
    crowdData: predictions['data'],
  );
  print('AI Insights: ${insights['summary']}');
}
```

---

## 📊 Data Flow Diagram

```
┌─────────────────┐
│  Flutter App    │
│  (AppState)     │
└────────┬────────┘
         │
         │ 1. Check Health
         ├──────────────────► GET /health
         │
         │ 2. Get Locations
         ├──────────────────► GET /locations
         │
         │ 3. Get Predictions
         ├──────────────────► GET /predictions/bulk?hour=14
         │
         │ 4. Check Realtime
         ├──────────────────► GET /realtime/status
         │
         │ 5. Collect Live Data
         ├──────────────────► POST /realtime/collect
         │                     (uses Google Maps API)
         │
         │ 6. Get AI Insights
         ├──────────────────► POST /ai/insights
         │                     (uses OpenAI GPT)
         │
         │ 7. Get Directions
         └──────────────────► POST /maps/directions
                              (uses Google Maps API)
```

---

## 🚨 Important Notes

### 1. CORS is Enabled
The backend allows all origins (`*`), so no CORS issues.

### 2. No Authentication Required
Current version has no auth. All endpoints are public.

### 3. Rate Limits
- OpenAI: 500 requests/minute
- Google Maps: 1000 requests/day (free tier)

### 4. Timestamps
All timestamps are in ISO 8601 format (UTC):
```
"2026-03-27T14:30:00Z"
```

Parse in Flutter:
```dart
DateTime.parse(json['timestamp'])
```

### 5. Crowd Status Values
- `"low"`: density < 30%
- `"medium"`: density 30-60%
- `"high"`: density > 60%

---

## 📱 Recommended Update Interval

```dart
// In your AppState
Timer? _refreshTimer;

void startAutoRefresh() {
  _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
    refreshCrowdData();
  });
}

void stopAutoRefresh() {
  _refreshTimer?.cancel();
}
```

---

## 🔧 Environment Variables

Make sure your backend has these configured:

```bash
# backend/.env
OPENAI_API_KEY=sk-proj-xxxxx
GOOGLE_MAPS_API_KEY=AIzaxxxxx
ENABLE_REALTIME_MAPS=true
MAP_PROVIDER=google_maps
ALLOWED_ORIGINS=*
```

---

## 📞 Support & Debugging

### Enable Verbose Logging

```dart
class ApiService {
  static bool debugMode = true;

  static void _log(String message) {
    if (debugMode) {
      print('[API] $message');
    }
  }

  static Future<Map<String, dynamic>> getBulkPredictions({int? hour}) async {
    _log('Fetching predictions for hour: $hour');
    final response = await http.get(...);
    _log('Response: ${response.statusCode}');
    return json.decode(response.body);
  }
}
```

### Check Backend Logs

When running locally:
```bash
cd backend
./run.bat  # Watch console output
```

### Test with cURL

```bash
# Health
curl http://localhost:8000/health

# Predictions
curl http://localhost:8000/predictions/bulk?hour=14

# AI Insights
curl -X POST http://localhost:8000/ai/insights \
  -H "Content-Type: application/json" \
  -d '{"crowdData": []}'
```

---

## ✅ Integration Checklist

- [ ] Update `app_constants.dart` with correct `apiBaseUrl`
- [ ] Implement `ApiService` with all methods
- [ ] Test `/health` endpoint
- [ ] Test `/predictions/bulk` endpoint
- [ ] Integrate with `AppState.refreshCrowdData()`
- [ ] Handle errors gracefully with fallback to dummy data
- [ ] Test real-time data collection
- [ ] Test AI insights generation
- [ ] Test Google Maps directions
- [ ] Implement auto-refresh timer (30 seconds)
- [ ] Test with production URL after Vercel deployment

---

## 🎉 You're All Set!

Your Flutter app is now ready to connect to the CrowdSense AI backend. The API provides:

✅ **ML-powered crowd predictions**
✅ **Real-time Google Maps data**
✅ **AI-generated insights via OpenAI**
✅ **Location-based services**
✅ **Traffic and directions**

**Next Steps:**
1. Run backend: `cd backend && ./run.bat`
2. Test endpoints from Flutter
3. Deploy to Vercel when ready
4. Update Flutter app with production URL

**Questions?** Check [backend/README.md](../backend/README.md) for full documentation.

---

**Built with ❤️ for CrowdSense AI**
