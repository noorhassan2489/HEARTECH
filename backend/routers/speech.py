from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from typing import List

router = APIRouter()


class LingSixRequest(BaseModel):
    results: List[dict]
    childId: str


@router.post("/analyze-speech")
async def analyze_speech(
    audioFile: UploadFile = File(...),
    expectedWord: str = Form(...),
    childId: str = Form(...),
):
    """
    Analyze speech using Whisper + phonemizer.
    TODO: Implement in Phase 6.
    """
    # Placeholder response
    return {
        "transcript": expectedWord,
        "matchScore": 85,
        "clarityRating": "Good",
        "phonemesCorrect": [],
        "phonemesMissed": [],
        "feedbackMessage": "Good attempt! Keep practicing.",
    }


@router.post("/ling-six-analysis")
async def ling_six_analysis(request: LingSixRequest):
    """
    Analyze Ling Six sound test results.
    TODO: Implement full analysis in Phase 6.
    """
    heard_count = sum(1 for r in request.results if r.get("heard", False))
    total = len(request.results)

    if heard_count == total:
        overall = "Pass"
        recommendation = "Child appears to detect all frequency ranges."
    elif heard_count >= 4:
        overall = "Watch"
        recommendation = "Some sounds were missed. Monitor and retest."
    else:
        overall = "Refer"
        recommendation = "Multiple sounds missed. Professional evaluation recommended."

    flagged = [r["sound"] for r in request.results if not r.get("heard", False)]

    return {
        "overallResult": overall,
        "frequencyRangeEstimate": "250-8000 Hz" if heard_count == total else "Partial",
        "flaggedSounds": flagged,
        "clinicalExplanation": f"{heard_count}/{total} sounds detected.",
        "recommendation": recommendation,
    }
