# Map Page Search Backend Integration

This document explains the backend contract for the Map page search flow and how to connect it to the Flutter frontend.

## 1. Current Frontend Flow (Map Page)

The Map page search flow currently works in three steps:

1. User types in the search field on the map page.
2. Frontend fetches place suggestions.
3. When a place is selected, frontend fetches crowd data for that coordinate.

Relevant frontend methods:

- `MapScreen._performSearch(query)` calls `ApiService.searchPlaces(query)`.
- `MapScreen._onPlaceSelected(place)` calls `ApiService.getCrowdDensityForLocation(latitude, longitude)`.
- `ApiService.getCrowdDensityForLocation(...)`:
  - first tries `GET /maps/estimate-crowd/custom?latitude=...&longitude=...`
  - then falls back to `GET /maps/nearby?latitude=...&longitude=...&radius=2000`

## 2. Backend Endpoints Required For Map Search

## Endpoint A: Search Places

- Method: `GET`
- Path: `/maps/search`
- Purpose: Return place suggestions for user text input.

Query parameters:

- `q` (string, required): user search text
- `limit` (int, optional, default `6`): max suggestions
- `latitude` (float, optional): optional bias location
- `longitude` (float, optional): optional bias location

Recommended success response (`200`):

```json
[
  {
    "display_name": "Connaught Place, New Delhi, India",
    "name": "Connaught Place",
    "lat": 28.6315,
    "lng": 77.2167,
    "type": "commercial",
    "class": "place"
  }
]
```

Validation errors:

- `400` when `q` is missing or empty
- `422` when coordinates are invalid

Notes:

- Return `[]` with `200` when no matches are found.
- Normalize `lat` and `lng` as numbers, not strings.

## Endpoint B: Estimate Crowd For Custom Coordinates

- Method: `GET`
- Path: `/maps/estimate-crowd/{locationId}`
- Frontend usage for map search: `locationId = custom`
- Example call:
  - `/maps/estimate-crowd/custom?latitude=28.6315&longitude=77.2167`

Query parameters:

- `latitude` (float, required)
- `longitude` (float, required)

Recommended response (`200`):

```json
{
  "location_id": "custom",
  "crowd_density": 61.2,
  "status": "medium",
  "timestamp": "2026-03-29T09:10:00Z",
  "source": "maps"
}
```

## Endpoint C: Nearby Fallback

- Method: `GET`
- Path: `/maps/nearby`
- Purpose: Fallback response when custom estimate is unavailable.

Query parameters:

- `latitude` (float, required)
- `longitude` (float, required)
- `radius` (int, optional, default `2000`)
- `place_type` (string, optional)

Recommended response (`200`):

```json
{
  "radius_km": 2.0,
  "nearby_locations": [
    {
      "id": "metro_a",
      "name": "Metro Station A",
      "lat": 28.6321,
      "lng": 77.2182,
      "crowd_density": 74.3,
      "status": "high"
    }
  ]
}
```

Frontend compatibility:

- Frontend accepts any one of these keys for the place list:
  - `nearby_locations`
  - `places`
  - `results`

## 3. Frontend Connection Instructions

## Step 1: Point frontend to backend base URL

`AppConstants.apiBaseUrl` already reads from `API_BASE_URL`.

Run with:

```bash
flutter run --dart-define=API_BASE_URL=https://your-backend-domain
```

## Step 2: Make search suggestions come from backend endpoint

Update `ApiService.searchPlaces` to call backend `/maps/search`.

Recommended implementation:

```dart
static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
  final q = query.trim();
  if (q.isEmpty) return [];

  try {
    final uri = Uri.parse('$_baseUrl/maps/search').replace(
      queryParameters: {
        'q': q,
        'limit': '6',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List<dynamic> results = jsonDecode(response.body);
      return results.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return {
          'display_name': map['display_name'] ?? '',
          'name': map['name'] ?? map['display_name'] ?? '',
          'lat': (map['lat'] as num?)?.toDouble() ?? 0.0,
          'lng': (map['lng'] as num?)?.toDouble() ?? 0.0,
          'type': map['type'] ?? '',
          'class': map['class'] ?? '',
        };
      }).toList();
    }
  } catch (_) {
    // Optional: keep current Nominatim fallback here.
  }

  return [];
}
```

## Step 3: Keep crowd lookup flow unchanged

No map page UI change is required for crowd fetch after selecting a place.
It already does:

1. `getCrowdDensityForLocation(latitude, longitude)`
2. internal fallback from `/maps/estimate-crowd/custom` to `/maps/nearby`

## Step 4: Ensure CORS and headers are allowed

If frontend is web, backend must allow:

- `Origin` from app domain
- Methods: `GET`, `POST`, `OPTIONS`
- Headers: `Content-Type`, `Authorization` (if used)

## 4. Endpoint Test Commands

Search endpoint test:

```bash
curl "https://your-backend-domain/maps/search?q=airport&limit=6"
```

Custom crowd estimate test:

```bash
curl "https://your-backend-domain/maps/estimate-crowd/custom?latitude=28.6315&longitude=77.2167"
```

Nearby fallback test:

```bash
curl "https://your-backend-domain/maps/nearby?latitude=28.6315&longitude=77.2167&radius=2000"
```

## 5. Quick Verification Checklist

- [ ] Typing in map search shows suggestions from `/maps/search`
- [ ] Tapping a suggestion moves map to selected coordinates
- [ ] Crowd card shows data from `/maps/estimate-crowd/custom`
- [ ] If estimate fails, data appears via `/maps/nearby`
- [ ] No UI crash on empty search results
- [ ] Backend returns numeric `lat` and `lng`
