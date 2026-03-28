# Frontend Integration Changes Guide
## CrowdSense AI — Connecting Flutter App to the New Gemini Backend

> **Scope:** Every change required in the Flutter frontend so it talks correctly to the new `main.py` backend.  
> All endpoint paths, response keys, and behaviours described here match the backend exactly as shipped.

---

## 1. Base URL Configuration

### Change required — `lib/constants/app_constants.dart`

The default base URL must point to your deployed backend.

```dart
// BEFORE
static const String apiBaseUrl = 'https://crowd-backend-2-ndfu.vercel.app/';

// AFTER — replace with your actual Render / Vercel deployment URL
static const String apiBaseUrl = 'https://YOUR-NEW-BACKEND.onrender.com/';
```

To override at build time without touching source:

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-NEW-BACKEND.onrender.com
flutter build apk --dart-define=API_BASE_URL=https://YOUR-NEW-BACKEND.onrender.com
```

---

## 2. Health Check — `ApiService.getHealth()`

### What changed

The `/health` response now includes a `geminiConfigured` flag in addition to the existing flags.  
`openAiConfigured` is still present (set to `true`) for backward compatibility — **no code change needed** for that flag.

### Optional enhancement — `lib/services/api_service.dart`

```dart
// Existing check — still works, no change required
final googleMapsConfigured = data['googleMapsConfigured'] as bool? ?? false;
final openAiConfigured     = data['openAiConfigured']     as bool? ?? false;

// NEW — read Gemini flag if you want to show it in UI
final geminiConfigured = data['geminiConfigured'] as bool? ?? false;
```

---

## 3. AI Insights — `ApiService.getAiInsights()`

### What changed

- The backend now uses **Gemini** instead of OpenAI.  
- The response shape is **identical**: `{ "summary": "...", "success": true }`.  
- **No code change required** in the API call itself.

### Verify your parser reads `summary`

```dart
// lib/services/api_service.dart — confirm this line exists
final summary = data['summary'] as String? ?? '';
```

---

## 4. AI Route Advice — `ApiService.getAiRouteAdvice()`

### What changed

The response now returns **both** `advice` and `summary` keys with the same content.  
If your code currently reads `advice`, it keeps working.  
If it reads `summary`, it also keeps working.

```dart
// Either key is safe to read
final advice = data['advice'] as String?
            ?? data['summary'] as String?
            ?? '';
```

---

## 5. Realtime Predict — `ApiService.getRealtimePrediction()`

### What changed

`POST /realtime/predict` now takes **query parameters**, not a JSON body.

```dart
// BEFORE — if sending a JSON body
final response = await http.post(
  Uri.parse('$apiBaseUrl/realtime/predict'),
  body: jsonEncode({'location_id': locationId, 'hour': hour}),
);

// AFTER — send as query params
final uri = Uri.parse('$apiBaseUrl/realtime/predict').replace(
  queryParameters: {
    'location_id': locationId,
    if (hour != null) 'hour': hour.toString(),
  },
);
final response = await http.post(uri);
```

---

## 6. Best Time — `ApiService.getBestTravelTime()`

### What changed

The query parameter for origin is `from` (which is a Dart reserved word — needs encoding).

```dart
// lib/services/api_service.dart
Future<Map<String, dynamic>?> getBestTravelTime(String from, String to) async {
  final uri = Uri.parse('$apiBaseUrl/best-time').replace(
    queryParameters: {'from': from, 'to': to},  // 'from' sent as string key, fine in Uri
  );
  final response = await http.get(uri);
  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  return null;
}
```

### Response keys to read — `lib/screens/best_time_screen.dart`

The backend returns both `best_time` (string e.g. `"09:00"`) and `best_hour` (int).  
Read whichever your UI prefers:

```dart
final raw      = jsonDecode(response.body);
final bestTime = raw['best_time']  as String? ?? '';   // "09:00" — display-ready
final bestHour = raw['best_hour']  as int?    ?? 0;    // 9       — for chart indexing

final expectedDensity  = raw['expected_density']   as double? ?? 0.0;
final status           = raw['status']             as String? ?? '';
final hourlyPredictions = raw['hourly_predictions'] as List?  ?? [];
```

---

## 7. CrowdData Model — Dual-Key Parsing

### What changed

The backend now returns **both** camelCase and snake_case for every crowd field.  
Your existing camelCase parser already works.  
If you ever switch to snake_case parsing, those keys are available too.

Confirm `lib/models/crowd_data.dart` reads at least one of each pair:

```dart
factory CrowdData.fromJson(Map<String, dynamic> json) {
  return CrowdData(
    locationId:        json['locationId']   ?? json['location_id']   ?? '',
    locationName:      json['locationName'] ?? json['location_name'] ?? '',
    latitude:          (json['latitude']    as num).toDouble(),
    longitude:         (json['longitude']   as num).toDouble(),
    crowdCount:        json['crowdCount']   ?? json['crowd_count']   ?? 0,
    crowdDensity:      (json['crowdDensity'] ?? json['crowd_density'] ?? 0.0) as double,
    status:            json['status']       ?? 'low',
    timestamp:         DateTime.parse(json['timestamp']),
    predictedNextHour: json['predictedNextHour'] ?? json['predicted_next_hour'],
  );
}
```

---

## 8. Maps Directions — `ApiService.getDirections()`

### No change required — but verify body shape

The backend expects exactly this JSON body:

```dart
// lib/services/api_service.dart — confirm this is your current implementation
final body = jsonEncode({
  'origin':      {'lat': origin.latitude,      'lng': origin.longitude},
  'destination': {'lat': destination.latitude, 'lng': destination.longitude},
  'mode':        mode,   // 'driving' | 'walking' | 'transit' | 'bicycling'
});
```

---

## 9. Realtime Training — Admin Panel

### What changed

`POST /realtime/train` returns a custom `status_code` field (not the HTTP status).  
The HTTP status is always `200`. Your AdminPanel must read `status_code` from the body.

```dart
// lib/screens/admin_panel.dart
Future<void> _startTraining() async {
  final result = await ApiService.startRealtimeTraining(...);

  // status_code is inside the response body, not HTTP status
  final statusCode = result?['status_code'] as int? ?? 500;

  switch (statusCode) {
    case 200:
      _showMessage('Training started successfully');
      break;
    case 409:
      _showMessage('Training is already running');
      break;
    case 503:
      _showMessage('Google Maps not configured — training unavailable');
      break;
    default:
      _showMessage('Unexpected error');
  }
}
```

### Training status polling — `GET /realtime/train/status`

The status object is nested under a `training` key:

```dart
// lib/services/api_service.dart
Future<Map<String, dynamic>?> getRealtimeTrainingStatus() async {
  final response = await http.get(Uri.parse('$apiBaseUrl/realtime/train/status'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['training'] as Map<String, dynamic>?;   // ← unwrap 'training' key
  }
  return null;
}
```

Then in `AdminPanel`:

```dart
final status    = trainingStatus?['status']        as String? ?? 'idle';
final lastError = trainingStatus?['last_error']    as String?;
final rowsUsed  = trainingStatus?['last_rows_used'] as int?   ?? 0;
```

---

## 10. Nearby Smart Route — `ApiService.getNearbySmartRoute()`

### What changed

`GET /maps/nearby` now returns three keys for the same list: `nearby_locations`, `places`, and `results`.  
The existing smart-route adapter that reads any of these three will work without changes.  
Also returns `radius_km` (float) — use it to display the search radius in the UI.

```dart
// Already handled if your adapter does:
final raw = jsonDecode(response.body);
final places = raw['nearby_locations']
            ?? raw['places']
            ?? raw['results']
            ?? [];
final radiusKm = raw['radius_km'] as double? ?? 0.0;
```

---

## 11. Error Handling — Null Safety Across All Endpoints

All endpoints return `null` from `ApiService` on non-200 responses.  
Add null-safe fallbacks everywhere the data is consumed:

```dart
// Pattern to apply consistently in AppState and screens
final predictions = await ApiService.getBulkPredictions(hour: currentHour);
if (predictions == null) {
  // Keep showing previous data, do not crash
  return;
}
final data = predictions['data'] as List? ?? [];
```

---

## 12. Environment Variables for Deployment

Set these on your hosting platform (Render / Vercel / Railway etc.):

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | ✅ Yes | Google Gemini API key |
| `GOOGLE_MAPS_API_KEY` | Optional | Enables live maps + realtime training |
| `PORT` | Auto-set | Hosting platform sets this automatically |

In Flutter, set the backend URL at build time:

```bash
# Development
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# Staging
flutter build apk --dart-define=API_BASE_URL=https://staging.yourapp.onrender.com

# Production
flutter build apk --dart-define=API_BASE_URL=https://yourapp.onrender.com
```

---

## 13. Quick Validation Checklist

Run through this after deploying the new backend:

- [ ] `GET /health` returns `200` with `geminiConfigured: true`
- [ ] `GET /locations` returns array of 7 location objects
- [ ] `GET /predictions/bulk` returns `{ data: [...] }` with dual-key crowd items
- [ ] `POST /ai/insights` returns `{ summary: "..." }` — content is Gemini-generated
- [ ] `POST /ai/route-advice` returns `{ advice: "...", summary: "..." }`
- [ ] `POST /realtime/predict?location_id=loc-central-station` returns `predicted_density`
- [ ] `GET /best-time?from=loc-central-station&to=loc-airport` returns `best_time` string
- [ ] `POST /realtime/train` returns body with `status_code` field (not HTTP status)
- [ ] Flutter `ApiService.isApiAvailable()` returns `true` (5-second timeout test)
- [ ] Auto-refresh timer (30s) successfully polls `/predictions/bulk` and `/realtime/collect`

---

## 14. Summary of Breaking Changes

| # | Area | Breaking? | Action needed |
|---|---|---|---|
| 1 | Base URL | ✅ Yes | Update `apiBaseUrl` in `AppConstants` |
| 2 | `/realtime/predict` | ✅ Yes | Switch from JSON body → query params |
| 3 | `/realtime/train/status` | ✅ Yes | Unwrap `training` key from response |
| 4 | `/realtime/train` body | ⚠️ Soft | Read `status_code` from body, not HTTP |
| 5 | AI provider | ✅ Changed | No code change — same response shape |
| 6 | `/best-time` response | ⚠️ Soft | Read `best_time` string OR `best_hour` int |
| 7 | CrowdData dual keys | ✅ Additive | Confirm fallback parsing in `fromJson` |
| 8 | `/maps/nearby` keys | ✅ Additive | Adapter already handles all three keys |

---

*Generated for CrowdSense AI — Backend v2.0.0 (Gemini)*
