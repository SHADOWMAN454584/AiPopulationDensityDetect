# CrowdSense AI — Backend API Contract

This document is the single source of truth for the backend that the Flutter frontend expects.  
Build your backend in any language/framework (FastAPI recommended) and make it match these contracts exactly.

---

## App Overview

**CrowdSense AI** is a crowd density prediction and navigation app.

| Field | Value |
|---|---|
| App Name | CrowdSense AI |
| Tagline | "Predict Before You Step Out" |
| Default backend URL | `http://localhost:8000` |
| Production URL | Set via `--dart-define=API_BASE_URL=https://your-backend.com` |

### What the app does
- Shows real-time crowd density for 6 fixed locations on a map
- Predicts crowd density for next hour at each location
- Recommends the **best time** to travel between two locations (24-hour forecast)
- Suggests **smart route** alternatives when a location is too crowded
- Lets users set **crowd alerts** (notify when a location drops below a threshold)
- Has an **Admin Panel** with hourly + weekly charts per location
- Auto-refreshes crowd data every **30 seconds**

---

## Base URL

Configured in `lib/constants/app_constants.dart`:

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);
```

All endpoints below are relative to `apiBaseUrl`.

---

## Locations (Fixed — no API needed)

The 6 locations are hardcoded in the app. Your backend must use these exact `location_id` strings:

| location_id | Location Name | Latitude | Longitude | Type |
|---|---|---|---|---|
| `metro_a` | Metro Station A | 19.0760 | 72.8777 | metro |
| `metro_b` | Metro Station B | 19.0590 | 72.8360 | metro |
| `bus_stop_1` | Central Bus Stop | 19.0820 | 72.8810 | bus |
| `mall_1` | City Mall | 19.0650 | 72.8650 | mall |
| `park_1` | Green Park | 19.0700 | 72.8500 | park |
| `station_1` | Railway Station | 19.0728 | 72.8826 | railway |

---

## Endpoints

### 1. `GET /health`

Health check. Called on every refresh cycle to detect if backend is reachable.

**Request:** No body, no params.

**Response `200 OK`:**
```json
{ "status": "ok" }
```

---

### 2. `POST /predict`

Single-location crowd density prediction from the ML model.

**Request body (`application/json`):**
```json
{
  "location_id": "metro_a",
  "hour": 9,
  "day_of_week": 0,
  "is_weekend": 0,
  "is_holiday": 0
}
```

| Field | Type | Description |
|---|---|---|
| `location_id` | string | One of the 6 location IDs above |
| `hour` | int | 0–23 (current hour) |
| `day_of_week` | int | 0 = Monday … 6 = Sunday |
| `is_weekend` | int | 0 or 1 |
| `is_holiday` | int | 0 or 1 |

**Response `200 OK`:**
```json
{
  "location_id": "metro_a",
  "location_name": "Metro Station A",
  "predicted_density": 72.4,
  "status": "high",
  "hour": 9,
  "day_of_week": 0
}
```

| Field | Type | Description |
|---|---|---|
| `location_id` | string | Same as request |
| `location_name` | string | Human-readable name |
| `predicted_density` | float | 0.0 – 100.0 |
| `status` | string | `"low"` (<40), `"medium"` (40–69), `"high"` (≥70) |
| `hour` | int | Same as request |
| `day_of_week` | int | Same as request |

---

### 3. `POST /predict/bulk`

Bulk predictions for **all 6 locations** at once — called on every auto-refresh.

**Request body (`application/json`):**
```json
{
  "hour": 9,
  "day_of_week": 0
}
```

| Field | Type | Description |
|---|---|---|
| `hour` | int | 0–23 |
| `day_of_week` | int | 0 = Monday … 6 = Sunday |

**Response `200 OK`:**
```json
{
  "predictions": [
    {
      "location_id": "metro_a",
      "location_name": "Metro Station A",
      "predicted_density": 72.4,
      "status": "high"
    },
    {
      "location_id": "metro_b",
      "location_name": "Metro Station B",
      "predicted_density": 38.1,
      "status": "low"
    },
    {
      "location_id": "bus_stop_1",
      "location_name": "Central Bus Stop",
      "predicted_density": 55.0,
      "status": "medium"
    },
    {
      "location_id": "mall_1",
      "location_name": "City Mall",
      "predicted_density": 61.3,
      "status": "medium"
    },
    {
      "location_id": "park_1",
      "location_name": "Green Park",
      "predicted_density": 22.0,
      "status": "low"
    },
    {
      "location_id": "station_1",
      "location_name": "Railway Station",
      "predicted_density": 80.5,
      "status": "high"
    }
  ]
}
```

> **How the app uses this:**  
> - Called once for `hour = now.hour` → current crowd data for map + home screen  
> - Called again for `hour = (now.hour + 1) % 24` → `predicted_next_hour` values

---

### 4. `GET /best-time?from={location_id}&to={location_id}`

Returns a 24-hour crowd forecast for the origin location and the best hour to travel.

**Request query params:**

| Param | Type | Example |
|---|---|---|
| `from` | string | `metro_a` |
| `to` | string | `metro_b` |

**Example:** `GET /best-time?from=metro_a&to=metro_b`

**Response `200 OK`:**
```json
{
  "best_time": "06:00",
  "expected_density": 18.5,
  "status": "low",
  "all_predictions": [
    { "hour": 0,  "density": 12.3, "status": "low",    "label": "00:00" },
    { "hour": 1,  "density": 10.1, "status": "low",    "label": "01:00" },
    { "hour": 2,  "density": 9.4,  "status": "low",    "label": "02:00" },
    { "hour": 3,  "density": 8.7,  "status": "low",    "label": "03:00" },
    { "hour": 4,  "density": 11.2, "status": "low",    "label": "04:00" },
    { "hour": 5,  "density": 15.6, "status": "low",    "label": "05:00" },
    { "hour": 6,  "density": 18.5, "status": "low",    "label": "06:00" },
    { "hour": 7,  "density": 68.0, "status": "medium", "label": "07:00" },
    { "hour": 8,  "density": 85.2, "status": "high",   "label": "08:00" },
    ...24 entries total (hour 0 – 23)
  ]
}
```

| Field | Type | Description |
|---|---|---|
| `best_time` | string | `"HH:00"` format — hour with lowest density |
| `expected_density` | float | Density at the best hour (0–100) |
| `status` | string | `"low"` / `"medium"` / `"high"` |
| `all_predictions` | array | 24 entries, one per hour (see below) |

Each entry in `all_predictions`:

| Field | Type | Description |
|---|---|---|
| `hour` | int | 0–23 |
| `density` | float | 0–100 |
| `status` | string | `"low"` / `"medium"` / `"high"` |
| `label` | string | `"HH:00"` (e.g. `"09:00"`) |

---

## Crowd Density → Status Mapping

The app uses this rule everywhere (matches `CrowdData.getStatusFromDensity`):

| `predicted_density` | `status` |
|---|---|
| < 40 | `"low"` |
| 40 – 69.99 | `"medium"` |
| ≥ 70 | `"high"` |

---

## CrowdData Object (what the app stores internally)

This is the Flutter model the app populates from `/predict/bulk` responses:

```
locationId        → location_id        (string)
locationName      → location_name      (string)
latitude          → from app constants (not from API)
longitude         → from app constants (not from API)
crowdCount        → (predicted_density × 5).round()   [computed by app]
crowdDensity      → predicted_density  (float, 0–100)
status            → status             (string)
timestamp         → DateTime.now()     [set by app]
predictedNextHour → predicted_density from next-hour bulk call (float)
```

> Latitude/Longitude are NOT expected from the API — the app reads them from its hardcoded location table.

---

## Error Handling

If any endpoint returns a non-200 status code or throws a network error,  
the app **silently falls back to locally-generated dummy data** and sets  
`isApiConnected = false` in the app state. No error is shown to the user.

You do NOT need to implement custom error response bodies — the app ignores them.

---

## CORS

Your backend must allow cross-origin requests from any origin (needed for web builds):

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

---

## Summary of All Endpoints

| Method | Path | Used By | Called When |
|---|---|---|---|
| `GET` | `/health` | `ApiService.isApiAvailable()` | Every 30-second refresh |
| `POST` | `/predict` | `ApiService.getPrediction()` | Analytics screen per-location detail |
| `POST` | `/predict/bulk` | `ApiService.getBulkPredictions()` | Every 30-second refresh (×2: current + next hour) |
| `GET` | `/best-time` | `ApiService.getBestTravelTime()` | Best Time screen on "Find" button tap |
