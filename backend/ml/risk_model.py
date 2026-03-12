import os
import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier

MODEL_PATH = "risk_rf_model.joblib"

# A basic training function that can be run once to generate a mock/baseline model
def train_baseline_model():
    # Features: [age_months, score, has_clinical_flags, family_history]
    # Target: 0 (Low), 1 (Medium), 2 (High)
    
    # Mock dataset
    X = np.array([
        [3, 2, 0, 0],   # Low risk baby
        [12, 15, 0, 0], # Medium risk toddler
        [24, 25, 1, 1], # High risk with clinical flag
        [36, 5, 0, 1],  # Low risk with fam history
        [6, 28, 1, 0],  # High risk infant
        [18, 10, 0, 0], # Low risk toddler
        [48, 20, 0, 0], # Medium risk child
        [2, 30, 1, 1],  # High risk newborn
    ])
    y = np.array([0, 1, 2, 0, 2, 0, 1, 2])
    
    clf = RandomForestClassifier(n_estimators=100, random_state=42)
    clf.fit(X, y)
    joblib.dump(clf, MODEL_PATH)
    return clf

def get_model():
    if os.path.exists(MODEL_PATH):
        return joblib.load(MODEL_PATH)
    else:
        return train_baseline_model()

def calculate_risk(age_months: float, score: int, max_score: int, has_clinical_flags: bool, family_history: bool) -> dict:
    # 1. Try ML Model
    try:
        model = get_model()
        features = np.array([[age_months, score, int(has_clinical_flags), int(family_history)]])
        prediction = model.predict(features)[0] # 0, 1, or 2
        
        risk_level = "Low"
        if prediction == 1:
            risk_level = "Medium"
        elif prediction == 2:
            risk_level = "High"
            
        # Optional: get probability
        proba = model.predict_proba(features)[0]
        confidence = float(np.max(proba))
        
        return {
            "risk_score_raw": score / max_score if max_score > 0 else 0.0,
            "risk_level": risk_level,
            "confidence": confidence,
            "method": "random_forest"
        }
    except Exception as e:
        print(f"ML Model failed, using rule-based fallback: {e}")
        # 2. Rule-based Fallback
        risk_ratio = score / max_score if max_score > 0 else 0.0
        
        # Clinical flags auto-bump to High
        if has_clinical_flags:
            return {
                "risk_score_raw": risk_ratio,
                "risk_level": "High",
                "confidence": 1.0,
                "method": "rule_based_clinical_flag"
            }
            
        if risk_ratio >= 0.7:
            level = "High"
        elif risk_ratio >= 0.4:
            level = "Medium"
        else:
            level = "Low"
            
        return {
            "risk_score_raw": risk_ratio,
            "risk_level": level,
            "confidence": 0.8,
            "method": "rule_based_heuristic"
        }
