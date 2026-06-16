from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import datetime, timezone
from firebase_admin import firestore
from auth_dependency import verify_firebase_token
from services.notification_service import NotificationService

router = APIRouter()
db = firestore.client()


class ClaimProfileRequest(BaseModel):
    code: str
    parentUid: str


@router.post("/claim-profile")
async def claim_profile(body: ClaimProfileRequest, token: dict = Depends(verify_firebase_token)):
    """Validate handover code and link child to parent.

    Step 1: Verify JWT — uid in token must match parentUid in body
    Step 2: Search for child by handoverCode.code (case-insensitive)
    Step 3: Validate code (not expired, not used, attempts < 5)
    Step 4: Batch write — set parentId + handoverCode.used + linkedChildIds
    Step 5: Fire HCW-02 notification
    Step 6: Return success
    """
    token_uid = token.get("uid", "")
    if token_uid != body.parentUid:
        raise HTTPException(status_code=401, detail="UID mismatch")

    code = body.code.upper().strip()
    parent_uid = body.parentUid

    # Step 2 — Search for child with this code
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
    attempts = handover.get("attempts", 0)
    if attempts >= 5:
        return {"error": "rate_limited"}

    if handover.get("used", False):
        db.collection("children").document(child_id).update({
            "handoverCode.attempts": firestore.Increment(1)
        })
        return {"error": "already_used"}

    expires_at = handover.get("expiresAt")
    if expires_at:
        now_ts = datetime.now(timezone.utc).timestamp()
        if hasattr(expires_at, 'timestamp'):
            exp_ts = expires_at.timestamp()
        elif isinstance(expires_at, datetime):
            exp_ts = expires_at.timestamp()
        else:
            exp_ts = now_ts + 1

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
        await NotificationService.send(
            uid=hcw_ids[0],
            notif_type="HCW-02",
            title="Profile Claimed",
            body=f"A parent has claimed {child_name}'s profile.",
            related_child_id=child_id,
            navigation_route=f"/hcw/child/{child_id}",
        )

    return {
        "childId": child_id,
        "childName": child_name,
        "riskLevel": child_data.get("riskLevel", "low"),
    }
