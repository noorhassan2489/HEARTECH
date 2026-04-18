from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import Optional
import string
import random
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore, auth as firebase_auth
import uuid

router = APIRouter()
db = firestore.client()

# Characters for handover codes (no 0, O, I, 1)
CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def generate_code(length=6):
    return "".join(random.choices(CODE_CHARS, k=length))


class ClaimProfileRequest(BaseModel):
    code: str
    parentUid: str


class RegenerateCodeRequest(BaseModel):
    childId: str


def _verify_jwt(request: Request) -> dict:
    """Extract and verify Firebase JWT from Authorization header."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing auth token")
    token = auth_header.split("Bearer ")[1]
    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid auth token")


@router.post("/claim-profile")
async def claim_profile(request: Request, body: ClaimProfileRequest):
    """Validate handover code and link child to parent.

    Step 1: Verify JWT — uid in token must match parentUid in body
    Step 2: Search for child by handoverCode.code (case-insensitive)
    Step 3: Validate code (not expired, not used, attempts < 5)
    Step 4: Batch write — set parentId + handoverCode.used + linkedChildIds
    Step 5: Fire HCW-02 notification
    Step 6: Return success
    """
    # Step 1 — Verify JWT
    decoded_token = _verify_jwt(request)
    token_uid = decoded_token.get("uid", "")
    if token_uid != body.parentUid:
        raise HTTPException(status_code=401, detail="UID mismatch")

    code = body.code.upper().strip()
    parent_uid = body.parentUid

    # Step 2 — Search for child with this code
    # Iterate all children and match in Python to avoid needing a composite index.
    # This is safe for development; for production, create a single-field index
    # on handoverCode.code and switch to a .where() query.
    children_ref = db.collection("children")
    all_children = children_ref.stream()

    child_doc = None
    for doc in all_children:
        data = doc.to_dict()
        handover = data.get("handoverCode")
        if handover and isinstance(handover, dict):
            stored_code = handover.get("code", "")
            if isinstance(stored_code, str) and stored_code.upper() == code:
                child_doc = doc
                break

    if not child_doc:
        return {"error": "invalid"}

    child_data = child_doc.to_dict()
    child_id = child_doc.id
    handover = child_data.get("handoverCode", {})

    # Step 3 — Validate the code
    # 3a: Check attempts (rate limit)
    attempts = handover.get("attempts", 0)
    if attempts >= 5:
        return {"error": "rate_limited"}

    # 3b: Check if already used
    if handover.get("used", False):
        db.collection("children").document(child_id).update({
            "handoverCode.attempts": firestore.Increment(1)
        })
        return {"error": "already_used"}

    # 3c: Check expiry — compare in UTC
    expires_at = handover.get("expiresAt")
    if expires_at:
        # Firestore Timestamps have a .timestamp() method
        now_ts = datetime.now(timezone.utc).timestamp()
        if hasattr(expires_at, 'timestamp'):
            exp_ts = expires_at.timestamp()
        elif isinstance(expires_at, datetime):
            exp_ts = expires_at.timestamp()
        else:
            exp_ts = now_ts + 1  # If format unknown, don't block

        if now_ts > exp_ts:
            db.collection("children").document(child_id).update({
                "handoverCode.attempts": firestore.Increment(1)
            })
            return {"error": "expired"}

    # Step 4 — Claim the profile (batch write — atomic)
    batch = db.batch()

    child_ref = db.collection("children").document(child_id)
    batch.update(child_ref, {
        "parentId": parent_uid,
        "handoverCode.used": True,
        "lastUpdatedAt": datetime.now(timezone.utc),
    })

    parent_ref = db.collection("users").document(parent_uid)
    batch.update(parent_ref, {
        "linkedChildIds": firestore.ArrayUnion([child_id])
    })

    batch.commit()

    # Step 5 — Fire HCW-02 notification
    hcw_ids = child_data.get("hcwIds", [])
    child_name = child_data.get("name", "")
    if hcw_ids:
        _fire_notification(
            uid=hcw_ids[0],
            notif_type="HCW-02",
            title="Profile Claimed",
            body=f"A parent has claimed {child_name}'s profile.",
            related_child_id=child_id,
        )

    # Step 6 — Return success
    return {
        "childId": child_id,
        "childName": child_name,
        "riskLevel": child_data.get("riskLevel", "low"),
    }


@router.post("/regenerate-handover-code")
async def regenerate_handover_code(body: RegenerateCodeRequest):
    """Generate a new handover code for a child."""
    new_code = generate_code()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(hours=24)

    db.collection("children").document(body.childId).update({
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


def _fire_notification(uid: str, notif_type: str, title: str, body: str,
                        priority: str = "normal", related_child_id: str = ""):
    """Write notification directly to Firestore."""
    notif_id = str(uuid.uuid4())[:8]
    db.collection("notifications").document(uid).collection("items").document(notif_id).set({
        "type": notif_type,
        "title": title,
        "body": body,
        "read": False,
        "priority": priority,
        "createdAt": datetime.now(timezone.utc),
        "relatedChildId": related_child_id,
    })
