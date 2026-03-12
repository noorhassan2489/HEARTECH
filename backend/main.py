import os
import firebase_admin
from firebase_admin import credentials
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from routers import notifications, risk_score, referral, speech, utils
from cron_jobs import start_cron_jobs

# Initialize Firebase Admin SDK
# Provide path to service account key file in an env variable or standard path in production
# For development, assuming standard app default or explicit file later
try:
    if not firebase_admin._apps:
        # Use application default credentials or explicitly load from json
        cred = credentials.Certificate(os.environ.get("FIREBASE_SERVICE_ACCOUNT", "serviceAccountKey.json"))
        firebase_admin.initialize_app(cred)
except Exception as e:
    print(f"Firebase Admin Initialization Error/Warning: {e}")
    # Fallback init for testing without credentials
    if not firebase_admin._apps:
        firebase_admin.initialize_app()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start APScheduler cron jobs on startup
    scheduler = start_cron_jobs()
    yield
    # Shutdown gracefully
    if scheduler:
        scheduler.shutdown()

app = FastAPI(title="HearTech API", lifespan=lifespan)

# Allow CORS for Flutter Web/Local dev if needed
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(notifications.router, prefix="/api", tags=["Notifications"])
app.include_router(risk_score.router, prefix="/api", tags=["Risk Assessment"])
app.include_router(referral.router, prefix="/api", tags=["Referrals"])
app.include_router(speech.router, prefix="/api", tags=["Speech & AI"])
app.include_router(utils.router, prefix="/api", tags=["Utilities"])

@app.get("/")
def read_root():
    return {"message": "HearTech FastAPI App Running"}
