from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, auth as firebase_auth, firestore
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / ".env")

# ═══════════════════════════════════════════════════════════════════════════════
# HEARTECH FASTAPI — Main application entry point
# ═══════════════════════════════════════════════════════════════════════════════

if not firebase_admin._apps:
    if os.path.exists("service-account-key.json"):
        cred = credentials.Certificate("service-account-key.json")
        firebase_admin.initialize_app(cred)
    else:
        firebase_admin.initialize_app()

db = firestore.client()

app = FastAPI(
    title="HearTech API",
    description="Backend API for HearTech — Early childhood hearing screening",
    version="1.0.0",
)

# CORS — allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ═══════════════════════════════════════════════════════════════════════════════
# JWT VERIFICATION MIDDLEWARE
# ═══════════════════════════════════════════════════════════════════════════════

from auth_dependency import verify_firebase_token


# ═══════════════════════════════════════════════════════════════════════════════
# HEALTH CHECK
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "heartech-api"}


# ═══════════════════════════════════════════════════════════════════════════════
# ROUTERS — imported from separate files
# ═══════════════════════════════════════════════════════════════════════════════

from routers.risk_score import router as risk_score_router
from routers.referral import router as referral_router
from routers.speech import router as speech_router
from routers.utils import router as utils_router
from routers.notifications import router as notifications_router
from routers.profile import router as profile_router
from routers.invites import router as invites_router
from routers.questionnaires import router as questionnaires_router
from services.referral_ai_service import ReferralAIService

_protected = [Depends(verify_firebase_token)]

app.include_router(risk_score_router, prefix="/api", tags=["Risk Scoring"], dependencies=_protected)
app.include_router(referral_router, prefix="/api", tags=["Referrals"], dependencies=_protected)
app.include_router(speech_router, prefix="/api", tags=["Speech Analysis"], dependencies=_protected)
app.include_router(utils_router, prefix="/api", tags=["Utilities"])
app.include_router(notifications_router, prefix="/api", tags=["Notifications"], dependencies=_protected)
app.include_router(profile_router, prefix="/api", tags=["Profile Management"], dependencies=_protected)
app.include_router(invites_router, prefix="/api", tags=["Invites"], dependencies=_protected)
app.include_router(questionnaires_router, prefix="/api", tags=["Questionnaires"])


# ═══════════════════════════════════════════════════════════════════════════════
# CRON JOBS — APScheduler
# ═══════════════════════════════════════════════════════════════════════════════

from cron_jobs import setup_cron_jobs

@app.on_event("startup")
async def startup():
    setup_cron_jobs()

    # Whisper loads on first speech request — keeps GPU RAM free for referral chat.
    app.state.whisper_model = None
    app.state.whisper_load_attempted = False
    print("[STARTUP] Whisper deferred (loads on first speech analysis request).")

    import shutil
    if shutil.which("ffmpeg"):
        print("[STARTUP] ffmpeg found — speech transcription ready.")
    else:
        print("[STARTUP] WARNING: ffmpeg not found. Install with: brew install ffmpeg")

    # Referral model loads lazily on first chat request to avoid Metal OOM with Whisper.
    try:
        ReferralAIService.get_instance()
        print("[STARTUP] ReferralAIService ready (model loads on first chat request).")
    except Exception as e:
        print(f"[STARTUP] WARNING: Failed to initialize ReferralAIService: {e}")
