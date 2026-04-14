from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_admin import firestore
from datetime import datetime, timedelta
import uuid

router = APIRouter()
db = firestore.client()


def _fire_notification(uid: str, notif_type: str, title: str, body: str,
                        priority: str = "normal", related_child_id: str = "",
                        navigation_route: str = ""):
    """Write notification directly to Firestore."""
    notif_id = str(uuid.uuid4())[:8]
    data = {
        "type": notif_type,
        "title": title,
        "body": body,
        "read": False,
        "priority": priority,
        "createdAt": datetime.now(),
        "relatedChildId": related_child_id,
    }
    if navigation_route:
        data["navigationRoute"] = navigation_route
    db.collection("notifications").document(uid).collection("items").document(notif_id).set(data)


# ═══════════════════════════════════════════════════════════════════════════════
# REQUEST MODELS
# ═══════════════════════════════════════════════════════════════════════════════


class InviteTeacherRequest(BaseModel):
    childId: str
    parentUid: str
    teacherEmail: str


class RespondInviteRequest(BaseModel):
    inviteId: str
    action: str  # "accept" or "decline"


class CancelInviteRequest(BaseModel):
    inviteId: str
    parentUid: str


class RemoveHcwRequest(BaseModel):
    childId: str
    parentUid: str
    hcwId: str


class RemoveTeacherRequest(BaseModel):
    childId: str
    parentUid: str
    teacherUid: str


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/invite-teacher
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/invite-teacher")
async def invite_teacher(request: InviteTeacherRequest):
    """Send teacher invite. Verify parentUid matches child.parentId."""
    # Verify parent owns this child
    child_doc = db.collection("children").document(request.childId).get()
    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Child not found")

    child_data = child_doc.to_dict()
    if child_data.get("parentId") != request.parentUid:
        raise HTTPException(status_code=403, detail="Not authorized")

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

    # Get parent info
    parent_doc = db.collection("users").document(request.parentUid).get()
    parent_name = parent_doc.to_dict().get("name", "") if parent_doc.exists else ""

    invite_data = {
        "inviteId": invite_id,
        "childId": request.childId,
        "childName": child_data.get("name", ""),
        "parentUid": request.parentUid,
        "parentName": parent_name,
        "teacherEmail": request.teacherEmail.strip().lower(),
        "teacherUid": teacher_doc.id,
        "status": "pending",
        "createdAt": datetime.now(),
        "expiresAt": datetime.now() + timedelta(hours=72),
        "inviteExpirySent": False,
    }

    db.collection("invites").document(invite_id).set(invite_data)

    # Fire TCH-01: New invite received → to Teacher
    _fire_notification(
        uid=teacher_doc.id,
        notif_type="TCH-01",
        title="New Invite",
        body=f"{parent_name} has invited you to observe {child_data.get('name', '')}.",
        related_child_id=request.childId,
    )

    return {"inviteId": invite_id}


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/respond-invite
# ═══════════════════════════════════════════════════════════════════════════════


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

    child_id = invite_data["childId"]
    teacher_uid = invite_data["teacherUid"]
    parent_uid = invite_data.get("parentUid", "")
    child_name = invite_data.get("childName", "")

    if request.action == "accept":
        # Batch write
        batch = db.batch()
        batch.update(invite_ref, {"status": "accepted"})

        child_ref = db.collection("children").document(child_id)
        batch.update(child_ref, {
            "teacherIds": firestore.ArrayUnion([teacher_uid])
        })

        teacher_ref = db.collection("users").document(teacher_uid)
        batch.update(teacher_ref, {
            "linkedChildIds": firestore.ArrayUnion([child_id])
        })

        batch.commit()

        # Fire HCW-03: Teacher linked to patient → to HCW
        child_data = db.collection("children").document(child_id).get().to_dict()
        hcw_ids = child_data.get("hcwIds", []) if child_data else []
        if hcw_ids:
            teacher_name = db.collection("users").document(teacher_uid).get().to_dict().get("name", "Teacher")
            _fire_notification(
                uid=hcw_ids[0],
                notif_type="HCW-03",
                title="Teacher Linked",
                body=f"{teacher_name} has been linked to {child_name}'s profile.",
                related_child_id=child_id,
            )

        # Fire PAR-05: Teacher accepted invite → to Parent
        if parent_uid:
            _fire_notification(
                uid=parent_uid,
                notif_type="PAR-05",
                title="Teacher Accepted",
                body=f"A teacher has accepted your invite for {child_name}.",
                related_child_id=child_id,
            )

    elif request.action == "decline":
        invite_ref.update({"status": "declined"})

        # Fire PAR-06: Teacher declined invite → to Parent
        if parent_uid:
            _fire_notification(
                uid=parent_uid,
                notif_type="PAR-06",
                title="Invite Declined",
                body=f"The teacher declined your invite for {child_name}.",
                related_child_id=child_id,
            )

    return {"success": True}


# ═══════════════════════════════════════════════════════════════════════════════
# GET /api/pending-invites
# ═══════════════════════════════════════════════════════════════════════════════


@router.get("/pending-invites")
async def get_pending_invites(teacherUid: str = "", parentUid: str = ""):
    """Get all pending invites for a teacher OR parent."""
    if teacherUid:
        invites = db.collection("invites").where(
            "teacherUid", "==", teacherUid
        ).where("status", "==", "pending").stream()
    elif parentUid:
        invites = db.collection("invites").where(
            "parentUid", "==", parentUid
        ).where("status", "==", "pending").stream()
    else:
        return []

    result = []
    for doc in invites:
        data = doc.to_dict()
        # Convert timestamps to ISO strings
        for key in ["createdAt", "expiresAt"]:
            if key in data and hasattr(data[key], 'isoformat'):
                data[key] = data[key].isoformat()
        result.append(data)

    return result


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/cancel-invite
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/cancel-invite")
async def cancel_invite(request: CancelInviteRequest):
    """Cancel a pending invite. Verify parentUid matches."""
    invite_ref = db.collection("invites").document(request.inviteId)
    invite_doc = invite_ref.get()

    if not invite_doc.exists:
        raise HTTPException(status_code=404, detail="Invite not found")

    invite_data = invite_doc.to_dict()
    if invite_data.get("parentUid") != request.parentUid:
        raise HTTPException(status_code=403, detail="Not authorized")

    invite_ref.update({"status": "cancelled"})
    return {"success": True}


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/remove-hcw
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/remove-hcw")
async def remove_hcw(request: RemoveHcwRequest):
    """Remove HCW from child's profile. Verify parentUid matches."""
    child_ref = db.collection("children").document(request.childId)
    child_doc = child_ref.get()

    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Child not found")

    child_data = child_doc.to_dict()
    if child_data.get("parentId") != request.parentUid:
        raise HTTPException(status_code=403, detail="Not authorized")

    child_ref.update({
        "hcwIds": firestore.ArrayRemove([request.hcwId])
    })

    # Fire HCW-09: Parent removed HCW access → to HCW
    child_name = child_data.get("name", "")
    _fire_notification(
        uid=request.hcwId,
        notif_type="HCW-09",
        title="Access Removed",
        body=f"A parent has removed your access to {child_name}'s profile.",
        related_child_id=request.childId,
    )

    return {"success": True}


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/remove-teacher
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/remove-teacher")
async def remove_teacher(request: RemoveTeacherRequest):
    """Remove teacher from child profile. Verify parentUid matches.

    - Remove teacherUid from child.teacherIds
    - Remove childId from users/{teacherUid}.linkedChildIds
    - Fire TCH-06 push to teacher
    - Fire PAR-10 in-app only to parent (no push)
    """
    child_ref = db.collection("children").document(request.childId)
    child_doc = child_ref.get()

    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Child not found")

    child_data = child_doc.to_dict()
    if child_data.get("parentId") != request.parentUid:
        raise HTTPException(status_code=403, detail="Not authorized")

    batch = db.batch()

    # Remove teacher from child
    batch.update(child_ref, {
        "teacherIds": firestore.ArrayRemove([request.teacherUid])
    })

    # Remove child from teacher's linkedChildIds
    teacher_ref = db.collection("users").document(request.teacherUid)
    batch.update(teacher_ref, {
        "linkedChildIds": firestore.ArrayRemove([request.childId])
    })

    batch.commit()

    child_name = child_data.get("name", "")

    # Fire TCH-06: Parent removed teacher access → to Teacher (push)
    _fire_notification(
        uid=request.teacherUid,
        notif_type="TCH-06",
        title="Access Removed",
        body=f"A parent has removed your access to {child_name}'s profile.",
        related_child_id=request.childId,
    )

    # Fire PAR-10: Teacher unlinked → to Parent (IN-APP ONLY, no push)
    _fire_notification(
        uid=request.parentUid,
        notif_type="PAR-10",
        title="Teacher Unlinked",
        body=f"The teacher has been removed from {child_name}'s profile.",
        related_child_id=request.childId,
    )

    return {"success": True}
