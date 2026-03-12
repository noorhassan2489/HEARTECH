from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, List

# Add ml folder to path if needed depending on structure, but usually python finds it
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ml.risk_model import calculate_risk

router = APIRouter()

class RiskScoreRequest(BaseModel):
    child_id: str
    age_months: float
    score: int
    max_score: int
    has_clinical_flags: bool
    family_history: bool
    responses: Dict[str, int]

class RiskScoreResponse(BaseModel):
    risk_score_raw: float
    risk_level: str
    confidence: float
    method: str

@router.post("/risk-score", response_model=RiskScoreResponse)
async def get_risk_score(req: RiskScoreRequest):
    try:
        # We pass the features to our ML/Heuristic model
        result = calculate_risk(
            age_months=req.age_months,
            score=req.score,
            max_score=req.max_score,
            has_clinical_flags=req.has_clinical_flags,
            family_history=req.family_history
        )
        return RiskScoreResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to calculate risk: {str(e)}")
