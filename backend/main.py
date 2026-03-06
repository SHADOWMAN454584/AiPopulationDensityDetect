"""
CrowdSense AI - FastAPI Backend
Serves crowd density predictions via REST API.
Works locally with uvicorn and on Vercel as serverless.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import os

app = FastAPI(
    title="CrowdSense AI API",
    description="Crowd density prediction API powered by ML",
    version="1.0.0",
)

# CORS - allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Load model ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, 'model')
model = None
location_mapping = None

# Location ID to name mapping (matching Flutter app)
LOCATION_ID_TO_NAME = {
    "metro_a": "Metro Station A",
    "metro_b": "Metro Station B",
    "bus_stop_1": "Central Bus Stop",
    "mall_1": "City Mall",
    "park_1": "Green Park",
    "station_1": "Railway Station",
}

def load_model():
    global model, location_mapping
    model_path = os.path.join(MODEL_DIR, 'crowd_model.pkl')
    mapping_path = os.path.join(MODEL_DIR, 'location_mapping.pkl')

    if os.path.exists(model_path) and os.path.exists(mapping_path):
        try:
            import joblib
            model = joblib.load(model_path)
            location_mapping = joblib.load(mapping_path)
            print("Model loaded successfully!")
        except ImportError:
            print("WARNING: joblib not available. Using fallback predictions.")
    else:
        print("WARNING: Model not found. Run train_model.py first.")
        print("Using fallback predictions.")

# Auto-load model on import (works for both uvicorn and Vercel)
load_model()

# --- Request/Response Models ---
class PredictionRequest(BaseModel):
    location_id: str
    hour: int  # 0-23
    day_of_week: int  # 0=Mon, 6=Sun
    is_weekend: int  # 0 or 1
    is_holiday: int  # 0 or 1

class PredictionResponse(BaseModel):
    location_id: str
    location_name: str
    predicted_density: float
    status: str
    hour: int
    day_of_week: int

class BulkPredictionRequest(BaseModel):
    hour: int
    day_of_week: int

class BestTimeResponse(BaseModel):
    from_location: str
    to_location: str
    best_hour: int
    best_time: str
    expected_density: float
    status: str
    hourly_predictions: list

# --- Helper Functions ---
def get_status(density: float) -> str:
    if density < 40:
        return "low"
    elif density < 70:
        return "medium"
    return "high"

def predict_density(location_id: str, hour: int, day_of_week: int,
                    is_weekend: int, is_holiday: int) -> float:
    """Predict crowd density for given parameters."""
    if model is None or location_mapping is None:
        # Fallback: simple heuristic
        base = 30
        if 7 <= hour <= 10:
            base = 70
        elif 16 <= hour <= 20:
            base = 80
        elif 11 <= hour <= 15:
            base = 50
        if is_weekend:
            base *= 0.7
        return round(min(max(base, 0), 100), 1)

    # Map location ID to training name
    loc_name = LOCATION_ID_TO_NAME.get(location_id, "Metro Station A")
    loc_encoded = location_mapping.get(loc_name, 0)

    features = np.array([[loc_encoded, hour, day_of_week, is_weekend, is_holiday]])
    prediction = model.predict(features)[0]
    return round(min(max(prediction, 0), 100), 1)

# --- Endpoints ---
@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "version": "1.0.0",
    }

@app.post("/predict", response_model=PredictionResponse)
async def predict(req: PredictionRequest):
    """Predict crowd density for a specific location and time."""
    if req.hour < 0 or req.hour > 23:
        raise HTTPException(status_code=400, detail="Hour must be 0-23")
    if req.day_of_week < 0 or req.day_of_week > 6:
        raise HTTPException(status_code=400, detail="Day must be 0-6")

    density = predict_density(
        req.location_id, req.hour, req.day_of_week,
        req.is_weekend, req.is_holiday
    )

    loc_name = LOCATION_ID_TO_NAME.get(req.location_id, req.location_id)

    return PredictionResponse(
        location_id=req.location_id,
        location_name=loc_name,
        predicted_density=density,
        status=get_status(density),
        hour=req.hour,
        day_of_week=req.day_of_week,
    )

@app.post("/predict/bulk")
async def predict_bulk(req: BulkPredictionRequest):
    """Predict crowd density for all locations at a given time."""
    is_weekend = 1 if req.day_of_week >= 5 else 0

    predictions = []
    for loc_id, loc_name in LOCATION_ID_TO_NAME.items():
        density = predict_density(loc_id, req.hour, req.day_of_week, is_weekend, 0)
        predictions.append({
            "location_id": loc_id,
            "location_name": loc_name,
            "predicted_density": density,
            "status": get_status(density),
        })

    return {"predictions": predictions}

@app.get("/best-time")
async def best_time(from_location: str = "metro_a", to_location: str = "metro_b"):
    """Find the best time to travel (lowest crowd hour)."""
    from datetime import datetime
    now = datetime.now()
    today_dow = now.weekday()  # 0=Mon, 6=Sun
    is_weekend = 1 if today_dow >= 5 else 0

    hourly = []
    for hour in range(6, 23):
        density = predict_density(from_location, hour, today_dow, is_weekend, 0)
        hourly.append({
            "hour": hour,
            "label": f"{hour:02d}:00",
            "density": density,
            "status": get_status(density),
        })

    # Find lowest density hour
    best = min(hourly, key=lambda x: x["density"])

    return BestTimeResponse(
        from_location=LOCATION_ID_TO_NAME.get(from_location, from_location),
        to_location=LOCATION_ID_TO_NAME.get(to_location, to_location),
        best_hour=best["hour"],
        best_time=best["label"],
        expected_density=best["density"],
        status=best["status"],
        hourly_predictions=hourly,
    )

@app.get("/locations")
async def list_locations():
    """List all monitored locations."""
    return {
        "locations": [
            {"id": k, "name": v} for k, v in LOCATION_ID_TO_NAME.items()
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
