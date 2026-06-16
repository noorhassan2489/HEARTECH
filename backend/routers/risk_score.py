from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from firebase_admin import firestore

from auth_dependency import verify_firebase_token
from child_auth import assert_child_access

router = APIRouter()
db = firestore.client()


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


class AggregateRiskRequest(BaseModel):
    childId: str
    trigger: Optional[str] = None


class AggregateRiskResponse(BaseModel):
    riskScore: int
    riskLevel: str
    breakdown: Dict[str, Optional[int]]
    recommendations: List[str]


# Source weights for milestone score
SOURCE_WEIGHTS = {
    "hcw": 1.0,
    "parent": 0.7,
    "teacher": 0.7,
    "speech": 0.5,
}

RECENCY_DAYS = 30
RECENCY_BOOST = 0.10


def _score_answers(
    answers: List[dict],
    conductor_role: str,
    medical_history: Optional[dict] = None,
    clinical_note: Optional[str] = None,
) -> int:
    """Return risk score 0-100 from questionnaire answers."""
    score = 0.0
    max_score = 0.0

    answer_scores = {
        "yes": 1.0,
        "partial": 0.5,
        "no": 0.0,
        "not_sure": 0.3,
        "sometimes": 0.5,
        "always": 1.0,
        "often": 0.75,
        "rarely": 0.25,
        "never": 0.0,
    }

    role_weight = 1.0 if conductor_role == "hcw" else 0.7

    for ans in answers or []:
        raw_answer = (
            ans.get("answer", "")
            .lower()
            .strip()
            .replace(" ", "_")
            .replace("'", "")
        )
        is_clinical = ans.get("isClinical", False)
        clinical_multiplier = 2.0 if is_clinical else 1.0
        answer_score = answer_scores.get(raw_answer, 0.3)
        max_score += 1.0 * clinical_multiplier * role_weight
        score += answer_score * clinical_multiplier * role_weight

    medical_penalty = 0.0
    med_history = medical_history or {}
    if med_history.get("prematureBirth", False):
        medical_penalty += 0.1
    if med_history.get("nicuAdmission", False):
        medical_penalty += 0.1
    if med_history.get("familyHistoryHearingLoss", False):
        medical_penalty += 0.1
    ear_infections = med_history.get("earInfectionCount", 0)
    if isinstance(ear_infections, (int, float)):
        medical_penalty += ear_infections * 0.03

    if clinical_note and clinical_note.strip():
        medical_penalty += 0.05

    if max_score > 0:
        good_ratio = score / max_score
        normalized = int((1.0 - good_ratio) * 100 + medical_penalty * 100)
    else:
        normalized = 0

    return max(0, min(100, normalized))


def _level_from_score(score: int) -> str:
    if score <= 33:
        return "low"
    if score <= 66:
        return "medium"
    return "high"


def _parse_date(value) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if hasattr(value, "timestamp"):
        return datetime.fromtimestamp(value.timestamp(), tz=timezone.utc)
    if isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


def _recency_multiplier(session_date: Optional[datetime]) -> float:
    if session_date is None:
        return 1.0
    now = datetime.now(timezone.utc)
    days = (now - session_date).days
    if days <= RECENCY_DAYS:
        return 1.0 + RECENCY_BOOST
    return 1.0


def _normalize_ling_frequency_flag(raw: str) -> str:
    """Map frequencyFlag to refer/watch/pass (handles legacy stored values)."""
    flag = (raw or "").lower().strip()
    if flag in ("refer", "referral"):
        return "refer"
    if flag in ("watch", "monitor"):
        return "watch"
    if flag in ("pass", "normal"):
        return "pass"
    # Legacy: frequencyRangeEstimate text stored in frequencyFlag
    if any(k in flag for k in ("profound", "significant", "severe", "all frequencies")):
        return "refer"
    if flag and ("possible" in flag or "loss" in flag or "mixed" in flag):
        return "watch"
    return "pass"


def _speech_risk_score(log: dict) -> int:
    """Convert speech log to risk 0-100 (higher = more concern)."""
    game = (log.get("game") or "").lower().replace(" ", "").replace("_", "")
    if "lingsix" in game or game == "lingsix":
        flag = _normalize_ling_frequency_flag(log.get("frequencyFlag") or "")
        if flag == "refer":
            return 75
        if flag == "watch":
            return 45
        return 15
    # Show and Tell — invert performance score when present
    score = log.get("score")
    if score is None:
        score = log.get("matchScore")
    if isinstance(score, (int, float)) and score > 0:
        return max(0, min(100, 100 - int(score)))
    clarity = (log.get("clarityRating") or "").lower()
    if clarity in ("unclear", "needs practice"):
        return 60
    if clarity == "good":
        return 30
    if clarity == "excellent":
        return 15
    return 40


def _latest_doc(docs: list, date_field: str = "date"):
    if not docs:
        return None
    best = None
    best_dt = None
    for d in docs:
        data = d.to_dict() if hasattr(d, "to_dict") else d
        dt = _parse_date(data.get(date_field)) or _parse_date(data.get("createdAt"))
        if best is None or (dt and (best_dt is None or dt > best_dt)):
            best = data
            best_dt = dt
    return best


@router.post("/risk-score", response_model=RiskScoreResponse)
async def calculate_risk_score(
    request: RiskScoreRequest,
    user=Depends(verify_firebase_token),
):
    """
    Calculate hearing risk score using weighted scoring algorithm.
    """
    flagged = []
    answer_scores = {
        "yes": 1.0,
        "partial": 0.5,
        "no": 0.0,
        "not_sure": 0.3,
        "sometimes": 0.5,
        "always": 1.0,
        "often": 0.75,
        "rarely": 0.25,
        "never": 0.0,
    }
    role_weight = 1.0 if request.conductorRole == "hcw" else 0.7
    score = 0.0
    max_score = 0.0

    for ans in request.answers:
        raw_answer = ans.get("answer", "").lower().strip().replace(" ", "_").replace("'", "")
        is_clinical = ans.get("isClinical", False)
        clinical_multiplier = 2.0 if is_clinical else 1.0
        answer_score = answer_scores.get(raw_answer, 0.3)
        max_score += 1.0 * clinical_multiplier * role_weight
        score += answer_score * clinical_multiplier * role_weight
        if answer_score < 0.5:
            flagged.append({
                "questionId": ans.get("questionId", ""),
                "questionText": ans.get("questionText", ""),
                "answer": ans.get("answer", ""),
                "isClinical": is_clinical,
            })

    metadata = request.childMetadata or {}
    med_history = metadata.get("medicalHistory", {})
    normalized = _score_answers(
        request.answers,
        request.conductorRole,
        med_history,
        request.clinicalNote,
    )
    risk_level = _level_from_score(normalized)
    recommendations = _get_recommendations(risk_level, normalized, flagged)

    return RiskScoreResponse(
        riskScore=normalized,
        riskLevel=risk_level,
        flaggedItems=flagged,
        recommendations=recommendations,
    )


@router.post("/risk-score/aggregate", response_model=AggregateRiskResponse)
async def aggregate_risk_score(
    request: AggregateRiskRequest,
    token: dict = Depends(verify_firebase_token),
):
    """
    Combine latest HCW screening, parent screening, teacher observation,
    and speech session into a weighted milestone risk score.
    """
    assert_child_access(token.get("uid", ""), request.childId)

    child_ref = db.collection("children").document(request.childId)
    child_doc = child_ref.get()
    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Child not found")

    child = child_doc.to_dict() or {}
    medical_history = child.get("medicalHistory", {})
    age_bracket = child.get("ageBracket", 1)

    breakdown: Dict[str, Optional[int]] = {
        "hcw": None,
        "parent": None,
        "teacher": None,
        "speech": None,
    }
    weighted_sum = 0.0
    weight_total = 0.0

    # Latest HCW screening
    hcw_screenings = (
        child_ref.collection("screenings")
        .where("conductorRole", "==", "hcw")
        .stream()
    )
    hcw_list = list(hcw_screenings)
    latest_hcw = _latest_doc(hcw_list, "date")
    if latest_hcw:
        answers = latest_hcw.get("answers", [])
        if latest_hcw.get("riskScore") is not None:
            hcw_score = int(latest_hcw["riskScore"])
        else:
            hcw_score = _score_answers(
                answers,
                "hcw",
                medical_history,
                latest_hcw.get("clinicalNote"),
            )
        breakdown["hcw"] = hcw_score
        w = SOURCE_WEIGHTS["hcw"] * _recency_multiplier(_parse_date(latest_hcw.get("date")))
        weighted_sum += hcw_score * w
        weight_total += w

    # Latest parent screening
    parent_screenings = (
        child_ref.collection("screenings")
        .where("conductorRole", "==", "parent")
        .stream()
    )
    parent_list = list(parent_screenings)
    latest_parent = _latest_doc(parent_list, "date")
    if latest_parent:
        if latest_parent.get("riskScore") is not None:
            parent_score = int(latest_parent["riskScore"])
        else:
            parent_score = _score_answers(
                latest_parent.get("answers", []),
                "parent",
                medical_history,
            )
        breakdown["parent"] = parent_score
        w = SOURCE_WEIGHTS["parent"] * _recency_multiplier(_parse_date(latest_parent.get("date")))
        weighted_sum += parent_score * w
        weight_total += w

    # Latest teacher observation
    obs_stream = child_ref.collection("teacherObservations").stream()
    obs_list = list(obs_stream)
    latest_obs = _latest_doc(obs_list, "date")
    if latest_obs:
        if latest_obs.get("riskScoreContribution") is not None:
            teacher_score = int(latest_obs["riskScoreContribution"])
        else:
            teacher_score = _score_answers(
                latest_obs.get("answers", []),
                "teacher",
                medical_history,
                latest_obs.get("openNote"),
            )
        breakdown["teacher"] = teacher_score
        w = SOURCE_WEIGHTS["teacher"] * _recency_multiplier(_parse_date(latest_obs.get("date")))
        weighted_sum += teacher_score * w
        weight_total += w

    # Latest speech log
    speech_stream = child_ref.collection("speechLogs").stream()
    speech_list = list(speech_stream)
    latest_speech = _latest_doc(speech_list, "date")
    if latest_speech:
        speech_score = _speech_risk_score(latest_speech)
        breakdown["speech"] = speech_score
        w = SOURCE_WEIGHTS["speech"] * _recency_multiplier(_parse_date(latest_speech.get("date")))
        weighted_sum += speech_score * w
        weight_total += w

    if weight_total > 0:
        final_score = int(round(weighted_sum / weight_total))
    else:
        final_score = int(child.get("riskScore", 0) or 0)

    final_score = max(0, min(100, final_score))
    risk_level = _level_from_score(final_score)
    recommendations = _get_recommendations(risk_level, final_score, [])

    return AggregateRiskResponse(
        riskScore=final_score,
        riskLevel=risk_level,
        breakdown=breakdown,
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
