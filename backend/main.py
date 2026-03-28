from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, auth as firebase_auth, firestore
import os

# ═══════════════════════════════════════════════════════════════════════════════
# HEARTECH FASTAPI — Main application entry point
# ═══════════════════════════════════════════════════════════════════════════════

# Initialize Firebase Admin SDK
if not firebase_admin._apps:
    # Use default credentials (for Cloud Run) or service account key
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

async def verify_firebase_token(request: Request):
    """Verify Firebase JWT on every endpoint except GET /health."""
    if request.url.path == "/health" and request.method == "GET":
        return None

    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing auth token")

    token = auth_header.split("Bearer ")[1]
    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid auth token")


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

app.include_router(risk_score_router, prefix="/api", tags=["Risk Scoring"])
app.include_router(referral_router, prefix="/api", tags=["Referrals"])
app.include_router(speech_router, prefix="/api", tags=["Speech Analysis"])
app.include_router(utils_router, prefix="/api", tags=["Utilities"])
app.include_router(notifications_router, prefix="/api", tags=["Notifications"])
app.include_router(profile_router, prefix="/api", tags=["Profile Management"])
app.include_router(invites_router, prefix="/api", tags=["Invites"])
app.include_router(questionnaires_router, prefix="/api", tags=["Questionnaires"])


# ═══════════════════════════════════════════════════════════════════════════════
# CRON JOBS — APScheduler
# ═══════════════════════════════════════════════════════════════════════════════

from cron_jobs import setup_cron_jobs

@app.on_event("startup")
async def startup():
    setup_cron_jobs()
