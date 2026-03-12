import os
from fastapi import APIRouter, File, UploadFile, HTTPException, Form
from pydantic import BaseModel
import tempfile
import whisper
from rapidfuzz import fuzz

router = APIRouter()

# Load model globally to avoid reloading on every request (in a real app, do this smartly)
# For local development we might use 'tiny' to spare CPU/RAM
# To prevent blocking the server constantly loading, we try to load it lazily
_whisper_model = None

def get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        print("Loading Whisper Model...")
        _whisper_model = whisper.load_model("tiny.en")
        print("Whisper Model loaded.")
    return _whisper_model

class SpeechAnalysisResponse(BaseModel):
    transcription: str
    target_word: str
    match_score: float
    accuracy_level: str

@router.post("/analyze-speech", response_model=SpeechAnalysisResponse)
async def analyze_speech(audio: UploadFile = File(...), target_word: str = Form(...)):
    try:
        # Save uploaded file to temp file for Whisper to read
        fd, temp_path = tempfile.mkstemp(suffix=".wav")
        with os.fdopen(fd, 'wb') as f:
            f.write(await audio.read())
            
        model = get_whisper_model()
        
        # Transcribe
        result = model.transcribe(temp_path)
        transcription = result["text"].strip().lower()
        
        # Cleanup temp file
        os.remove(temp_path)
        
        # Compare using RapidFuzz
        target = target_word.lower()
        
        # Check phonetic / fuzzy match
        # partial_ratio is good for catching the word inside a sentence "it's a dog" -> "dog"
        score = fuzz.partial_ratio(target, transcription)
        
        if score >= 85:
            accuracy = "Excellent"
        elif score >= 60:
            accuracy = "Good"
        elif score >= 30:
            accuracy = "Needs Practice"
        else:
            accuracy = "Unclear"
            
        return SpeechAnalysisResponse(
            transcription=transcription,
            target_word=target,
            match_score=score,
            accuracy_level=accuracy
        )
    except Exception as e:
        print(f"Speech Analysis Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to analyze speech.")

class LingSixRequest(BaseModel):
    responses: dict[str, bool] # {"ah": True, "oo": False, "ee": True...}
    distance_meters: float

class LingSixResponse(BaseModel):
    score_percentage: float
    frequencies_missed: list[str]
    recommendation: str

@router.post("/ling-six-analysis", response_model=LingSixResponse)
async def analyze_ling_six(req: LingSixRequest):
    sounds = req.responses
    missed = [sound for sound, heard in sounds.items() if not heard]
    
    total = len(sounds)
    if total == 0:
        total = 6
        
    heard_count = total - len(missed)
    score = (heard_count / total) * 100
    
    if score == 100:
        rec = "Excellent hearing response across all frequencies."
    elif score >= 66:
        rec = "Good response, but monitor specific frequencies."
    else:
        rec = "Potential hearing concern detected. Recommend full audiologist evaluation."
        
    return LingSixResponse(
        score_percentage=score,
        frequencies_missed=missed,
        recommendation=rec
    )
