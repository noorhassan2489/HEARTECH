"""
Speech analysis endpoints — Whisper transcription, phoneme analysis, Ling Six scoring.
"""
import os
import re
import shutil
import subprocess
import tempfile
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Request, Depends
from pydantic import BaseModel
from typing import List, Optional

from auth_dependency import verify_firebase_token
from child_auth import assert_child_access

router = APIRouter()


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
LING_SOUND_ORDER = ("m", "ah", "oo", "ee", "sh", "s")
SHOW_AND_TELL_CATEGORIES = ("animals", "food", "objects", "body", "transport")

LING_SIX_SOUND_META = {
    "m": {"display": "/m/", "frequency": "250-500 Hz", "label": "Low frequency"},
    "ah": {"display": "/ah/", "frequency": "500-1000 Hz", "label": "Low-mid"},
    "oo": {"display": "/oo/", "frequency": "500-1000 Hz", "label": "Mid"},
    "ee": {"display": "/ee/", "frequency": "1000-3000 Hz", "label": "Mid-high"},
    "sh": {"display": "/sh/", "frequency": "2000-4000 Hz", "label": "High"},
    "s": {"display": "/s/", "frequency": "4000-8000 Hz", "label": "Very high"},
}


def _cloudinary_configured() -> bool:
    if os.environ.get("CLOUDINARY_URL", "").strip():
        return True
    return all(
        os.environ.get(k, "").strip()
        for k in ("CLOUDINARY_CLOUD_NAME", "CLOUDINARY_API_KEY", "CLOUDINARY_API_SECRET")
    )


def _ensure_cloudinary_config() -> bool:
    """Configure Cloudinary SDK before Admin API calls."""
    if not _cloudinary_configured():
        return False
    try:
        import cloudinary

        url = os.environ.get("CLOUDINARY_URL", "").strip()
        if url:
            cloudinary.config(cloudinary_url=url)
            return True
        cloudinary.config(
            cloud_name=os.environ.get("CLOUDINARY_CLOUD_NAME", "").strip(),
            api_key=os.environ.get("CLOUDINARY_API_KEY", "").strip(),
            api_secret=os.environ.get("CLOUDINARY_API_SECRET", "").strip(),
        )
        return True
    except Exception as e:
        print(f"[SPEECH-ASSETS] Cloudinary config failed: {e}")
        return False


def _list_cloudinary_resources(prefix: str, max_results: int = 30) -> list:
    """List Cloudinary upload resources under a folder prefix."""
    if not _ensure_cloudinary_config():
        print("[SPEECH-ASSETS] Cloudinary not configured — check CLOUDINARY_URL in backend/.env")
        return []
    try:
        import cloudinary.api
        from cloudinary import Search

        prefix_clean = prefix.strip("/")
        list_prefix = f"{prefix_clean}/"

        result = cloudinary.api.resources(
            type="upload",
            prefix=list_prefix,
            max_results=max_results,
        )
        resources = result.get("resources", [])
        if resources:
            print(f"[SPEECH-ASSETS] Found {len(resources)} via resources() for {list_prefix}")
            return resources

        # Media Library folder view can require Search API on some accounts.
        search_result = (
            Search()
            .expression(f'folder="{prefix_clean}"')
            .max_results(max_results)
            .execute()
        )
        resources = search_result.get("resources", [])
        if resources:
            print(f"[SPEECH-ASSETS] Found {len(resources)} via search() for {prefix_clean}")
            return resources

        print(f"[SPEECH-ASSETS] No resources for prefix {list_prefix}")
        return []
    except Exception as e:
        print(f"[SPEECH-ASSETS] Cloudinary list failed for {prefix}: {e}")
        return []


# Cloudinary appends a random 6-char suffix to uploaded filenames (e.g. cat_niwwo5).
_CLOUDINARY_SUFFIX_RE = re.compile(r"_[a-z0-9]{6}$", re.IGNORECASE)


def _normalize_asset_word(raw: str) -> str:
    """Turn a Cloudinary public_id / filename into a clean display + match word."""
    word = os.path.splitext(raw.split("/")[-1])[0]
    word = _CLOUDINARY_SUFFIX_RE.sub("", word)
    word = word.replace("_", " ").replace("-", " ").strip()
    return word


def _word_from_public_id(public_id: str) -> str:
    return _normalize_asset_word(public_id)


def _ling_sound_key_from_public_id(public_id: str) -> str:
    """Extract Ling Six sound key (m, ah, oo, ...) from a Cloudinary public_id."""
    stem = os.path.splitext(public_id.split("/")[-1])[0]
    stem = _CLOUDINARY_SUFFIX_RE.sub("", stem)
    if stem.lower().startswith("ling_"):
        stem = stem[5:]
    return stem.lower().strip()


def _speech_match_score(expected: str, transcript: str) -> int:
    """Best fuzzy score between expected word and transcript (handles single-word utterances)."""
    from rapidfuzz import fuzz

    expected = expected.strip().lower()
    transcript = re.sub(r"[^\w\s]", "", transcript.strip().lower()).strip()
    if not expected or not transcript:
        return 0

    scores = [
        fuzz.ratio(transcript, expected),
        fuzz.partial_ratio(transcript, expected),
        fuzz.token_sort_ratio(transcript, expected),
    ]
    for token in transcript.split():
        scores.extend([
            fuzz.ratio(token, expected),
            fuzz.partial_ratio(token, expected),
        ])
        if token == expected:
            scores.append(100)

    return int(max(scores))


def _sanitize_english_transcript(text: str) -> str:
    """Keep ASCII letters/spaces only — no CJK or other scripts in Show & Tell output."""
    if not text:
        return ""
    cleaned = "".join(
        ch if (ch.isascii() and (ch.isalpha() or ch.isspace())) else " "
        for ch in text
    )
    return re.sub(r"\s+", " ", cleaned).strip().lower()


def _trim_silence_wav(input_path: str) -> str:
    """Trim leading/trailing silence so Whisper does not hallucinate on quiet tails."""
    trimmed_path = f"{input_path}.trim.wav"
    try:
        subprocess.run(
            [
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-i", input_path,
                "-af",
                (
                    "silenceremove=start_periods=1:start_duration=0.05:start_threshold=-42dB:detection=rms,"
                    "silenceremove=stop_periods=-1:stop_duration=0.25:stop_threshold=-42dB:detection=rms"
                ),
                trimmed_path,
            ],
            check=True,
            capture_output=True,
        )
        if os.path.exists(trimmed_path) and os.path.getsize(trimmed_path) > 500:
            return trimmed_path
    except Exception as exc:
        print(f"[ANALYZE-SPEECH] Silence trim skipped: {exc}")
    return input_path


def _looks_like_hallucination(text: str, expected: str) -> bool:
    words = text.split()
    if len(words) > 4:
        return True
    if len(text) > max(len(expected) * 3, 24):
        return True
    filler_phrases = (
        "thank you for watching",
        "subscribe",
        "please subscribe",
        "stop listening",
        "we should",
    )
    lowered = text.lower()
    return any(phrase in lowered for phrase in filler_phrases)


def _pick_show_and_tell_transcript(expected: str, result: dict) -> str:
    """Choose the most plausible short English transcript for a single-word game."""
    from rapidfuzz import fuzz

    expected = expected.strip().lower()
    segments = result.get("segments") or []

    short_segment_texts = []
    for seg in segments:
        text = _sanitize_english_transcript(seg.get("text", ""))
        if not text:
            continue
        if len(text.split()) <= 4:
            short_segment_texts.append((seg.get("avg_logprob", -9.0), text))

    if short_segment_texts:
        short_segment_texts.sort(key=lambda item: item[0], reverse=True)
        return short_segment_texts[0][1]

    raw = _sanitize_english_transcript(result.get("text", ""))
    if not raw:
        return ""

    if not _looks_like_hallucination(raw, expected):
        return raw

    tokens = raw.split()
    best = raw
    best_score = -1
    for token in tokens:
        score = fuzz.ratio(token, expected)
        if score > best_score:
            best_score = score
            best = token

    if len(raw.split()) > 1:
        for window in (2, 3):
            if len(tokens) < window:
                continue
            for i in range(len(tokens) - window + 1):
                phrase = " ".join(tokens[i : i + window])
                score = fuzz.ratio(phrase, expected)
                if score > best_score:
                    best_score = score
                    best = phrase

    return best or raw


def _transcribe_show_and_tell_word(whisper_model, audio_path: str, expected_word: str) -> dict:
    """Transcribe one English word with anti-hallucination Whisper settings."""
    expected = expected_word.strip().lower()
    return whisper_model.transcribe(
        audio_path,
        language="en",
        task="transcribe",
        fp16=False,
        temperature=0.0,
        condition_on_previous_text=False,
        compression_ratio_threshold=2.0,
        logprob_threshold=-0.8,
        no_speech_threshold=0.65,
        initial_prompt=f"English word: {expected}.",
    )


def _fetch_show_and_tell_from_cloudinary() -> dict:
    categories = {}
    for category in SHOW_AND_TELL_CATEGORIES:
        resources = _list_cloudinary_resources(f"heartech/show_and_tell/{category}/", max_results=50)
        image_resources = [
            r for r in resources
            if r.get("resource_type") in (None, "image") and r.get("secure_url")
        ]
        if image_resources:
            categories[category] = [
                {
                    "word": _word_from_public_id(r["public_id"]),
                    "url": r["secure_url"],
                }
                for r in image_resources
            ]
    return categories


def _fetch_ling_six_from_cloudinary() -> list:
    audio_resources = _list_cloudinary_resources("heartech/ling_six/audio/")
    image_resources = _list_cloudinary_resources("heartech/ling_six/images/")

    audio_by_sound = {}
    for resource in audio_resources:
        sound = _ling_sound_key_from_public_id(resource["public_id"])
        if sound in LING_SIX_SOUND_META:
            audio_by_sound[sound] = resource["secure_url"]

    image_by_sound = {}
    for resource in image_resources:
        sound = _ling_sound_key_from_public_id(resource["public_id"])
        if sound in LING_SIX_SOUND_META:
            image_by_sound[sound] = resource["secure_url"]

    sounds = []
    for sound in LING_SOUND_ORDER:
        meta = LING_SIX_SOUND_META[sound]
        sounds.append({
            "sound": sound,
            "display": meta["display"],
            "frequency": meta["frequency"],
            "label": meta["label"],
            "audioUrl": audio_by_sound.get(sound),
            "imageUrl": image_by_sound.get(sound),
        })
    return sounds


def _deterministic_frequency_profile(missed_sounds: List[str]) -> dict:
    ordered_missed = [sound for sound in LING_SOUND_ORDER if sound in set(missed_sounds)]
    if not ordered_missed:
        return {
            "orderedMissedSounds": [],
            "frequencyBands": [],
            "rationale": "No missed sounds in Round 2.",
        }

    bands = []
    details = []
    for sound in ordered_missed:
        info = LING_FREQUENCY_MAP.get(sound, {})
        band = info.get("range")
        if band and band not in bands:
            bands.append(band)
        details.append(f"/{sound}/ -> {info.get('range', 'Unknown')} ({info.get('label', 'unknown')})")

    return {
        "orderedMissedSounds": ordered_missed,
        "frequencyBands": bands,
        "rationale": "; ".join(details),
    }



def _ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None


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
    assert_child_access(user.get("uid", ""), childId)

    # ── Save uploaded .wav to temp file ───────────────────────────────────
    temp_path = None
    trimmed_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            content = await audioFile.read()
            tmp.write(content)
            temp_path = tmp.name

        # ── Transcribe with Whisper (lazy load) ───────────────────────────
        whisper_model = getattr(request.app.state, "whisper_model", None)
        if whisper_model is None and not getattr(request.app.state, "whisper_load_attempted", False):
            try:
                import whisper

                print("[SPEECH] Loading Whisper 'base' model...")
                whisper_model = whisper.load_model("base")
                request.app.state.whisper_model = whisper_model
                print("[SPEECH] Whisper ready.")
            except Exception as e:
                print(f"[SPEECH] WARNING: Failed to load Whisper model: {e}")
            finally:
                request.app.state.whisper_load_attempted = True
            whisper_model = getattr(request.app.state, "whisper_model", None)

        if whisper_model is None:
            # Whisper not loaded — fail closed; client must not save this result
            return {
                "transcript": "",
                "matchScore": 0,
                "clarityRating": "Unavailable",
                "phonemesCorrect": [],
                "phonemesMissed": [],
                "feedbackMessage": (
                    "Speech analysis is unavailable right now. "
                    "Please wait a moment and try recording again."
                ),
                "isFallback": True,
                "analysisUnavailable": True,
            }

        if not _ffmpeg_available():
            print("[ANALYZE-SPEECH] ffmpeg not found on PATH — Whisper cannot decode audio.")
            raise HTTPException(
                status_code=503,
                detail=(
                    "Speech analysis requires ffmpeg. Install it locally with: brew install ffmpeg "
                    "(then restart the backend)."
                ),
            )

        expected_clean = _normalize_asset_word(expectedWord)
        if not expected_clean:
            expected_clean = expectedWord.strip().lower()

        trimmed_path = _trim_silence_wav(temp_path)
        whisper_result = _transcribe_show_and_tell_word(
            whisper_model, trimmed_path, expected_clean
        )
        transcript_clean = _pick_show_and_tell_transcript(expected_clean, whisper_result)
        transcript = transcript_clean

        # ── Fuzzy match ───────────────────────────────────────────────────
        expected_lower = expected_clean.lower()
        match_score = _speech_match_score(expected_lower, transcript_clean or transcript)

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
            feedback = f"Excellent pronunciation! '{expected_clean}' was clearly spoken."
        elif clarity_rating == "Good":
            feedback = f"Good attempt at '{expected_clean}'! Keep practicing for even clearer speech."
        elif clarity_rating == "Needs Practice":
            missed_str = ", ".join(f"/{p}/" for p in phonemes_missed[:3]) if phonemes_missed else "some sounds"
            feedback = f"'{expected_clean}' needs more practice. Focus on {missed_str}."
        else:
            feedback = (
                f"The word '{expected_clean}' was not clearly detected"
                f"{f' (we heard \"{transcript_clean}\")' if transcript_clean else ''}. "
                "Try speaking more slowly and clearly."
            )

        return {
            "transcript": transcript_clean or transcript,
            "expectedWord": expected_clean,
            "matchScore": match_score,
            "clarityRating": clarity_rating,
            "phonemesCorrect": phonemes_correct,
            "phonemesMissed": phonemes_missed,
            "feedbackMessage": feedback,
            "analysisFallbackUsed": False,
            "analysisAvailable": True,
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[ANALYZE-SPEECH] Error: {e}")
        if "ffmpeg" in str(e).lower():
            raise HTTPException(
                status_code=503,
                detail=(
                    "Speech analysis requires ffmpeg. Install it locally with: brew install ffmpeg "
                    "(then restart the backend)."
                ),
            )
        raise HTTPException(status_code=500, detail="Speech analysis failed. Please try again.")

    finally:
        for path in {temp_path, trimmed_path}:
            if path and os.path.exists(path):
                os.unlink(path)


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
    assert_child_access(user.get("uid", ""), request_body.childId)

    results = request_body.results
    child_id = request_body.childId

    # ── Score based on Round 2 heard count ────────────────────────────────
    round2_heard = sum(1 for r in results if r.round2heard)

    if round2_heard == 6:
        overall_result = "pass"
    elif round2_heard >= 4:
        overall_result = "watch"
    else:
        overall_result = "refer"

    # ── Frequency range estimation ────────────────────────────────────────
    missed_sounds = [r.sound for r in results if not r.round2heard]
    frequency_profile = _deterministic_frequency_profile(missed_sounds)

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
            bands = frequency_profile["frequencyBands"]
            freq_estimate = (
                f"Possible loss in: {', '.join(bands)}" if bands else "Possible mixed-frequency hearing concern"
            )

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

        if overall_result == "refer":
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

    return {
        "overallResult": overall_result,
        "frequencyRangeEstimate": freq_estimate,
        "frequencyProfile": frequency_profile,
        "roundSummary": {
            "round1HeardCount": sum(1 for r in results if r.round1heard),
            "round2HeardCount": round2_heard,
            "totalSounds": len(results),
        },
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
    Return Show and Tell image URLs organized by category from Cloudinary.
    Response includes source metadata; no silent emoji-only fallback.
    """
    categories = _fetch_show_and_tell_from_cloudinary()
    if categories:
        return {
            "source": "cloudinary",
            "categories": categories,
            "message": "",
        }

    return {
        "source": "fallback",
        "categories": FALLBACK_IMAGES,
        "message": (
            "Using built-in emoji word bank. Upload images to Cloudinary under "
            "heartech/show_and_tell/{category}/ for photo-based cards."
        ),
    }


# ═══════════════════════════════════════════════════════════════════════════════
# GET /api/ling-six-assets
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/ling-six-assets")
async def get_ling_six_assets(user=Depends(verify_firebase_token)):
    """
    Return Ling Six sound manifest with Cloudinary audio/image URLs.
    """
    sounds = _fetch_ling_six_from_cloudinary()
    has_remote_assets = any(s.get("audioUrl") or s.get("imageUrl") for s in sounds)
    if has_remote_assets:
        return {
            "source": "cloudinary",
            "sounds": sounds,
            "message": "",
        }

    return {
        "source": "empty",
        "sounds": sounds,
        "message": (
            "No Ling Six assets found in Cloudinary. "
            "Upload audio to heartech/ling_six/audio/ling_{sound}.mp3 "
            "and images to heartech/ling_six/images/{sound}.jpg."
        ),
    }
