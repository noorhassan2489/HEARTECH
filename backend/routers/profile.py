from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import string
import random
from datetime import datetime, timedelta
from firebase_admin import firestore

router = APIRouter()
db = firestore.client()

# Characters for handover codes (no 0, O, I, 1)
CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def generate_code(length=6):
    return "".join(random.choices(CODE_CHARS, k=length))


class ClaimProfileRequest(BaseModel):
    code: str


class RegenerateCodeRequest(BaseModel):
    childId: str


class InviteTeacherRequest(BaseModel):
    childId: str
    teacherEmail: str


class RespondInviteRequest(BaseModel):
    inviteId: str
    action: str  # "accept" or "decline"


class CancelInviteRequest(BaseModel):
    inviteId: str


class RemoveHcwRequest(BaseModel):
    childId: str
    hcwId: str


class RemoveTeacherRequest(BaseModel):
    childId: str


@router.post("/claim-profile")
async def claim_profile(request: ClaimProfileRequest):
    """Validate handover code and link child to parent."""
    code = request.code.upper().strip()

    # Find child with this handover code
    children_ref = db.collection("children")
    query = children_ref.where("handoverCode.code", "==", code).limit(1).stream()

    child_doc = None
    for doc in query:
        child_doc = doc
        break

    if not child_doc:
        return {"error": "invalid_code", "message": "Code not found."}

    child_data = child_doc.to_dict()
    handover = child_data.get("handoverCode", {})

    # Check if already used
    if handover.get("used", False):
        return {"error": "already_used", "message": "This code has already been used."}

    # Check expiry
    expires_at = handover.get("expiresAt")
    if expires_at and hasattr(expires_at, 'timestamp'):
        if datetime.now().timestamp() > expires_at.timestamp():
            return {"error": "expired", "message": "This code has expired."}

    # Check attempts
    attempts = handover.get("attempts", 0)
    if attempts >= 5:
        return {"error": "too_many_attempts", "message": "Too many attempts."}

    return {
        "childId": child_doc.id,
        "childName": child_data.get("name", ""),
        "riskLevel": child_data.get("riskLevel", "low"),
    }


@router.post("/regenerate-handover-code")
async def regenerate_handover_code(request: RegenerateCodeRequest):
    """Generate a new handover code for a child."""
    new_code = generate_code()
    now = datetime.now()
    expires_at = now + timedelta(hours=24)

    db.collection("children").document(request.childId).update({
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
