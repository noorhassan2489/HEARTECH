from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, date, timedelta
import random
import os
import cloudinary
import cloudinary.utils
import firebase_admin
from firebase_admin import firestore
from auth_dependency import verify_firebase_token
from child_auth import assert_token_uid

router = APIRouter()

db = firestore.client()

# Characters for handover code — exclude confusable chars: 0, O, I, 1
HANDOVER_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


@router.get("/age-bracket/{dob}")
async def get_age_bracket(dob: str):
    """
    Compute age bracket from date of birth string (YYYY-MM-DD).
    Returns bracketId (1-5), bracketLabel, and ageInMonths.
    """
    try:
        birth_date = date.fromisoformat(dob)
    except ValueError:
        return {"error": "Invalid date format. Use YYYY-MM-DD."}

    today = date.today()
    age_months = (today.year - birth_date.year) * 12 + (today.month - birth_date.month)
    if today.day < birth_date.day:
        age_months -= 1

    if age_months <= 6:
        bracket = 1
        label = "0-6 months"
    elif age_months <= 12:
        bracket = 2
        label = "7-12 months"
    elif age_months <= 24:
        bracket = 3
        label = "1-2 years"
    elif age_months <= 60:
        bracket = 4
        label = "3-5 years"
    else:
        bracket = 5
        label = "6-12 years"

    return {
        "bracketId": bracket,
        "bracketLabel": label,
        "ageInMonths": age_months,
    }


class HandoverCodeRequest(BaseModel):
    childId: str
    hcwUid: str


@router.post("/regenerate-handover-code")
async def regenerate_handover_code(request: HandoverCodeRequest, token: dict = Depends(verify_firebase_token)):
    """
    Generate (or regenerate) a 6-character handover code for a child.
    - Verifies hcwUid is in child's hcwIds array
    - Generates 6-char code (excluding 0/O/I/1)
    - Updates Firestore child document with new code, expiry (24h)
    - Returns: newCode, expiresAt
    """
    assert_token_uid(token, request.hcwUid)
    child_ref = db.collection("children").document(request.childId)
    child_doc = child_ref.get()

    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Child not found")

    child_data = child_doc.to_dict()
    hcw_ids = child_data.get("hcwIds", [])

    if request.hcwUid not in hcw_ids:
        raise HTTPException(status_code=403, detail="You are not authorized for this child")

    # Generate 6-character code
    new_code = "".join(random.choices(HANDOVER_CHARS, k=6))

    now = datetime.utcnow()
    expires_at = now + timedelta(hours=24)

    # Update Firestore
    child_ref.update({
        "handoverCode": {
            "code": new_code,
            "createdAt": now,
            "expiresAt": expires_at,
            "used": False,
            "attempts": 0,
            "expiryWarningSent": False,
        }
    })

    return {
        "newCode": new_code,
        "expiresAt": expires_at.isoformat(),
    }


class CloudinarySignatureRequest(BaseModel):
    uploadPreset: Optional[str] = "heartech_unsigned"
    folder: Optional[str] = "heartech/"


@router.post("/cloudinary-signature")
async def cloudinary_signature(
    request: CloudinarySignatureRequest,
    token: dict = Depends(verify_firebase_token),
):
    """
    Generate Cloudinary upload signature for secure uploads.
    Returns: signature, timestamp, cloudName, apiKey
    Never returns apiSecret to the client.
    """
    cloud_name = os.environ.get("CLOUDINARY_CLOUD_NAME", "")
    api_key = os.environ.get("CLOUDINARY_API_KEY", "")
    api_secret = os.environ.get("CLOUDINARY_API_SECRET", "")

    if not cloud_name or not api_key or not api_secret:
        raise HTTPException(
            status_code=500,
            detail="Cloudinary not configured. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET env vars.",
        )

    timestamp = int(datetime.now().timestamp())
    params_to_sign = {
        "timestamp": timestamp,
        "folder": request.folder,
        "upload_preset": request.uploadPreset,
    }

    # Remove None values
    params_to_sign = {k: v for k, v in params_to_sign.items() if v is not None}

    signature = cloudinary.utils.api_sign_request(params_to_sign, api_secret)

    return {
        "signature": signature,
        "timestamp": timestamp,
        "cloudName": cloud_name,
        "apiKey": api_key,
    }
