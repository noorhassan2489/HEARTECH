from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import random

router = APIRouter()


class RiskScoreRequest(BaseModel):
    answers: List[dict]
    ageBracket: int
    conductorRole: str
    childId: Optional[str] = None


class RiskScoreResponse(BaseModel):
    riskScore: int
    riskLevel: str
    flaggedQuestions: List[dict]


@router.post("/risk-score", response_model=RiskScoreResponse)
async def calculate_risk_score(request: RiskScoreRequest):
    """
    Calculate hearing risk score using AI model.
    In production, uses trained Random Forest model.
    Currently uses a weighted scoring algorithm.
    """
    score = 0
    total_weight = 0
    flagged = []

    # Scoring weights per answer
    answer_weights = {
        # HCW/Parent responses
        "yes": 0, "partial": 1, "sometimes": 1,
        "no": 2, "not_sure": 1,
        # Teacher responses
        "always": 0, "often": 0, "rarely": 2, "never": 2,
    }

    clinical_weight = 2.0  # Clinical questions count double

    for ans in request.answers:
        answer = ans.get("answer", "").lower().replace(" ", "_").replace("'", "")
        is_clinical = ans.get("isClinical", False)
        weight = clinical_weight if is_clinical else 1.0
        answer_score = answer_weights.get(answer, 1)

        score += answer_score * weight
        total_weight += 2 * weight  # Max possible per question

        # Flag concerning answers
        if answer_score >= 2:
            flagged.append({
                "questionId": ans.get("questionId", ""),
                "questionText": ans.get("questionText", ""),
                "answer": ans.get("answer", ""),
                "isClinical": is_clinical,
            })

    # Normalize to 0-100
    if total_weight > 0:
        normalized = int((score / total_weight) * 100)
    else:
        normalized = 0

    # Determine risk level
    if normalized <= 33:
        risk_level = "low"
    elif normalized <= 66:
        risk_level = "medium"
    else:
        risk_level = "high"

    return RiskScoreResponse(
        riskScore=normalized,
        riskLevel=risk_level,
        flaggedQuestions=flagged,
    )
