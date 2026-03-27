# Frontend Integration Instructions (Realtime + Training)

This guide explains what to change in frontend so FastAPI endpoints connect end-to-end for:
- Maps data fetch
- model training with Maps data
- real-time result display

## 1) Base URL

Keep backend base URL configurable (dev/prod), for example:
- Dev: `http://localhost:8000`
- Prod: your deployed API URL

All endpoints below are relative to that base.

## 2) Realtime API flow to implement

Use this sequence in frontend:

1. Call `GET /realtime/status` on app load.
2. If `google_maps_configured=true`, call `GET /realtime/collect`.
3. Render returned `locations` in UI as "live crowd".
4. Poll `GET /realtime/collect` every 30-60 seconds (or based on app refresh policy).
5. If collect fails, fall back to `GET /realtime/cached`.

## 3) Endpoint contracts

### A) `GET /realtime/status`
Use this to decide if live Maps mode is available.

Important fields:
- `google_maps_configured` (bool)
- `cached_data_points` (int)
- `status` (`operational` or limited mode)

### B) `GET /realtime/collect`
Returns:
- `status`
- `data_points`
- `last_updated`
- `locations` (map keyed by `location_id`)

Each location object includes:
- `location_id`
- `timestamp`
- `nearby_places_count`
- `total_user_ratings`
- `place_rating`
- `business_status`
- `crowd_intensity` (0-100)

Use `crowd_intensity` as realtime density value in cards/map badges.

### C) `GET /realtime/cached`
Use as fallback when live collection request fails or rate limits occur.

### D) `POST /realtime/predict?location_id={id}&hour={optional}`
Use for a single location's realtime-aware prediction view/detail panel.

Response includes:
- `predicted_density`
- `status`
- `prediction_source`
- `real_time_data`

### E) `POST /realtime/train`
Trigger background model retraining from frontend admin panel.

Request body:
```json
{
  "hours_to_sample": 12,
  "blend_with_original": true,
  "weight_maps": 0.6
}
```

Validation rules:
- `hours_to_sample`: 1..24
- `weight_maps`: 0..1

Possible responses:
- `200`: training started
- `409`: training already running
- `503`: Maps API not configured

### F) `GET /realtime/train/status`
Poll this after triggering training (every 5-10 seconds):
- `training.status`: `idle | running | completed | failed`
- `training.last_error`: show in admin UI if failed
- `training.last_rows_used`: show summary on completion

### G) `GET /realtime/training-data`
Optional admin diagnostics endpoint to show available dataset row counts.

## 4) UI wiring recommendations

- Main map/home:
  - Use `/predict/bulk` for model-based current/next-hour cards.
  - Overlay/augment with `/realtime/collect` `crowd_intensity` when available.

- Location detail screen:
  - Prefer `/realtime/predict` to show live-aware value and source label.

- Admin training panel:
  - Form fields: `hours_to_sample`, `blend_with_original`, `weight_maps`.
  - Start button -> `POST /realtime/train`.
  - Disable start button while status is `running`.
  - Status badge from `/realtime/train/status`.

## 5) Error-handling behavior to implement

- If `/realtime/status` says Maps unavailable, hide "Live Maps" tag and continue with ML endpoints (`/predict`, `/predict/bulk`, `/best-time`).
- If `/realtime/collect` fails, call `/realtime/cached`.
- On training `409`, show "Training already in progress".
- On training `failed`, show `last_error` from `/realtime/train/status`.

## 6) Location ID consistency

Frontend and backend must use exact IDs:
- `metro_a`
- `metro_b`
- `bus_stop_1`
- `mall_1`
- `park_1`
- `station_1`
