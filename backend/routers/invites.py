from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from firebase_admin import firestore
from datetime import datetime, timedelta
import uuid

from auth_dependency import verify_firebase_token
from child_auth import assert_child_access, assert_token_uid, delete_child_tree, get_child_data
from services.notification_service import NotificationService

router = APIRouter()
db = firestore.client()


# ═══════════════════════════════════════════════════════════════════════════════
# REQUEST MODELS
# ═══════════════════════════════════════════════════════════════════════════════


class InviteTeacherRequest(BaseModel):
    childId: str
    parentUid: str
    teacherEmail: str


class InviteHcwRequest(BaseModel):
    childId: str
    parentUid: str
    hcwEmail: str


class RespondInviteRequest(BaseModel):
    inviteId: str
    action: str  # "accept" or "decline"
    teacherUid: str = ""
    hcwUid: str = ""


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


class HcwDeleteChildRequest(BaseModel):
    childId: str
    hcwUid: str


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/invite-teacher
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/invite-teacher")
async def invite_teacher(request: InviteTeacherRequest, token: dict = Depends(verify_firebase_token)):
    """Send teacher invite. Verify parentUid matches child.parentId."""
    assert_token_uid(token, request.parentUid)
    child_data = assert_child_access(request.parentUid, request.childId)

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
        "inviteType": "teacher",
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
    await NotificationService.send(
        uid=teacher_doc.id,
        notif_type="TCH-01",
        title="New Invite",
        body=f"{parent_name} has invited you to observe {child_data.get('name', '')}.",
        related_child_id=request.childId,
        related_invite_id=invite_id,
        navigation_route="/teacher/invites",
    )

    return {"inviteId": invite_id}


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/invite-hcw
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/invite-hcw")
async def invite_hcw(request: InviteHcwRequest, token: dict = Depends(verify_firebase_token)):
    """Parent invites an HCW to link to an already-claimed child profile."""
    assert_token_uid(token, request.parentUid)
    child_data = assert_child_access(request.parentUid, request.childId)
    if child_data.get("parentId") != request.parentUid:
        raise HTTPException(status_code=403, detail="Not authorized")

    hcw_ids = child_data.get("hcwIds") or []
    if hcw_ids:
        return {"error": "hcw_already_linked"}

    hcws = db.collection("users").where(
        "email", "==", request.hcwEmail.strip().lower()
    ).where("role", "==", "hcw").limit(1).stream()

    hcw_doc = None
    for doc in hcws:
        hcw_doc = doc
        break

    if not hcw_doc:
        return {"error": "hcw_not_found"}

    # One pending HCW invite per child
    existing = db.collection("invites").where(
        "childId", "==", request.childId
    ).where("inviteType", "==", "hcw").where(
        "status", "==", "pending"
    ).limit(1).stream()
    for _ in existing:
        return {"error": "invite_already_pending"}

    invite_id = str(uuid.uuid4())[:8]
    parent_doc = db.collection("users").document(request.parentUid).get()
    parent_name = parent_doc.to_dict().get("name", "") if parent_doc.exists else ""
    child_name = child_data.get("name", "")

    invite_data = {
        "inviteId": invite_id,
        "inviteType": "hcw",
        "childId": request.childId,
        "childName": child_name,
        "parentUid": request.parentUid,
        "parentName": parent_name,
        "hcwEmail": request.hcwEmail.strip().lower(),
        "hcwUid": hcw_doc.id,
        "status": "pending",
        "createdAt": datetime.now(),
        "expiresAt": datetime.now() + timedelta(hours=72),
        "inviteExpirySent": False,
    }

    db.collection("invites").document(invite_id).set(invite_data)

    await NotificationService.send(
        uid=hcw_doc.id,
        notif_type="HCW-11",
        title="New Patient Invite",
        body=f"{parent_name} has invited you to care for {child_name}.",
        related_child_id=request.childId,
        related_invite_id=invite_id,
        navigation_route="/hcw/invites",
    )

    return {"inviteId": invite_id}


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/respond-invite
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/respond-invite")
async def respond_invite(request: RespondInviteRequest, token: dict = Depends(verify_firebase_token)):
    """Accept or decline a teacher invite.
    
    Validates:
    - Invite exists and is pending
    - teacherUid matches the invite's teacherUid
    - Invite is not expired
    """
    invite_ref = db.collection("invites").document(request.inviteId)
    invite_doc = invite_ref.get()

    if not invite_doc.exists:
        raise HTTPException(status_code=404, detail="Invite not found")

    invite_data = invite_doc.to_dict()

    if invite_data.get("status") != "pending":
        return {"error": "invite_not_pending"}

    invite_type = invite_data.get("inviteType", "teacher")

    if invite_type == "hcw":
        stored_hcw_uid = invite_data.get("hcwUid", "")
        hcw_uid = request.hcwUid or stored_hcw_uid
        assert_token_uid(token, hcw_uid)
        if stored_hcw_uid != hcw_uid:
            raise HTTPException(status_code=403, detail="Not authorized")
    else:
        stored_teacher_uid = invite_data.get("teacherUid", "")
        teacher_uid = request.teacherUid or stored_teacher_uid
        assert_token_uid(token, teacher_uid)
        if stored_teacher_uid != teacher_uid:
            raise HTTPException(status_code=403, detail="Not authorized")

    # Check expiry
    expires_at = invite_data.get("expiresAt")
    if expires_at:
        if hasattr(expires_at, 'timestamp'):
            if datetime.now().timestamp() > expires_at.timestamp():
                invite_ref.update({"status": "expired"})
                return {"error": "invite_expired"}

    child_id = invite_data["childId"]
    parent_uid = invite_data.get("parentUid", "")
    child_name = invite_data.get("childName", "")

    if request.action == "accept":
        batch = db.batch()
        batch.update(invite_ref, {"status": "accepted"})

        child_ref = db.collection("children").document(child_id)

        if invite_type == "hcw":
            batch.update(child_ref, {
                "hcwIds": firestore.ArrayUnion([hcw_uid]),
                "lastUpdatedAt": datetime.now(),
            })
        else:
            batch.update(child_ref, {
                "teacherIds": firestore.ArrayUnion([teacher_uid])
            })
            teacher_ref = db.collection("users").document(teacher_uid)
            batch.update(teacher_ref, {
                "linkedChildIds": firestore.ArrayUnion([child_id])
            })

        batch.commit()

        if invite_type == "hcw":
            hcw_name = db.collection("users").document(hcw_uid).get().to_dict().get("name", "Healthcare worker")
            if parent_uid:
                await NotificationService.send(
                    uid=parent_uid,
                    notif_type="PAR-04",
                    title="Healthcare Worker Linked",
                    body=f"{hcw_name} has accepted your invite for {child_name}.",
                    related_child_id=child_id,
                    navigation_route=f"/parent/child/{child_id}",
                )
        else:
            # Fire HCW-03: Teacher linked to patient → to HCW
            child_data = db.collection("children").document(child_id).get().to_dict()
            hcw_ids = child_data.get("hcwIds", []) if child_data else []
            if hcw_ids:
                teacher_name = db.collection("users").document(teacher_uid).get().to_dict().get("name", "Teacher")
                await NotificationService.send(
                    uid=hcw_ids[0],
                    notif_type="HCW-03",
                    title="Teacher Linked",
                    body=f"{teacher_name} has been linked to {child_name}'s profile.",
                    related_child_id=child_id,
                    navigation_route=f"/hcw/child/{child_id}",
                )

            # Fire PAR-04: Teacher accepted invite → to Parent
            if parent_uid:
                await NotificationService.send(
                    uid=parent_uid,
                    notif_type="PAR-04",
                    title="Teacher Accepted",
                    body=f"A teacher has accepted your invite for {child_name}.",
                    related_child_id=child_id,
                    navigation_route=f"/parent/child/{child_id}",
                )

    elif request.action == "decline":
        invite_ref.update({"status": "declined"})

        if invite_type == "hcw":
            if parent_uid:
                await NotificationService.send(
                    uid=parent_uid,
                    notif_type="PAR-05",
                    title="Invite Declined",
                    body=f"The healthcare worker declined your invite for {child_name}.",
                    related_child_id=child_id,
                    navigation_route=f"/parent/child/{child_id}",
                )
        elif parent_uid:
            # Fire PAR-05: Teacher declined invite → to Parent
            await NotificationService.send(
                uid=parent_uid,
                notif_type="PAR-05",
                title="Invite Declined",
                body=f"The teacher declined your invite for {child_name}.",
                related_child_id=child_id,
                navigation_route=f"/parent/child/{child_id}",
            )

    return {"success": True}


# ═══════════════════════════════════════════════════════════════════════════════
# GET /api/pending-invites
# ═══════════════════════════════════════════════════════════════════════════════


@router.get("/pending-invites")
async def get_pending_invites(
    teacherUid: str = "",
    hcwUid: str = "",
    parentUid: str = "",
    token: dict = Depends(verify_firebase_token),
):
    """Get all pending invites for a teacher, HCW, or parent."""
    if teacherUid:
        assert_token_uid(token, teacherUid)
        invites = db.collection("invites").where(
            "teacherUid", "==", teacherUid
        ).where("status", "==", "pending").stream()
    elif hcwUid:
        assert_token_uid(token, hcwUid)
        invites = db.collection("invites").where(
            "hcwUid", "==", hcwUid
        ).where("status", "==", "pending").stream()
    elif parentUid:
        assert_token_uid(token, parentUid)
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
async def cancel_invite(request: CancelInviteRequest, token: dict = Depends(verify_firebase_token)):
    """Cancel a pending invite. Verify parentUid matches."""
    assert_token_uid(token, request.parentUid)
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
async def remove_hcw(request: RemoveHcwRequest, token: dict = Depends(verify_firebase_token)):
    """Remove HCW from child's profile.

    - Parent removes HCW: parentUid = parent, hcwId = HCW to remove
    - HCW self-unlink (parent linked): parentUid = hcwId = requesting HCW
    """
    assert_token_uid(token, request.parentUid)
    child_data = assert_child_access(request.parentUid, request.childId)
    parent_id = child_data.get("parentId") or ""
    is_parent = parent_id == request.parentUid
    is_hcw_self = request.parentUid == request.hcwId
    hcw_in_list = request.hcwId in (child_data.get("hcwIds") or [])

    if not is_parent and not (is_hcw_self and hcw_in_list):
        raise HTTPException(status_code=403, detail="Not authorized")

    if is_hcw_self and not parent_id:
        raise HTTPException(
            status_code=400,
            detail="Profile is not linked to a parent. Delete the profile instead.",
        )

    child_ref = db.collection("children").document(request.childId)
    child_ref.update({
        "hcwIds": firestore.ArrayRemove([request.hcwId])
    })

    child_name = child_data.get("name", "")

    if is_hcw_self:
        if parent_id:
            await NotificationService.send(
                uid=parent_id,
                notif_type="PAR-10",
                title="Healthcare Worker Unlinked",
                body=f"Your healthcare worker has unlinked from {child_name}'s profile.",
                related_child_id=request.childId,
                navigation_route=f"/parent/child/{request.childId}",
                skip_push=True,
            )
    else:
        # Fire HCW-09: Parent removed HCW access → to HCW
        await NotificationService.send(
            uid=request.hcwId,
            notif_type="HCW-09",
            title="Access Removed",
            body=f"A parent has removed your access to {child_name}'s profile.",
            related_child_id=request.childId,
            navigation_route="/hcw/patients",
        )

    return {"success": True}


@router.post("/hcw-delete-child")
async def hcw_delete_child(request: HcwDeleteChildRequest, token: dict = Depends(verify_firebase_token)):
    """Permanently delete an unclaimed child profile created by an HCW."""
    assert_token_uid(token, request.hcwUid)
    child_data = get_child_data(request.childId)
    parent_id = child_data.get("parentId") or ""
    if parent_id:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete a profile linked to a parent. Unlink instead.",
        )

    hcw_ids = child_data.get("hcwIds") or []
    if request.hcwUid not in hcw_ids:
        raise HTTPException(status_code=403, detail="Not authorized")

    delete_child_tree(request.childId)
    return {"success": True, "deleted": True}


# ═══════════════════════════════════════════════════════════════════════════════
# POST /api/remove-teacher
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/remove-teacher")
async def remove_teacher(request: RemoveTeacherRequest, token: dict = Depends(verify_firebase_token)):
    """Remove teacher from child profile. Verify parentUid matches.

    - Remove teacherUid from child.teacherIds
    - Remove childId from users/{teacherUid}.linkedChildIds
    - Fire TCH-06 push to teacher
    - Fire PAR-10 in-app only to parent (no push)
    """
    assert_token_uid(token, request.parentUid)
    child_data = assert_child_access(request.parentUid, request.childId)
    is_parent = child_data.get("parentId") == request.parentUid
    is_teacher_self = request.parentUid == request.teacherUid
    teacher_in_list = request.teacherUid in (child_data.get("teacherIds") or [])

    if not is_parent and not (is_teacher_self and teacher_in_list):
        raise HTTPException(status_code=403, detail="Not authorized")

    child_ref = db.collection("children").document(request.childId)
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
    parent_id = child_data.get("parentId", "")

    if is_teacher_self:
        # Teacher removed themselves — notify parent
        if parent_id:
            await NotificationService.send(
                uid=parent_id,
                notif_type="PAR-10",
                title="Teacher Unlinked",
                body=f"The teacher has unlinked themselves from {child_name}'s profile.",
                related_child_id=request.childId,
                navigation_route=f"/parent/child/{request.childId}",
                skip_push=True,
            )
    else:
        # Parent removed teacher — notify teacher
        await NotificationService.send(
            uid=request.teacherUid,
            notif_type="TCH-06",
            title="Access Removed",
            body=f"A parent has removed your access to {child_name}'s profile.",
            related_child_id=request.childId,
            navigation_route="/teacher/dashboard",
        )

        # Fire PAR-10: Teacher unlinked → to Parent (IN-APP ONLY, no push)
        await NotificationService.send(
            uid=request.parentUid,
            notif_type="PAR-10",
            title="Teacher Unlinked",
            body=f"The teacher has been removed from {child_name}'s profile.",
            related_child_id=request.childId,
            navigation_route=f"/parent/child/{request.childId}",
            skip_push=True,
        )

    return {"success": True}
