# Backend Changes Required for AI Route Planner

This document describes the backend endpoints the frontend expects so that the **AI Route Planner** (formerly "Best Time to Travel") works end-to-end.

---

## Overview

The frontend now supports free-text location search for origin and destination, sends those coordinates to the backend, and expects an AI-powered fastest-route response that includes directions, crowd density, and AI advice.

### Flow

```
User types origin & destination
       │
       ▼
Geocode via /maps/search  (or Nominatim fallback)
       │
       ▼
POST /ai/smart-route   ← NEW primary endpoint
       │
       ▼ (if 404 / unavailable, frontend falls back to combining)
  ┌────┴────┐
  │         │
POST /maps/directions    GET /maps/estimate-crowd/custom
  │         │
  └────┬────┘
       │
  POST /ai/route-advice
       │
       ▼
Combined response rendered in UI
```

---

## 1. `POST /ai/smart-route` — ⭐ NEW endpoint (primary)

This is the single endpoint the frontend calls first. It should combine directions, crowd estimation, and AI analysis into one response.

### Request

```http
POST /ai/smart-route
Content-Type: application/json
```

```json
{
  "origin": {
    "name": "Times Square",
    "lat": 40.758,
    "lng": -73.9855
  },
  "destination": {
    "name": "Central Park",
    "lat": 40.7829,
    "lng": -73.9654
  },
  "mode": "driving"       // "driving" | "walking" | "transit" | "bicycling"
}
```

### Expected Response

```json
{
  "origin": {
    "name": "Times Square",
    "lat": 40.758,
    "lng": -73.9855
  },
  "destination": {
    "name": "Central Park",
    "lat": 40.7829,
    "lng": -73.9654
  },
  "best_time": "10:30 AM",
  "ai_advice": "Route 1 via 7th Avenue is the fastest option. Avoid Broadway due to high pedestrian density at this hour. Consider departing around 10:30 AM when crowd levels drop to ~25%.",
  "origin_crowd": {
    "crowd_density": 72.0,
    "status": "high"
  },
  "destination_crowd": {
    "crowd_density": 35.0,
    "status": "low"
  },
  "routes": [
    {
      "summary": "7th Avenue",
      "duration": "12 mins",
      "distance": "2.3 km",
      "warnings": null
    },
    {
      "summary": "Broadway",
      "duration": "18 mins",
      "distance": "2.8 km",
      "warnings": "Heavy pedestrian traffic expected"
    }
  ],
  "recommendations": [
    { "text": "Depart after 10 AM for 40% less crowd at origin" },
    { "text": "Use 7th Avenue to avoid high-density Broadway corridor" }
  ]
}
```

### Backend Implementation Guide

```python
# In your FastAPI app (e.g., routes/ai.py)

from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

router = APIRouter(prefix="/ai", tags=["AI"])

class LocationInput(BaseModel):
    name: str
    lat: float
    lng: float

class SmartRouteRequest(BaseModel):
    origin: LocationInput
    destination: LocationInput
    mode: str = "driving"  # driving | walking | transit | bicycling

@router.post("/smart-route")
async def ai_smart_route(req: SmartRouteRequest):
    # Step 1: Get directions from Google Maps
    directions = await google_maps_service.get_directions(
        origin_lat=req.origin.lat,
        origin_lng=req.origin.lng,
        dest_lat=req.destination.lat,
        dest_lng=req.destination.lng,
        mode=req.mode,
    )

    # Step 2: Estimate crowd at origin & destination
    origin_crowd = await estimate_crowd(req.origin.lat, req.origin.lng)
    dest_crowd = await estimate_crowd(req.destination.lat, req.destination.lng)

    # Step 3: Use Gemini/OpenAI to generate AI advice
    prompt = f"""
    Given a route from {req.origin.name} to {req.destination.name}:
    - Origin crowd density: {origin_crowd.get('crowd_density', 'unknown')}%
    - Destination crowd density: {dest_crowd.get('crowd_density', 'unknown')}%
    - Travel mode: {req.mode}
    - Routes available: {json.dumps(directions.get('routes', []))}
    
    Provide:
    1. Which route is fastest and least crowded
    2. Best time to depart to avoid crowds
    3. Any warnings or recommendations
    """
    
    ai_response = await ai_service.generate(prompt)

    # Step 4: Combine into response
    return {
        "origin": req.origin.dict(),
        "destination": req.destination.dict(),
        "best_time": extract_best_time(ai_response),
        "ai_advice": ai_response,
        "origin_crowd": origin_crowd,
        "destination_crowd": dest_crowd,
        "routes": directions.get("routes", []),
        "recommendations": extract_recommendations(ai_response),
    }
```

---

## 2. `GET /maps/search` — Place Search (may already exist)

The frontend calls this **before** Nominatim so that your backend can proxy Google Places Text Search for better results.

### Request

```http
GET /maps/search?q=Times+Square&limit=6&latitude=40.758&longitude=-73.985
```

### Expected Response

```json
[
  {
    "name": "Times Square",
    "display_name": "Times Square, Manhattan, New York, NY, USA",
    "lat": 40.758,
    "lng": -73.9855,
    "type": "tourist_attraction"
  }
]
```

> **If this endpoint doesn't exist yet**, the frontend automatically falls back to the free Nominatim OpenStreetMap geocoding API. No action needed, but adding this endpoint gives better results via Google Places.

### Backend Implementation Guide

```python
@router.get("/maps/search")
async def search_places(q: str, limit: int = 6, latitude: float = None, longitude: float = None):
    # Option A: Proxy Google Places Text Search
    results = await google_maps_service.text_search(
        query=q,
        location=(latitude, longitude) if latitude else None,
    )
    
    return [
        {
            "name": place["name"],
            "display_name": place.get("formatted_address", ""),
            "lat": place["geometry"]["location"]["lat"],
            "lng": place["geometry"]["location"]["lng"],
            "type": place.get("types", [""])[0],
        }
        for place in results[:limit]
    ]
```

---

## 3. Existing Endpoints Used (verify they work)

The frontend fallback mechanism combines these existing endpoints:

### `POST /maps/directions`

```json
// Request
{
  "origin": { "lat": 40.758, "lng": -73.985 },
  "destination": { "lat": 40.782, "lng": -73.965 },
  "mode": "driving"
}

// Response — should include routes[] with duration, distance, summary
{
  "routes": [
    {
      "duration": "12 mins",
      "distance": "2.3 km",
      "summary": "7th Avenue"
    }
  ]
}
```

### `GET /maps/estimate-crowd/{locationId}`

The frontend calls this with `locationId = "custom"` and lat/lng query params:

```http
GET /maps/estimate-crowd/custom?latitude=40.758&longitude=-73.985
```

> **Important**: The backend should handle `locationId = "custom"` by doing a real-time crowd estimation for the given coordinates (using Google Places nearby search popularity data) rather than looking up a predefined location.

### `POST /ai/route-advice`

```json
// Request
{
  "crowdData": [...],
  "origin": "Times Square",
  "destination": "Central Park"
}

// Response
{
  "advice": "Take Route 1 via 7th Avenue...",
  "best_time": "10:30 AM",
  "recommendations": [...]
}
```

---

## 4. Summary of Required Changes

| Endpoint | Status | Action |
|----------|--------|--------|
| `POST /ai/smart-route` | 🆕 **NEW** | Create this endpoint — combines directions + crowd + AI |
| `GET /maps/search` | 🟡 Optional | Proxies Google Places Text Search (frontend has Nominatim fallback) |
| `POST /maps/directions` | ✅ Existing | Verify it returns `routes[]` with `duration`, `distance`, `summary` |
| `GET /maps/estimate-crowd/custom` | 🟡 Modify | Handle `locationId = "custom"` with lat/lng params |
| `POST /ai/route-advice` | ✅ Existing | Verify it returns `advice`, `best_time`, `recommendations` |

---

## 5. Environment Variables Needed

```env
GOOGLE_MAPS_API_KEY=your_key_here      # For directions & places
GEMINI_API_KEY=your_key_here           # Or OPENAI_API_KEY for AI insights
```

---

## 6. Frontend Fallback Behavior

If `POST /ai/smart-route` returns 404 or fails, the frontend automatically:

1. Calls `POST /maps/directions` for route options
2. Calls `GET /maps/estimate-crowd/custom` for origin & destination crowd
3. Calls `POST /ai/route-advice` for AI analysis
4. Combines all three into the same UI format

This means **the frontend works even without the new endpoint** — it just makes 3 calls instead of 1.
