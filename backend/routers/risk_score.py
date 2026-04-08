from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter()


class RiskScoreRequest(BaseModel):
    answers: List[dict]
    ageBracket: int
    conductorRole: str
    childId: Optional[str] = None
    clinicalNote: Optional[str] = None
    childMetadata: Optional[dict] = None


class RiskScoreResponse(BaseModel):
    riskScore: int
    riskLevel: str
    flaggedItems: List[dict]
    recommendations: List[str]


@router.post("/risk-score", response_model=RiskScoreResponse)
async def calculate_risk_score(request: RiskScoreRequest):
    """
    Calculate hearing risk score using weighted scoring algorithm.
    Scoring per the master prompt:
      yes=1.0, partial=0.5, no=0.0, not_sure=0.3
      Clinical questions: multiply score by 2 (double weight)
      Medical history flags each add 0.1
      Ear infection count * 0.03
      HCW answers weighted 1.0x, parent and teacher 0.7x
      Normalize to 0-100 scale
      Thresholds: 0-33 low, 34-66 medium, 67-100 high
    """
    score = 0.0
    max_score = 0.0
    flagged = []

    # Answer scoring – higher = better hearing (low risk)
    answer_scores = {
        # HCW/Parent responses
        "yes": 1.0, "partial": 0.5, "no": 0.0, "not_sure": 0.3,
        "sometimes": 0.5,
        # Teacher responses (always=good, never=bad)
        "always": 1.0, "often": 0.75, "sometimes": 0.5, "rarely": 0.25, "never": 0.0,
    }

    # Role weighting
    role_weight = 1.0 if request.conductorRole == "hcw" else 0.7

    for ans in request.answers:
        raw_answer = ans.get("answer", "").lower().strip().replace(" ", "_").replace("'", "")
        is_clinical = ans.get("isClinical", False)
        clinical_multiplier = 2.0 if is_clinical else 1.0

        answer_score = answer_scores.get(raw_answer, 0.3)
        # Max possible per question is 1.0 * clinical_multiplier * role_weight
        max_score += 1.0 * clinical_multiplier * role_weight
        score += answer_score * clinical_multiplier * role_weight

        # Flag concerning answers (score below 0.5 means concerning)
        if answer_score < 0.5:
            flagged.append({
                "questionId": ans.get("questionId", ""),
                "questionText": ans.get("questionText", ""),
                "answer": ans.get("answer", ""),
                "isClinical": is_clinical,
            })

    # Medical history adjustments (from childMetadata)
    medical_penalty = 0.0
    metadata = request.childMetadata or {}
    med_history = metadata.get("medicalHistory", {})

    if med_history.get("prematureBirth", False):
        medical_penalty += 0.1
    if med_history.get("nicuAdmission", False):
        medical_penalty += 0.1
    if med_history.get("familyHistoryHearingLoss", False):
        medical_penalty += 0.1
    ear_infections = med_history.get("earInfectionCount", 0)
    if isinstance(ear_infections, (int, float)):
        medical_penalty += ear_infections * 0.03

    # Normalize to 0-100 where 100 = high risk
    # score/max_score gives ratio of "good" answers
    # risk = 100 - (good_ratio * 100) + medical_penalty * 100 (capped)
    if max_score > 0:
        good_ratio = score / max_score
        normalized = int((1.0 - good_ratio) * 100 + medical_penalty * 100)
    else:
        normalized = 0

    # Cap at 0-100
    normalized = max(0, min(100, normalized))

    # Determine risk level
    if normalized <= 33:
        risk_level = "low"
    elif normalized <= 66:
        risk_level = "medium"
    else:
        risk_level = "high"

    # Generate recommendations
    recommendations = _get_recommendations(risk_level, normalized, flagged)

    return RiskScoreResponse(
        riskScore=normalized,
        riskLevel=risk_level,
        flaggedItems=flagged,
        recommendations=recommendations,
    )


def _get_recommendations(risk_level: str, score: int, flagged: list) -> list:
    """Generate recommendations based on risk level."""
    if risk_level == "low":
        return [
            "Continue monitoring the child's hearing development at regular intervals.",
            "Ensure the child is exposed to a variety of sounds and speech.",
            "Schedule a follow-up screening in 6-12 months.",
        ]
    elif risk_level == "medium":
        return [
            "Schedule a follow-up screening within 1-3 months.",
            "Monitor the child closely for changes in hearing behavior.",
            "Consider creating a child profile for ongoing tracking.",
            "Discuss findings with the child's parent or guardian.",
        ]
    else:
        return [
            "Immediate referral to an audiologist or ENT specialist is recommended.",
            "Create a child profile and generate a formal referral letter.",
            "Provide the parent with the handover code for ongoing monitoring.",
            "Schedule formal hearing tests (OAE, ABR) as soon as possible.",
            "Document all clinical observations in the patient notes.",
        ]
