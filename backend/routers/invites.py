from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_admin import firestore
from datetime import datetime, timedelta
import uuid

router = APIRouter()
db = firestore.client()


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


@router.post("/invite-teacher")
async def invite_teacher(request: InviteTeacherRequest):
    """Send teacher invite. Checks teacher account exists."""
    # Find teacher by email
    teachers = db.collection("users").where(
        "email", "==", request.teacherEmail.strip().lower()
    ).where("role", "==", "teacher").limit(1).stream()

    teacher_doc = None
    for doc in teachers:
        teacher_doc = doc
        break

    if not teacher_doc:
        return {"error": "teacher_not_found"}

    teacher_data = teacher_doc.to_dict()
    invite_id = str(uuid.uuid4())[:8]

    # Get child and parent info
    child_doc = db.collection("children").document(request.childId).get()
    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Child not found")

    child_data = child_doc.to_dict()

    # Get parent info
    parent_uid = child_data.get("parentId", "")
    parent_doc = db.collection("users").document(parent_uid).get()
    parent_name = parent_doc.to_dict().get("name", "") if parent_doc.exists else ""

    invite_data = {
        "inviteId": invite_id,
        "childId": request.childId,
        "childName": child_data.get("name", ""),
        "parentUid": parent_uid,
        "parentName": parent_name,
        "teacherEmail": request.teacherEmail.strip().lower(),
        "teacherUid": teacher_doc.id,
        "status": "pending",
        "createdAt": datetime.now(),
        "expiresAt": datetime.now() + timedelta(hours=72),
        "inviteExpirySent": False,
    }

    db.collection("invites").document(invite_id).set(invite_data)

    return {"inviteId": invite_id}


@router.post("/respond-invite")
async def respond_invite(request: RespondInviteRequest):
    """Accept or decline a teacher invite."""
    invite_ref = db.collection("invites").document(request.inviteId)
    invite_doc = invite_ref.get()

    if not invite_doc.exists:
        raise HTTPException(status_code=404, detail="Invite not found")

    invite_data = invite_doc.to_dict()

    if invite_data.get("status") != "pending":
        return {"error": "invite_not_pending"}

    if request.action == "accept":
        # Batch write
        batch = db.batch()
        batch.update(invite_ref, {"status": "accepted"})

        child_ref = db.collection("children").document(invite_data["childId"])
        batch.update(child_ref, {
            "teacherIds": firestore.ArrayUnion([invite_data["teacherUid"]])
        })

        teacher_ref = db.collection("users").document(invite_data["teacherUid"])
        batch.update(teacher_ref, {
            "linkedChildIds": firestore.ArrayUnion([invite_data["childId"]])
        })

        batch.commit()

    elif request.action == "decline":
        invite_ref.update({"status": "declined"})

    return {"success": True}


@router.get("/pending-invites")
async def get_pending_invites(teacherUid: str):
    """Get all pending invites for a teacher."""
    invites = db.collection("invites").where(
        "teacherUid", "==", teacherUid
    ).where("status", "==", "pending").stream()

    result = []
    for doc in invites:
        data = doc.to_dict()
        # Convert timestamps to strings
        for key in ["createdAt", "expiresAt"]:
            if key in data and hasattr(data[key], 'isoformat'):
                data[key] = data[key].isoformat()
        result.append(data)

    return result


@router.post("/cancel-invite")
async def cancel_invite(request: CancelInviteRequest):
    """Cancel a pending invite."""
    db.collection("invites").document(request.inviteId).update({
        "status": "cancelled"
    })
    return {"success": True}


@router.post("/remove-hcw")
async def remove_hcw(request: RemoveHcwRequest):
    """Remove HCW from child's profile."""
    child_ref = db.collection("children").document(request.childId)
    child_ref.update({
        "hcwIds": firestore.ArrayRemove([request.hcwId])
    })
    return {"success": True}


@router.post("/remove-teacher")
async def remove_teacher(request: RemoveTeacherRequest):
    """Remove teacher from child profile (teacher self-removal)."""
    # This needs the teacher UID from the JWT token
    # For now, placeholder
    return {"success": True}
