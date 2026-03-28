# Backend Endpoints Reference

Complete reference of backend endpoints used (or prepared) by the Flutter app.

Generated from:
- `lib/services/api_service.dart`
- `lib/providers/app_state.dart`
- `lib/screens/*`
- `ARCHITECTURE.md`

---

## 1) Base URL and Client Rules

- Base URL source: `AppConstants.apiBaseUrl`
- Default value: `https://YOUR-NEW-BACKEND.onrender.com/`
- Override at build time with: `--dart-define=API_BASE_URL=<your-backend-url>`

Example:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

Common client behavior in `ApiService`:
- Most methods return parsed JSON only when HTTP status is `200`.
- For non-200 responses, methods return `null`.
- Most requests send `Content-Type: application/json` for `POST`.
- `isApiAvailable()` uses a 5-second timeout.

---

## 2) Endpoint Inventory (GET/POST)

| HTTP | Endpoint | ApiService Method | Primary Frontend Consumers | Typical Trigger |
|---|---|---|---|---|
| GET | `/health` | `isApiAvailable()`, `getHealth()` | `AppState.initialize()`, `AppState.refreshCrowdData()` | App start + refresh checks |
| GET | `/locations` | `getLocations()` | `AppState.initialize()` | App start |
| GET | `/predictions/bulk` | `getBulkPredictions(hour?)` | `AppState.refreshCrowdData()` | Every 30s refresh |
| POST | `/predict` | `getPrediction(...)` | `AnalyticsScreen._fetchHourlyFromApi()` (fallback) | Analytics hourly view |
| GET | `/realtime/status` | `getRealtimeStatus()` | `AppState._tryRealtimeOverlay()` | During refresh |
| POST | `/realtime/collect` | `collectRealtimeData()` | `AppState._tryRealtimeOverlay()` | During refresh (if realtime enabled) |
| GET | `/realtime/cached` | `getCachedRealtimeData()` | `AppState._tryRealtimeOverlay()` fallback | When live collect fails |
| GET | `/maps/nearby` | `getNearbyPlaces(...)` | `AppState.getNearbyPlaces()`, `getNearbySmartRoute(...)` | On demand |
| POST | `/maps/directions` | `getDirections(...)` | `AppState.getDirections()` | On demand |
| GET | `/maps/place/{placeId}` | `getPlaceDetails(placeId)` | Not currently used by UI | On demand |
| GET | `/maps/estimate-crowd/{locationId}` | `estimateCrowdFromMaps(...)` | Not currently used by UI | On demand |
| POST | `/ai/insights` | `getAiInsights(crowdData?)` | `AppState._loadAiInsightsAsync()`, `AppState.loadAiInsights()` | On demand / after refresh |
| POST | `/ai/route-advice` | `getAiRouteAdvice(...)` | `AppState.getAiRouteAdvice()` | On demand |
| GET | `/best-time` | `getBestTravelTime(...)` | `BestTimeScreen._findBestTime()` | User action |
| POST | `/realtime/predict` | `getRealtimePrediction(...)` | `AnalyticsScreen._fetchHourlyFromApi()` | Analytics hourly loop |
| POST | `/realtime/train` | `startRealtimeTraining(...)` | `AdminPanel._startTraining()` | Admin action |
| GET | `/realtime/train/status` | `getRealtimeTrainingStatus()` | `AdminPanel._loadTrainingStatus()` | Admin page load + poll |
| GET | `/realtime/training-data` | `getRealtimeTrainingData()` | `AdminPanel._loadTrainingData()` | Admin page load |

---

## 3) Detailed Endpoint Specs

## A. Health and Configuration

### GET /health

Purpose:
- Check backend availability and service configuration flags.

Used by:
- `ApiService.isApiAvailable()` -> returns `bool`
- `ApiService.getHealth()` -> returns JSON map

Expected response fields used by app:
- `googleMapsConfigured` (bool)
- `openAiConfigured` (bool)

Called from:
- `AppState.initialize()`
- `AppState.refreshCrowdData()`

---

## B. Locations and Prediction

### GET /locations

Purpose:
- Fetch monitored locations metadata.

Used by:
- `ApiService.getLocations()`

Expected response shape:
- JSON array of location objects.

Called from:
- `AppState.initialize()`

### GET /predictions/bulk

Query params:
- `hour` (optional int, 0-23)

Purpose:
- Fetch prediction dataset for all monitored locations.

Used by:
- `ApiService.getBulkPredictions(hour?)`

Expected response fields used by app:
- `data`: array

Each `data` item is parsed into `CrowdData` with keys:
- `locationId` or `location_id`
- `locationName` or `location_name`
- `latitude`
- `longitude`
- `crowdCount` or `crowd_count`
- `crowdDensity` or `crowd_density`
- `status`
- `timestamp`
- `predictedNextHour` or `predicted_next_hour` (optional)

Called from:
- `AppState.refreshCrowdData()`

### POST /predict (legacy)

Body JSON:
```json
{
  "location_id": "metro_a",
  "hour": 14,
  "day_of_week": 5,
  "is_weekend": 1,
  "is_holiday": 0
}
```

Purpose:
- Legacy single-location prediction fallback.

Used by:
- `ApiService.getPrediction(...)`

Expected response fields used by analytics:
- `predicted_density`
- `status`

Called from:
- `AnalyticsScreen._fetchHourlyFromApi()` (only if `/realtime/predict` returns null)

---

## C. Realtime Crowd Pipeline

### GET /realtime/status

Purpose:
- Check realtime pipeline availability and provider type.

Used by:
- `ApiService.getRealtimeStatus()`

Expected response fields used by app:
- `enabled` (bool)
- `provider` (expects `google_maps` when configured)

Called from:
- `AppState._tryRealtimeOverlay()`

### POST /realtime/collect

Purpose:
- Trigger collection of fresh realtime data.

Used by:
- `ApiService.collectRealtimeData()`

Expected response fields used by app:
- `data`: array in prediction-compatible format.

Called from:
- `AppState._tryRealtimeOverlay()`

### GET /realtime/cached

Purpose:
- Return last cached realtime data as fallback.

Used by:
- `ApiService.getCachedRealtimeData()`

Expected response fields used by app:
- `data`: array in prediction-compatible format.

Called from:
- `AppState._tryRealtimeOverlay()` when `/realtime/collect` fails

### POST /realtime/predict

Query params:
- `location_id` (required)
- `hour` (optional)

Purpose:
- Single-location realtime-aware prediction.

Used by:
- `ApiService.getRealtimePrediction(...)`

Expected response fields used by analytics:
- `predicted_density`
- `status`

Called from:
- `AnalyticsScreen._fetchHourlyFromApi()` in a 24-hour loop

---

## D. Maps Endpoints

### GET /maps/nearby

Query params:
- `latitude` (required)
- `longitude` (required)
- `radius` (required, meters)
- `place_type` (optional)

Purpose:
- Fetch nearby places from map provider.

Used by:
- `ApiService.getNearbyPlaces(...)`

Expected response:
- Service accepts whatever backend returns.
- Smart route adapter can read any of:
  - `nearby_locations`
  - `places`
  - `results`

Called from:
- `AppState.getNearbyPlaces()`
- `ApiService.getNearbySmartRoute(...)` internal fetch

### POST /maps/directions

Body JSON:
```json
{
  "origin": { "lat": 23.81, "lng": 90.41 },
  "destination": { "lat": 23.79, "lng": 90.40 },
  "mode": "driving"
}
```

Purpose:
- Fetch route options and traffic-aware directions.

Used by:
- `ApiService.getDirections(...)`

Called from:
- `AppState.getDirections()`

### GET /maps/place/{placeId}

Path params:
- `placeId` (required)

Purpose:
- Fetch details for a specific place.

Used by:
- `ApiService.getPlaceDetails(placeId)`

Called from:
- No current UI caller.

### GET /maps/estimate-crowd/{locationId}

Path params:
- `locationId` (required)

Query params:
- `latitude` (required)
- `longitude` (required)

Purpose:
- Estimate crowd level using map signals.

Used by:
- `ApiService.estimateCrowdFromMaps(...)`

Called from:
- No current UI caller.

---

## E. AI Endpoints

### POST /ai/insights

Body JSON:
```json
{
  "crowdData": [
    {
      "location_id": "metro_a",
      "crowd_density": 62.0
    }
  ]
}
```

Notes:
- `crowdData` is optional in API client.

Purpose:
- Generate textual AI summary for crowd situation.

Used by:
- `ApiService.getAiInsights(...)`

Expected response fields used by app:
- `summary` (string)

Called from:
- `AppState._loadAiInsightsAsync()`
- `AppState.loadAiInsights()`

### POST /ai/route-advice

Body JSON:
```json
{
  "crowdData": [ ... ],
  "origin": "optional",
  "destination": "optional"
}
```

Purpose:
- Generate AI route/timing advice.

Used by:
- `ApiService.getAiRouteAdvice(...)`

Called from:
- `AppState.getAiRouteAdvice()`

---

## F. Best Time Endpoint

### GET /best-time

Query params:
- `from` (required location id)
- `to` (required location id)

Purpose:
- Suggest best travel time between two locations.

Used by:
- `ApiService.getBestTravelTime(...)`

Expected response fields used by app:
- `best_time` (or fallback from `best_hour`)
- `expected_density`
- `status`
- `hourly_predictions`

Called from:
- `BestTimeScreen._findBestTime()`

---

## G. Realtime Training (Admin)

### POST /realtime/train

Body JSON:
```json
{
  "hours_to_sample": 12,
  "blend_with_original": true,
  "weight_maps": 0.6
}
```

Purpose:
- Trigger retraining of realtime model from map data.

Used by:
- `ApiService.startRealtimeTraining(...)`

Special handling in client:
- Always returns a map (even for non-200) with extra key: `status_code`.
- Admin UI handles:
  - `200`: started
  - `409`: already running
  - `503`: maps not configured

Called from:
- `AdminPanel._startTraining()`

### GET /realtime/train/status

Purpose:
- Track training progress/status.

Used by:
- `ApiService.getRealtimeTrainingStatus()`

Expected response fields used by app:
- `training.status`
- `training.last_error`
- `training.last_rows_used`

Called from:
- `AdminPanel._loadTrainingStatus()`
- Polled every 7 seconds while running

### GET /realtime/training-data

Purpose:
- Return diagnostic/training dataset information.

Used by:
- `ApiService.getRealtimeTrainingData()`

Called from:
- `AdminPanel._loadTrainingData()`

---

## 4) Frontend Adapter (Not a Backend Route)

### ApiService.getNearbySmartRoute(...)

Important:
- This is a frontend adapter method, not a direct backend endpoint.
- It calls `GET /maps/nearby` and normalizes the response to:
  - `radius_km`
  - `nearby_locations`
  - `suggestions`

Called from:
- `SmartRouteScreen._loadNearbySmartRoute()`

---

## 5) Request Frequency Summary

- App start:
  - `/health`
  - `/locations`
  - `/predictions/bulk`
- Auto refresh (every 30 seconds while logged in):
  - `/health` check via `isApiAvailable()`
  - `/predictions/bulk`
  - `/realtime/status`
  - `/realtime/collect` (or `/realtime/cached` fallback)
- On demand:
  - `/ai/insights`
  - `/ai/route-advice`
  - `/maps/directions`
  - `/maps/nearby`
  - `/best-time`
  - `/realtime/predict`
- Admin only:
  - `/realtime/train`
  - `/realtime/train/status`
  - `/realtime/training-data`

---

## 6) Endpoints Present But Not Yet Used by UI

- `GET /maps/place/{placeId}`
- `GET /maps/estimate-crowd/{locationId}`

These are implemented in `ApiService` and ready for integration.

---

## 7) Quick Validation Checklist

- Confirm backend base URL is correct (`API_BASE_URL` or default URL).
- Verify all required routes exist on backend with exact method/path.
- Verify response keys used by app are present:
  - `data` for prediction/realtime bulk data
  - `summary` for AI insights
  - `training` object for training status
  - `best_time` or `best_hour` for best-time screen
- Ensure backend supports both legacy and new keys where needed (`snake_case` and `camelCase` for crowd items).
