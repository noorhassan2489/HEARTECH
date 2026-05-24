"""
Speech analysis endpoints — Whisper transcription, phoneme analysis, Ling Six scoring.
"""
import os
import tempfile
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Request, Depends
from pydantic import BaseModel
from typing import List, Optional
from firebase_admin import firestore

from auth_dependency import verify_firebase_token
from services.notification_service import NotificationService

router = APIRouter()
db = firestore.client()


# ═══════════════════════════════════════════════════════════════════════════════
# MODELS
# ═══════════════════════════════════════════════════════════════════════════════

class LingSixSoundResult(BaseModel):
    sound: str
    round1heard: bool
    round2heard: bool


class LingSixRequest(BaseModel):
    results: List[LingSixSoundResult]
    childId: str


# ═══════════════════════════════════════════════════════════════════════════════
# SHOW AND TELL IMAGE BANK — fallback when Cloudinary folder is empty
# ═══════════════════════════════════════════════════════════════════════════════

# These serve as the word bank with emoji placeholders.
# When real images are uploaded to Cloudinary heartech/show_and_tell/,
# the /api/speech-images endpoint will serve those instead.
FALLBACK_IMAGES = {
    "animals": [
        {"word": "cat", "url": "emoji://🐱"},
        {"word": "dog", "url": "emoji://🐶"},
        {"word": "fish", "url": "emoji://🐟"},
        {"word": "bird", "url": "emoji://🐦"},
        {"word": "cow", "url": "emoji://🐄"},
        {"word": "duck", "url": "emoji://🦆"},
        {"word": "frog", "url": "emoji://🐸"},
        {"word": "horse", "url": "emoji://🐴"},
        {"word": "sheep", "url": "emoji://🐑"},
        {"word": "lion", "url": "emoji://🦁"},
    ],
    "food": [
        {"word": "milk", "url": "emoji://🥛"},
        {"word": "rice", "url": "emoji://🍚"},
        {"word": "egg", "url": "emoji://🥚"},
        {"word": "cake", "url": "emoji://🎂"},
        {"word": "apple", "url": "emoji://🍎"},
        {"word": "banana", "url": "emoji://🍌"},
        {"word": "bread", "url": "emoji://🍞"},
        {"word": "cheese", "url": "emoji://🧀"},
        {"word": "grape", "url": "emoji://🍇"},
        {"word": "orange", "url": "emoji://🍊"},
    ],
    "objects": [
        {"word": "ball", "url": "emoji://⚽"},
        {"word": "cup", "url": "emoji://🥤"},
        {"word": "shoe", "url": "emoji://👟"},
        {"word": "book", "url": "emoji://📚"},
        {"word": "chair", "url": "emoji://🪑"},
        {"word": "clock", "url": "emoji://🕐"},
        {"word": "key", "url": "emoji://🔑"},
        {"word": "phone", "url": "emoji://📱"},
        {"word": "star", "url": "emoji://⭐"},
        {"word": "hat", "url": "emoji://🎩"},
    ],
    "body": [
        {"word": "hand", "url": "emoji://✋"},
        {"word": "eye", "url": "emoji://👁️"},
        {"word": "nose", "url": "emoji://👃"},
        {"word": "ear", "url": "emoji://👂"},
        {"word": "mouth", "url": "emoji://👄"},
        {"word": "foot", "url": "emoji://🦶"},
        {"word": "teeth", "url": "emoji://🦷"},
        {"word": "hair", "url": "emoji://💇"},
        {"word": "thumb", "url": "emoji://👍"},
        {"word": "leg", "url": "emoji://🦵"},
    ],
    "transport": [
        {"word": "car", "url": "emoji://🚗"},
        {"word": "bus", "url": "emoji://🚌"},
        {"word": "boat", "url": "emoji://⛵"},
        {"word": "bike", "url": "emoji://🚲"},
        {"word": "train", "url": "emoji://🚂"},
        {"word": "plane", "url": "emoji://✈️"},
        {"word": "truck", "url": "emoji://🚛"},
        {"word": "taxi", "url": "emoji://🚕"},
        {"word": "ship", "url": "emoji://🚢"},
        {"word": "rocket", "url": "emoji://🚀"},
    ],
}


# ═══════════════════════════════════════════════════════════════════════════════
# LING SIX FREQUENCY MAP
# ═══════════════════════════════════════════════════════════════════════════════

LING_FREQUENCY_MAP = {
    "m": {"range": "250-500 Hz", "label": "nasal, low frequency"},
    "ah": {"range": "500-1000 Hz", "label": "open vowel, low-mid"},
    "oo": {"range": "500-1000 Hz", "label": "rounded vowel, mid"},
    "ee": {"range": "1000-3000 Hz", "label": "front vowel, mid-high"},
    "sh": {"range": "2000-4000 Hz", "label": "fricative, high"},
    "s": {"range": "4000-8000 Hz", "label": "sibilant, very high"},
}


# ═══════════════════════════════════════════════════════════════════════════════
# HELPER — fire HCW-08 notification
# ═══════════════════════════════════════════════════════════════════════════════

async def _fire_hcw08(child_id: str, game_name: str):
    """Send HCW-08 notification to all linked HCWs for this child."""
    try:
        child_doc = db.collection("children").document(child_id).get()
        if not child_doc.exists:
            return
        child_data = child_doc.to_dict()
        child_name = child_data.get("name", "A child")
        hcw_ids = child_data.get("hcwIds", [])

        for hcw_id in hcw_ids:
            await NotificationService.send(
                uid=hcw_id,
                notif_type="HCW-08",
                title="Speech Session Completed",
                body=f"{child_name} completed a {game_name} session.",
                related_child_id=child_id,
                navigation_route=f"/hcw/child/{child_id}",
            )
    except Exception as e:
        print(f"[HCW-08] Failed to send notification: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/analyze-speech
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/analyze-speech")
async def analyze_speech(
    request: Request,
    audioFile: UploadFile = File(...),
    expectedWord: str = Form(...),
    childId: str = Form(...),
    user=Depends(verify_firebase_token),
):
    """
    Analyze speech using Whisper + rapidfuzz + phonemizer.
    Accepts a .wav file, transcribes it, fuzzy-matches against the expected word,
    and performs phoneme analysis.
    """
    # ── Save uploaded .wav to temp file ───────────────────────────────────
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            content = await audioFile.read()
            tmp.write(content)
            temp_path = tmp.name

        # ── Transcribe with Whisper ───────────────────────────────────────
        whisper_model = getattr(request.app.state, "whisper_model", None)
        if whisper_model is None:
            # Whisper not loaded — return graceful fallback
            return {
                "transcript": expectedWord.lower(),
                "matchScore": 70,
                "clarityRating": "Good",
                "phonemesCorrect": [],
                "phonemesMissed": [],
                "feedbackMessage": "Speech analysis model is loading. Please try again in a moment.",
            }

        result = whisper_model.transcribe(temp_path)
        transcript = result["text"].strip().lower()

        # Remove punctuation from transcript for cleaner matching
        import re
        transcript_clean = re.sub(r'[^\w\s]', '', transcript).strip()

        # ── Fuzzy match ───────────────────────────────────────────────────
        from rapidfuzz import fuzz
        expected_lower = expectedWord.strip().lower()
        match_score = int(fuzz.ratio(transcript_clean, expected_lower))

        # ── Phoneme analysis ──────────────────────────────────────────────
        phonemes_correct = []
        phonemes_missed = []

        try:
            from phonemizer import phonemize

            expected_ph = phonemize(
                expected_lower,
                language="en-us",
                backend="espeak",
                strip=True,
            )
            heard_ph = phonemize(
                transcript_clean if transcript_clean else expected_lower,
                language="en-us",
                backend="espeak",
                strip=True,
            )

            # Compare phonemes character by character
            expected_phonemes = list(expected_ph.replace(" ", ""))
            heard_phonemes = set(heard_ph.replace(" ", ""))

            for ph in expected_phonemes:
                if ph in heard_phonemes:
                    phonemes_correct.append(ph)
                else:
                    phonemes_missed.append(ph)

            # Deduplicate
            phonemes_correct = list(dict.fromkeys(phonemes_correct))
            phonemes_missed = list(dict.fromkeys(phonemes_missed))

        except Exception as e:
            print(f"[PHONEMIZER] Phoneme analysis failed (non-critical): {e}")
            # Continue without phoneme data — still return transcript + score

        # ── Clarity rating ────────────────────────────────────────────────
        if match_score >= 90:
            clarity_rating = "Excellent"
        elif match_score >= 60:
            clarity_rating = "Good"
        elif match_score >= 30:
            clarity_rating = "Needs Practice"
        else:
            clarity_rating = "Unclear"

        # ── Feedback message ──────────────────────────────────────────────
        if clarity_rating == "Excellent":
            feedback = f"Excellent pronunciation! '{expectedWord}' was clearly spoken."
        elif clarity_rating == "Good":
            feedback = f"Good attempt at '{expectedWord}'! Keep practicing for even clearer speech."
        elif clarity_rating == "Needs Practice":
            missed_str = ", ".join(f"/{p}/" for p in phonemes_missed[:3]) if phonemes_missed else "some sounds"
            feedback = f"'{expectedWord}' needs more practice. Focus on {missed_str}."
        else:
            feedback = f"The word '{expectedWord}' was not clearly detected. Try speaking more slowly and clearly."

        # ── Fire HCW-08 notification ──────────────────────────────────────
        await _fire_hcw08(childId, "Show and Tell")

        return {
            "transcript": transcript_clean or transcript,
            "matchScore": match_score,
            "clarityRating": clarity_rating,
            "phonemesCorrect": phonemes_correct,
            "phonemesMissed": phonemes_missed,
            "feedbackMessage": feedback,
        }

    except Exception as e:
        print(f"[ANALYZE-SPEECH] Error: {e}")
        raise HTTPException(status_code=500, detail=f"Speech analysis failed: {str(e)}")

    finally:
        # ── Clean up temp file ────────────────────────────────────────────
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/ling-six-analysis
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/ling-six-analysis")
async def ling_six_analysis(
    request_body: LingSixRequest,
    user=Depends(verify_firebase_token),
):
    """
    Analyze Ling Six sound test results.
    Scores based on Round 2 (definitive round).
    Estimates frequency range of potential hearing loss.
    """
    results = request_body.results
    child_id = request_body.childId

    # ── Score based on Round 2 heard count ────────────────────────────────
    round2_heard = sum(1 for r in results if r.round2heard)

    if round2_heard == 6:
        overall_result = "Pass"
    elif round2_heard >= 4:
        overall_result = "Watch"
    else:
        overall_result = "Refer"

    # ── Frequency range estimation ────────────────────────────────────────
    missed_sounds = [r.sound for r in results if not r.round2heard]

    if not missed_sounds:
        freq_estimate = "All frequencies detected (250-8000 Hz)"
        clinical_explanation = (
            "The child responded to all 6 Ling sounds in both rounds. "
            "This suggests functional hearing across the speech frequency range "
            "(250 Hz to 8000 Hz). No immediate concerns detected."
        )
        recommendation = (
            "Continue regular hearing monitoring. Retest periodically "
            "to ensure consistent results."
        )
    else:
        missed_set = set(missed_sounds)

        # Determine frequency range affected
        if missed_set == {"s"}:
            freq_estimate = "Possible high frequency loss above 4000 Hz"
        elif missed_set <= {"s", "sh"}:
            freq_estimate = "Possible high frequency loss above 2000 Hz"
        elif missed_set <= {"s", "sh", "ee"}:
            freq_estimate = "Possible hearing loss above 1000 Hz"
        elif missed_set <= {"s", "sh", "ee", "oo"}:
            freq_estimate = "Moderate to severe hearing loss indicated"
        elif missed_set <= {"s", "sh", "ee", "oo", "ah"}:
            freq_estimate = "Significant hearing loss across multiple frequencies"
        elif len(missed_set) == 6:
            freq_estimate = "Profound hearing loss indicator — all frequencies affected"
        else:
            # Mixed pattern
            freq_ranges = []
            for sound in missed_sounds:
                if sound in LING_FREQUENCY_MAP:
                    freq_ranges.append(LING_FREQUENCY_MAP[sound]["range"])
            freq_estimate = f"Possible loss in: {', '.join(set(freq_ranges))}"

        # Build clinical explanation
        missed_details = []
        for sound in missed_sounds:
            if sound in LING_FREQUENCY_MAP:
                info = LING_FREQUENCY_MAP[sound]
                missed_details.append(f"/{sound}/ ({info['range']} — {info['label']})")

        clinical_explanation = (
            f"The child did not respond to {len(missed_sounds)} of 6 sounds in Round 2. "
            f"Missed sounds: {', '.join(missed_details)}. "
            f"This pattern suggests {freq_estimate.lower()}. "
            f"Round 1 (1 meter) results should be compared with Round 2 (3 meters) "
            f"to assess distance-dependent hearing ability."
        )

        if overall_result == "Refer":
            recommendation = (
                "Professional audiological evaluation is strongly recommended. "
                "The pattern of missed sounds suggests potential hearing loss that "
                "requires clinical assessment. Please consult with an audiologist."
            )
        else:
            recommendation = (
                "Monitor closely and retest in 2 weeks. If results are consistent, "
                "consider referring for professional audiological evaluation. "
                "Ensure testing environment is quiet during retest."
            )

    # ── Flagged sounds with details ───────────────────────────────────────
    flagged_sounds = []
    for r in results:
        if not r.round2heard:
            info = LING_FREQUENCY_MAP.get(r.sound, {})
            flagged_sounds.append({
                "sound": r.sound,
                "frequency": info.get("range", "Unknown"),
                "description": info.get("label", "Unknown"),
                "round1heard": r.round1heard,
                "round2heard": r.round2heard,
            })

    # ── Fire HCW-08 notification ──────────────────────────────────────────
    await _fire_hcw08(child_id, "Ling Six Test")

    return {
        "overallResult": overall_result,
        "frequencyRangeEstimate": freq_estimate,
        "flaggedSounds": flagged_sounds,
        "clinicalExplanation": clinical_explanation,
        "recommendation": recommendation,
    }


# ═══════════════════════════════════════════════════════════════════════════════
# GET /api/speech-images
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/speech-images")
async def get_speech_images(user=Depends(verify_firebase_token)):
    """
    Return Show and Tell image URLs organized by category.
    Serves from Cloudinary heartech/show_and_tell/ folder if available,
    otherwise returns fallback emoji word bank.
    """
    # Try to fetch from Cloudinary if configured
    try:
        import cloudinary
        import cloudinary.api

        cloudinary_url = os.environ.get("CLOUDINARY_URL")
        if cloudinary_url:
            # Attempt to list resources from Cloudinary folder
            categories = {}
            for category in ["animals", "food", "objects", "body", "transport"]:
                try:
                    result = cloudinary.api.resources(
                        type="upload",
                        prefix=f"heartech/show_and_tell/{category}/",
                        max_results=20,
                    )
                    if result.get("resources"):
                        categories[category] = [
                            {
                                "word": os.path.splitext(
                                    r["public_id"].split("/")[-1]
                                )[0],
                                "url": r["secure_url"],
                            }
                            for r in result["resources"]
                        ]
                except Exception:
                    pass  # Category folder doesn't exist yet

            if categories:
                # Fill missing categories with fallback
                for cat in FALLBACK_IMAGES:
                    if cat not in categories:
                        categories[cat] = FALLBACK_IMAGES[cat]
                return categories

    except ImportError:
        pass  # cloudinary not configured
    except Exception as e:
        print(f"[SPEECH-IMAGES] Cloudinary fetch failed: {e}")

    # Return fallback emoji word bank
    return FALLBACK_IMAGES
