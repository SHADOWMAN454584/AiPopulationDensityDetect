# CrowdSense AI API Documentation

**Version:** 4.2.0  
**Base URL:** `http://your-server-url` (replace with your deployed server URL)

---

## Table of Contents

1. [Health & Status Endpoints](#health--status-endpoints)
2. [Locations Endpoints](#locations-endpoints)
3. [Predictions Endpoints](#predictions-endpoints)
4. [Realtime Pipeline Endpoints](#realtime-pipeline-endpoints)
5. [Maps Endpoints](#maps-endpoints)
6. [Best Time Endpoint](#best-time-endpoint)
7. [AI Endpoints](#ai-endpoints)
8. [Training Endpoints](#training-endpoints)
9. [Chatbot Endpoints](#chatbot-endpoints)

---

## Health & Status Endpoints

### `GET /`
Root endpoint - API info.

**Response:**
```json
{
  "message": "CrowdSense AI API — Real-Time Crowd Density Engine",
  "status": "healthy",
  "version": "4.2.0",
  "engine": "BestTime Live → BestTime Now → Google+Physics",
  "docs": "/docs"
}
```

---

### `GET /ping`
Simple ping endpoint.

**Response:**
```json
{
  "ping": "pong",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

### `GET /health`
Detailed health check with configuration status.

**Response:**
```json
{
  "status": "ok",
  "model": "gemini-1.5-flash",
  "service": "CrowdSense AI",
  "engine": "v4.2-besttime-accurate",
  "ist_time": "16:00 IST",
  "ist_day": "Monday",
  "is_holiday": false,
  "city": "Mumbai",
  "center_latitude": 19.076,
  "center_longitude": 72.8777,
  "bounds": {...},
  "googleMapsConfigured": true,
  "besttimeConfigured": true,
  "weatherConfigured": true,
  "geminiConfigured": true,
  "total_heatmap_locations": 20,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

### `GET /city-info`
Get city information and bounds.

**Response:**
```json
{
  "city": "Mumbai",
  "state": "Maharashtra",
  "country": "India",
  "center_latitude": 19.076,
  "center_longitude": 72.8777,
  "bounds": {...},
  "total_monitored_locations": 20
}
```

---

## Locations Endpoints

### `GET /locations`
Get all monitored locations.

**Response:**
```json
{
  "locations": [
    {
      "locationId": "loc-csmt",
      "locationName": "CSMT Railway Station",
      "latitude": 18.9398,
      "longitude": 72.8354,
      "area": "South Mumbai",
      "venue_type": "railway_station",
      "capacity": 6000
    }
    // ... more locations
  ],
  "total": 20,
  "city": "Mumbai",
  "bounds": {...}
}
```

---

### `GET /locations/nearby`
Get locations near a coordinate.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `latitude` | float | Yes | User's latitude |
| `longitude` | float | Yes | User's longitude |
| `radius_km` | float | No | Search radius in km (default: 10.0) |

**Example:** `/locations/nearby?latitude=19.076&longitude=72.877&radius_km=5`

**Response:**
```json
{
  "locations": [
    {
      "locationId": "loc-csmt",
      "locationName": "CSMT Railway Station",
      "latitude": 18.9398,
      "longitude": 72.8354,
      "distance_km": 2.5
    }
  ],
  "total": 5,
  "radius_km": 5,
  "user_lat": 19.076,
  "user_lng": 72.877
}
```

---

## Predictions Endpoints

### `GET /predictions/bulk`
Get crowd predictions for all monitored locations.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `hour` | int (0-23) | No | Hour to predict for (default: current hour) |

**Response:**
```json
{
  "data": [
    {
      "locationId": "loc-csmt",
      "location_id": "loc-csmt",
      "locationName": "CSMT Railway Station",
      "location_name": "CSMT Railway Station",
      "latitude": 18.9398,
      "longitude": 72.8354,
      "crowdDensity": 65.5,
      "crowd_density": 65.5,
      "crowdCount": 3930,
      "crowd_count": 3930,
      "status": "moderate",
      "source": "besttime_live",
      "timestamp": "2024-01-15T10:30:00.000Z",
      "predictedNextHour": 70.2,
      "predicted_next_hour": 70.2
    }
  ],
  "hour": 16,
  "count": 20,
  "city": "Mumbai"
}
```

---

### `POST /predict`
Get prediction for a single location.

**Request Body:**
```json
{
  "location_id": "loc-csmt",
  "hour": 16
}
```

**Response:**
```json
{
  "location_id": "loc-csmt",
  "location_name": "CSMT Railway Station",
  "predicted_density": 65.5,
  "status": "moderate",
  "source": "besttime_live",
  "hour": 16,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

## Realtime Pipeline Endpoints

### `GET /realtime/status`
Get realtime data pipeline status.

**Response:**
```json
{
  "enabled": true,
  "provider": "besttime_live",
  "status": "available",
  "sources": {
    "besttime": true,
    "google_places": true,
    "openweather": true,
    "physics_engine": true
  }
}
```

---

### `POST /realtime/collect`
Trigger fresh data collection for all locations.

**Response:**
```json
{
  "data": [...],
  "source": "realtime",
  "sources_used": ["besttime_live", "physics_engine"],
  "count": 20,
  "city": "Mumbai"
}
```

---

### `GET /realtime/cached`
Get cached realtime data (or collect if cache empty).

**Response:**
```json
{
  "data": [...],
  "source": "cache",
  "city": "Mumbai"
}
```

---

### `POST /realtime/predict`
Get realtime prediction for a specific location.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location_id` | string | Yes | Location ID |
| `hour` | int (0-23) | No | Hour to predict for |

**Example:** `/realtime/predict?location_id=loc-csmt&hour=16`

**Response:**
```json
{
  "location_id": "loc-csmt",
  "location_name": "CSMT Railway Station",
  "predicted_density": 65.5,
  "status": "moderate",
  "source": "besttime_live",
  "hour": 16,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

## Maps Endpoints

### `GET /maps/search`
Search for places by query.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `q` | string | Yes | Search query |
| `limit` | int | No | Max results (default: 6, max: 20) |
| `latitude` | float | No | Bias search near this latitude |
| `longitude` | float | No | Bias search near this longitude |

**Example:** `/maps/search?q=coffee%20shop&latitude=19.076&longitude=72.877`

**Response:**
```json
[
  {
    "name": "Starbucks",
    "display_name": "Starbucks, Lower Parel, Mumbai",
    "lat": 19.0022,
    "lng": 72.8298,
    "type": "cafe",
    "source": "google_places"
  }
]
```

---

### `GET /maps/nearby`
Find nearby places with crowd data.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `latitude` | float | Yes | Center latitude |
| `longitude` | float | Yes | Center longitude |
| `radius` | float | No | Radius in meters (default: 2000, max: 50000) |
| `place_type` | string | No | Filter by place type (e.g., "restaurant") |

**Response:**
```json
{
  "nearby_locations": [
    {
      "id": "ChIJN1t...",
      "name": "Phoenix Mall",
      "lat": 18.9937,
      "lng": 72.8262,
      "crowd_density": 55.2,
      "status": "moderate",
      "source": "besttime_live",
      "types": ["shopping_mall"],
      "vicinity": "Lower Parel"
    }
  ],
  "places": [...],
  "results": [...],
  "radius_km": 2,
  "count": 10
}
```

---

### `GET /maps/estimate-crowd/{location_id}`
Estimate crowd at a specific coordinate.

**Path Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `location_id` | string | Location identifier |

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `latitude` | float | Yes | Location latitude |
| `longitude` | float | Yes | Location longitude |

**Response:**
```json
{
  "location_id": "custom",
  "location_name": "Area at 19.0760, 72.8777",
  "crowd_density": 45.5,
  "status": "moderate",
  "source": "besttime_live",
  "venues_sampled": 5,
  "venue_details": [...],
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

### `POST /maps/directions`
Get directions between two points.

**Request Body:**
```json
{
  "origin": { "lat": 19.076, "lng": 72.877 },
  "destination": { "lat": 19.054, "lng": 72.840 },
  "mode": "driving"
}
```

**Response:** Google Directions API response format

---

### `GET /maps/place/{place_id}`
Get details for a specific place.

**Path Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `place_id` | string | Google Place ID |

**Response:**
```json
{
  "place_id": "ChIJN1t...",
  "name": "Phoenix Mall",
  "address": "462, Senapati Bapat Marg, Lower Parel",
  "rating": 4.3,
  "open_now": true,
  "types": ["shopping_mall", "point_of_interest"]
}
```

---

## Best Time Endpoint

### `GET /best-time`
Find the best time to travel between locations.

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `from` | string | Yes | Origin location ID |
| `to` | string | Yes | Destination location ID |

**Example:** `/best-time?from=loc-csmt&to=loc-bandra`

**Response:**
```json
{
  "from": "loc-csmt",
  "to": "loc-bandra",
  "current_hour": 16,
  "current_density": 65.5,
  "current_status": "moderate",
  "best_hour": 6,
  "best_time": "06:00",
  "expected_density": 25.2,
  "status": "low",
  "worst_hour": 18,
  "worst_time": "18:00",
  "worst_density": 85.0,
  "city": "Mumbai",
  "data_source": "besttime_weekly",
  "hourly_predictions": [
    { "hour": 0, "density": 15.2, "status": "low" },
    { "hour": 1, "density": 12.5, "status": "low" }
    // ... 24 hours
  ],
  "fastest_route": {
    "mode": "driving",
    "duration": "35 mins",
    "distance": "15.2 km",
    "summary": "Western Express Highway"
  }
}
```

---

## AI Endpoints

### `POST /ai/smart-route`
Get AI-powered smart route recommendations.

**Request Body:**
```json
{
  "origin": {
    "name": "CSMT Station",
    "lat": 18.9398,
    "lng": 72.8354
  },
  "destination": {
    "name": "Bandra Station",
    "lat": 19.0543,
    "lng": 72.8403
  },
  "mode": "driving"
}
```

**Response:**
```json
{
  "origin": { "name": "CSMT Station", "lat": 18.9398, "lng": 72.8354 },
  "destination": { "name": "Bandra Station", "lat": 19.0543, "lng": 72.8403 },
  "ist_time": "04:00 PM IST",
  "ist_day": "Monday",
  "route_cards": [
    {
      "mode": "driving",
      "mode_label": "🚗 Car",
      "summary": "Western Express Highway",
      "duration": "35 mins",
      "duration_secs": 2100,
      "distance": "15.2 km"
    }
  ],
  "fastest": {
    "mode": "driving",
    "mode_label": "🚗 Car",
    "summary": "Western Express Highway",
    "duration": "35 mins",
    "distance": "15.2 km"
  },
  "best_route_line": "🚗 Car via Western Express Highway — 35 mins (15.2 km)",
  "why": "This is the fastest route at this time with moderate traffic.",
  "ai_advice": "...",
  "best_time": "4:00 PM (depart now)",
  "recommendations": [
    { "text": "Take Western Express Highway for best ETA" },
    { "text": "Avoid peak-hour roads between 8–10 AM and 5–8 PM" }
  ],
  "city": "Mumbai"
}
```

---

### `POST /ai/insights`
Get AI-generated crowd insights.

**Request Body:**
```json
{
  "crowdData": [
    {
      "locationName": "CSMT Station",
      "crowdDensity": 65,
      "status": "moderate",
      "source": "besttime_live"
    }
  ]
}
```

**Response:**
```json
{
  "summary": "🚉 Current crowd situation in Mumbai...",
  "success": true,
  "city": "Mumbai"
}
```

---

### `POST /ai/route-advice`
Get AI route advice based on origin/destination names.

**Request Body:**
```json
{
  "origin": "CSMT Station",
  "destination": "Bandra Station",
  "crowdData": []
}
```

**Response:**
```json
{
  "advice": "...",
  "fastest_mode": "driving",
  "routes_available": {...},
  "recommendations": [...]
}
```

---

## Training Endpoints

### `POST /realtime/train`
Start realtime model training.

**Request Body:**
```json
{
  "hours_to_sample": 24
}
```

**Response:**
```json
{
  "status": "running",
  "started_at": "2024-01-15T10:30:00.000Z",
  "message": "Training started",
  "status_code": 200
}
```

---

### `GET /realtime/train/status`
Get training status.

**Response:**
```json
{
  "training": {
    "status": "completed",
    "started_at": "2024-01-15T10:30:00.000Z",
    "completed_at": "2024-01-15T11:00:00.000Z",
    "last_rows_used": 5000
  }
}
```

---

### `GET /realtime/training-data`
Get training data statistics.

**Response:**
```json
{
  "training_data": {
    "total_samples": 5000,
    "locations_covered": 20,
    "city": "Mumbai",
    "last_trained": "2024-01-15T11:00:00.000Z",
    "model_version": "4.2-besttime-accurate-physics-calibrated"
  }
}
```

---

## Chatbot Endpoints

### `POST /api/chatbot`
Chat with the AI assistant (public transport, crowd prediction, transit expert).

**Request Body:**
```json
{
  "message": "What's the best time to travel to avoid crowds at CSMT?",
  "conversation_history": [
    { "role": "user", "content": "Hello" },
    { "role": "assistant", "content": "Hi! How can I help you with transit?" }
  ]
}
```

**Response:**
```json
{
  "response": "Based on typical crowd patterns at CSMT Railway Station...",
  "topic_valid": true,
  "suggested_topics": null
}
```

---

### `GET /api/chatbot/topics`
Get list of supported chatbot topics.

**Response:**
```json
{
  "supported_topics": [
    {
      "category": "Public Transport",
      "description": "Bus schedules, departures, routes, alerts, and service updates",
      "example_questions": [
        "What are the bus routes from downtown to the airport?",
        "Are there any bus service alerts today?"
      ]
    },
    {
      "category": "Crowd Prediction",
      "description": "Crowd density predictions and analysis",
      "example_questions": [...]
    },
    {
      "category": "Transit Systems",
      "description": "Metro, subway, train, tram information",
      "example_questions": [...]
    }
  ]
}
```

---

## Status Values

The `status` field in crowd data uses these values:

| Status | Density Range | Description |
|--------|---------------|-------------|
| `low` | 0-35% | Low crowd, easy movement |
| `moderate` | 36-65% | Moderate crowd, some waiting |
| `high` | 66-85% | High crowd, expect delays |
| `very_high` | 86-100% | Very crowded, avoid if possible |

---

## Data Sources

The API uses multiple data sources with fallback chain:

1. **BestTime Live API** (Primary) - Real-time foot traffic data
2. **BestTime Now API** (Fallback) - Current busyness
3. **Google Places** (Secondary) - Popularity data
4. **Physics Engine** (Tertiary) - Algorithmic estimation based on:
   - Venue type & capacity
   - Time of day & day of week
   - Weather conditions
   - Public holidays

---

## Error Responses

All endpoints return standard HTTP error codes:

```json
{
  "detail": "Error message here"
}
```

| Code | Description |
|------|-------------|
| 400 | Bad Request - Invalid parameters |
| 404 | Not Found - Location/resource not found |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

---

## Interactive API Docs

FastAPI provides automatic interactive documentation:

- **Swagger UI:** `http://your-server-url/docs`
- **ReDoc:** `http://your-server-url/redoc`
