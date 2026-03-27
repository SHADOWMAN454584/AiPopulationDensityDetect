# 🔌 Quick API Reference Card

Quick lookup for CrowdSense AI Backend endpoints.

---

## 📍 Base URL
```dart
http://localhost:8000              // Local
https://your-app.vercel.app        // Production
```

---

## 🚀 Quick Endpoints

### Health
```http
GET /health
```

### Locations
```http
GET /locations
```

### Predictions
```http
GET /predictions/bulk?hour=14
```

### Real-time
```http
GET  /realtime/status
POST /realtime/collect
GET  /realtime/cached
```

### Google Maps
```http
GET  /maps/nearby?latitude=23.81&longitude=90.41&radius=1000
POST /maps/directions
GET  /maps/place/{place_id}
GET  /maps/estimate-crowd/{location_id}?latitude=23.81&longitude=90.41
```

### AI (OpenAI)
```http
POST /ai/insights
POST /ai/route-advice
```

---

## 📊 Response Models

### CrowdData (Predictions Response)
```json
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
}
```

### Location
```json
{
  "id": "loc-central-station",
  "name": "Central Railway Station",
  "latitude": 23.8103,
  "longitude": 90.4125,
  "category": "transport",
  "tags": ["commuter", "transit"],
  "baselineDensityProfile": {"0": 18.0, "23": 30.0}
}
```

---

## 🎯 Flutter Quick Start

```dart
// 1. Check backend
final health = await http.get(Uri.parse('$baseUrl/health'));

// 2. Get predictions
final response = await http.get(
  Uri.parse('$baseUrl/predictions/bulk?hour=14')
);
final data = json.decode(response.body);
final crowdList = (data['data'] as List)
    .map((item) => CrowdData.fromJson(item))
    .toList();

// 3. Get AI insights
final insights = await http.post(
  Uri.parse('$baseUrl/ai/insights'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({'crowdData': crowdList.map((c) => c.toJson()).toList()}),
);
```

---

## ⚡ Status Codes

- `200` - Success
- `400` - Bad request
- `404` - Not found
- `500` - Server error

---

For detailed documentation, see [FRONTEND_INTEGRATION.md](./FRONTEND_INTEGRATION.md)
