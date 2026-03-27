# 🏗️ CrowdSense AI - System Architecture

Visual guide to how the Flutter frontend connects to the FastAPI backend.

---

## 📐 System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER FRONTEND                           │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Home Screen  │  │ Map Screen   │  │Analytics     │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│                   ┌────────▼─────────┐                          │
│                   │   AppState       │                          │
│                   │  (Provider)      │                          │
│                   └────────┬─────────┘                          │
│                            │                                    │
│                   ┌────────▼─────────┐                          │
│                   │   ApiService     │                          │
│                   └────────┬─────────┘                          │
└────────────────────────────┼──────────────────────────────────┘
                             │ HTTP/HTTPS
                             │
┌────────────────────────────▼──────────────────────────────────┐
│                     FASTAPI BACKEND                            │
│                   http://localhost:8000                        │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  /health     │  │ /predictions │  │ /realtime    │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ /locations   │  │   /maps      │  │    /ai       │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│                                                                │
│  ┌────────────────────────────────────────────────────┐       │
│  │           ML Prediction Service                    │       │
│  │  (scikit-learn, Random Forest)                     │       │
│  └────────────────────────────────────────────────────┘       │
│                                                                │
└────────────────────────┬───────────────┬──────────────────────┘
                         │               │
              ┌──────────▼─────┐  ┌──────▼──────────┐
              │ Google Maps API │  │  OpenAI GPT API │
              │                 │  │                 │
              │ • Places        │  │ • Insights      │
              │ • Directions    │  │ • Route Advice  │
              │ • Traffic       │  │                 │
              └─────────────────┘  └─────────────────┘
```

---

## 🔄 Data Flow - App Startup

```
1. App Launch
   │
   ├─► Check Backend Health
   │   GET /health
   │   └─► Returns: service status, API availability
   │
   ├─► Load Locations
   │   GET /locations
   │   └─► Returns: 7 monitored locations with coordinates
   │
   ├─► Get Current Predictions
   │   GET /predictions/bulk?hour={current_hour}
   │   └─► Returns: ML predictions for all locations
   │
   ├─► Check Realtime Status
   │   GET /realtime/status
   │   └─► Returns: Google Maps API availability
   │
   └─► If Google Maps Available:
       │
       ├─► Collect Live Data
       │   POST /realtime/collect
       │   └─► Fetches traffic, place popularity
       │
       └─► Fallback to Cached
           GET /realtime/cached
           └─► Returns last collected data
```

---

## 🔄 Data Flow - User Interaction

### Scenario 1: User Views Home Screen

```
User Opens Home
    │
    ├─► AppState.refreshCrowdData()
    │   │
    │   ├─► GET /predictions/bulk?hour=14
    │   │   └─► CrowdData[] with predictions
    │   │
    │   ├─► POST /realtime/collect
    │   │   └─► Live crowd estimates from Google Maps
    │   │
    │   └─► POST /ai/insights
    │       └─► "🚨 High crowd alert at Station A..."
    │
    └─► Display:
        • Crowd levels for each location
        • Status indicators (low/medium/high)
        • AI-generated insights
        • Alerts for favorites
```

### Scenario 2: User Checks Best Time to Visit

```
User Selects Location
    │
    ├─► GET /predictions/bulk (for each hour 0-23)
    │   └─► Returns predictions for all 24 hours
    │
    ├─► POST /ai/insights
    │   └─► "Best time: 10 AM (low crowd)"
    │
    └─► Display:
        • Line chart showing density by hour
        • Recommended visit times
        • Peak hours highlighted
```

### Scenario 3: User Plans Route

```
User Enters Origin & Destination
    │
    ├─► POST /maps/directions
    │   {
    │     "origin": {"lat": 23.81, "lng": 90.41},
    │     "destination": {"lat": 23.79, "lng": 90.40}
    │   }
    │   └─► Multiple routes with traffic data
    │
    ├─► POST /ai/route-advice
    │   └─► "Take Route 2 to avoid crowds"
    │
    └─► Display:
        • Route options with ETA
        • Traffic conditions
        • AI recommendations
        • Crowd levels along route
```

---

## 🗂️ Backend Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FastAPI Application                  │
│                         main.py                         │
└────────────┬────────────────────────────────────────────┘
             │
    ┌────────┴────────┬────────────┬─────────────┐
    │                 │            │             │
┌───▼────┐   ┌────────▼─────┐  ┌──▼──────┐  ┌──▼─────┐
│ Routes │   │   Services   │  │ Models  │  │  Data  │
└────────┘   └──────────────┘  └─────────┘  └────────┘

Routes:                Services:               Models:
├── health.py         ├── prediction_service  ├── crowd.py
├── locations.py      ├── google_maps_service ├── alert.py
├── predictions.py    ├── openai_service      └── user.py
├── realtime.py       ├── realtime_service
├── maps.py           └── cache_service       Data:
└── ai.py                                     └── locations.py
```

---

## 📊 Data Models Mapping

### Backend → Frontend

```python
# Backend (Python)
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

```dart
// Frontend (Dart)
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
}
```

**✅ Perfect 1:1 mapping - no conversion needed!**

---

## 🔐 API Integration Points

### 1. Initialization (App Start)

```dart
class AppState {
  Future<void> initialize() async {
    // 1. Check backend
    backendAvailable = await ApiService.isApiAvailable();

    if (backendAvailable) {
      // 2. Load locations
      locations = await ApiService.getLocations();

      // 3. Get initial data
      await refreshCrowdData();
    } else {
      // Fallback to dummy data
      useDummyData();
    }
  }
}
```

### 2. Data Refresh (Every 30 seconds)

```dart
Timer.periodic(Duration(seconds: 30), (timer) async {
  // 1. Get predictions
  final predictions = await ApiService.getBulkPredictions();

  // 2. Get real-time (if available)
  final realtime = await ApiService.collectRealtimeData();

  // 3. Merge data (prefer real-time over predictions)
  crowdDataList = mergeData(predictions, realtime);

  // 4. Check alerts
  checkAlerts();

  // 5. Update UI
  notifyListeners();
});
```

### 3. AI Features (On Demand)

```dart
// When user taps "Get Insights"
final insights = await ApiService.getAiInsights(
  crowdData: crowdDataList.map((c) => c.toJson()).toList(),
);

// When user plans route
final advice = await ApiService.getAiRouteAdvice(
  crowdData: crowdDataList.map((c) => c.toJson()).toList(),
  origin: selectedOrigin,
  destination: selectedDestination,
);
```

---

## 🌐 Deployment Flow

### Local Development

```
┌──────────────┐         ┌──────────────┐
│ Flutter App  │ ◄─────► │ Backend      │
│ localhost    │  HTTP   │ localhost    │
│ (any port)   │         │ :8000        │
└──────────────┘         └──────────────┘
```

### Production

```
┌──────────────┐         ┌──────────────┐
│ Flutter App  │ ◄─────► │ Backend      │
│ (Mobile/Web) │ HTTPS   │ Vercel       │
│              │         │ *.vercel.app │
└──────────────┘         └──────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
              ┌─────▼─────┐      ┌──────▼──────┐
              │ Google    │      │  OpenAI     │
              │ Maps API  │      │  API        │
              └───────────┘      └─────────────┘
```

---

## 🔄 State Management Flow

```
┌─────────────────────────────────────────────────────┐
│                   User Action                       │
└────────────────────┬────────────────────────────────┘
                     │
          ┌──────────▼──────────┐
          │   UI Widget         │
          │  (StatefulWidget)   │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │   AppState          │
          │  (ChangeNotifier)   │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │   ApiService        │
          │  (HTTP calls)       │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Backend API        │
          │  (FastAPI)          │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Response Data      │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Parse to Model     │
          │  (CrowdData)        │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  Update State       │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  notifyListeners()  │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │   UI Rebuilds       │
          └─────────────────────┘
```

---

## 🚦 Error Handling Strategy

```dart
┌─────────────────┐
│  API Call       │
└────────┬────────┘
         │
    ┌────▼─────┐
    │ Success? │
    └────┬─────┘
         │
    ┌────▼─────────────────┐
    │ NO               YES │
    │                      │
    ▼                      ▼
┌───────────────┐  ┌──────────────┐
│ Check Error   │  │ Parse Data   │
│ Type          │  │ Update State │
└───┬───────────┘  └──────────────┘
    │
    ├─► Network Error
    │   └─► Use Cached Data
    │
    ├─► Timeout
    │   └─► Retry Once
    │
    ├─► 500 Error
    │   └─► Use Dummy Data
    │
    └─► Other
        └─► Log & Continue
```

---

## 📈 Performance Optimization

### Backend Caching

```
Request → Cache Check → Cache Hit? → Return Cached Data
                ↓
              Cache Miss
                ↓
        Call External API
                ↓
          Update Cache
                ↓
         Return Fresh Data
```

### Frontend Optimization

```dart
// 1. Debounce rapid refreshes
void debouncedRefresh() {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(seconds: 2), () {
    refreshCrowdData();
  });
}

// 2. Cache API responses
final cachedData = await _cache.get('predictions');
if (cachedData != null && !isExpired(cachedData)) {
  return cachedData;
}

// 3. Lazy load AI insights
// Only fetch when user opens analytics screen
```

---

## 🎯 Key Integration Points Summary

| Feature | Endpoint | Update Frequency |
|---------|----------|------------------|
| Health Check | `GET /health` | On app start, every 5 min |
| Locations | `GET /locations` | Once on app start |
| Predictions | `GET /predictions/bulk` | Every 30 seconds |
| Real-time Data | `POST /realtime/collect` | Every 30 seconds |
| AI Insights | `POST /ai/insights` | On demand |
| Maps Directions | `POST /maps/directions` | On demand |

---

## ✅ Integration Checklist

- [ ] Backend running locally on port 8000
- [ ] Flutter app can reach `http://localhost:8000/health`
- [ ] ApiService implemented with all methods
- [ ] AppState connected to ApiService
- [ ] CrowdData model matches API response
- [ ] Error handling with fallback to dummy data
- [ ] Auto-refresh timer (30 seconds)
- [ ] AI insights integration
- [ ] Google Maps integration
- [ ] Production URL configured for Vercel

---

**For detailed API documentation, see [FRONTEND_INTEGRATION.md](./FRONTEND_INTEGRATION.md)**

**Built with ❤️ for CrowdSense AI**
