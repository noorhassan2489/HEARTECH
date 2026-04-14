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
    parentUid: str


class RegenerateCodeRequest(BaseModel):
    childId: str


@router.post("/claim-profile")
async def claim_profile(request: ClaimProfileRequest):
    """Validate handover code and link child to parent.

    Phase 4 spec:
      - Query children where handoverCode.code == code
      - Validate: exists, not expired, not used, attempts < 5
      - On fail: increment attempts, return error
      - On success: batch write parentId, handoverCode.used,
        linkedChildIds on parent user doc
      - Fire HCW-02 notification to HCW
    """
    code = request.code.upper().strip()
    parent_uid = request.parentUid

    # Find child with this handover code
    children_ref = db.collection("children")
    query = children_ref.where("handoverCode.code", "==", code).limit(1).stream()

    child_doc = None
    for doc in query:
        child_doc = doc
        break

    if not child_doc:
        return {"error": "invalid"}

    child_data = child_doc.to_dict()
    child_id = child_doc.id
    handover = child_data.get("handoverCode", {})

    # Check attempts (rate limit)
    attempts = handover.get("attempts", 0)
    if attempts >= 5:
        return {"error": "rate_limited"}

    # Check if already used
    if handover.get("used", False):
        # Still increment attempts
        db.collection("children").document(child_id).update({
            "handoverCode.attempts": firestore.Increment(1)
        })
        return {"error": "already_used"}

    # Check expiry
    expires_at = handover.get("expiresAt")
    if expires_at:
        if hasattr(expires_at, 'timestamp'):
            if datetime.now().timestamp() > expires_at.timestamp():
                db.collection("children").document(child_id).update({
                    "handoverCode.attempts": firestore.Increment(1)
                })
                return {"error": "expired"}

    # ── SUCCESS — batch write ──
    batch = db.batch()

    child_ref = db.collection("children").document(child_id)
    batch.update(child_ref, {
        "parentId": parent_uid,
        "handoverCode.used": True,
        "lastUpdatedAt": datetime.now(),
    })

    parent_ref = db.collection("users").document(parent_uid)
    batch.update(parent_ref, {
        "linkedChildIds": firestore.ArrayUnion([child_id])
    })

    batch.commit()

    # Fire HCW-02: Parent claimed child profile → to HCW
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

    return {
        "childId": child_id,
        "childName": child_name,
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


def _fire_notification(uid: str, notif_type: str, title: str, body: str,
                        priority: str = "normal", related_child_id: str = ""):
    """Write notification directly to Firestore."""
    import uuid
    notif_id = str(uuid.uuid4())[:8]
    db.collection("notifications").document(uid).collection("items").document(notif_id).set({
        "type": notif_type,
        "title": title,
        "body": body,
        "read": False,
        "priority": priority,
        "createdAt": datetime.now(),
        "relatedChildId": related_child_id,
    })
