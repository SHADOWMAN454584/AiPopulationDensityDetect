"""
CrowdSense AI - ML Model Training Script
Trains a Linear Regression model on historical crowd data.
"""

import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import joblib
import os

def train_model():
    # Load data
    data_path = os.path.join(os.path.dirname(__file__), 'data', 'crowd_data.csv')
    df = pd.read_csv(data_path)

    print(f"Loaded {len(df)} records")
    print(f"Columns: {list(df.columns)}")
    print(f"Locations: {df['Location'].unique()}")

    # Encode location as numeric
    location_mapping = {loc: i for i, loc in enumerate(df['Location'].unique())}
    df['Location_Encoded'] = df['Location'].map(location_mapping)

    # Features
    features = ['Location_Encoded', 'Hour', 'Day_of_Week', 'Is_Weekend', 'Is_Holiday']
    X = df[features]
    y = df['Crowd_Density']

    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # Train model
    model = LinearRegression()
    model.fit(X_train, y_train)

    # Evaluate
    y_pred = model.predict(X_test)
    mae = mean_absolute_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)

    print(f"\n--- Model Performance ---")
    print(f"MAE: {mae:.2f}")
    print(f"R² Score: {r2:.4f}")
    print(f"Feature Importance (coefficients):")
    for feat, coef in zip(features, model.coef_):
        print(f"  {feat}: {coef:.4f}")
    print(f"  Intercept: {model.intercept_:.4f}")

    # Save model and mapping
    model_dir = os.path.join(os.path.dirname(__file__), 'model')
    os.makedirs(model_dir, exist_ok=True)

    joblib.dump(model, os.path.join(model_dir, 'crowd_model.pkl'))
    joblib.dump(location_mapping, os.path.join(model_dir, 'location_mapping.pkl'))

    print(f"\nModel saved to {model_dir}/")
    return model, location_mapping


if __name__ == '__main__':
    train_model()
