from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from firebase_admin import firestore
import random
import string

from services.notification_service import NotificationService

router = APIRouter()

def get_db():
    return firestore.client()

class ClaimProfileRequest(BaseModel):
    parent_uid: str
    handover_code: str

class HandoverCodeRequest(BaseModel):
    hcw_uid: str
    child_id: str

class InviteTeacherRequest(BaseModel):
    parent_uid: str
    child_id: str
    teacher_email: str

class RespondInviteRequest(BaseModel):
    teacher_uid: str
    invite_id: str
    accept: bool

@router.post("/regenerate-handover-code")
def regenerate_handover_code(req: HandoverCodeRequest):
    """
    HCW calls this to generate a new 6-char auth code for a child profile.
    """
    db = get_db()
    
    # Generate random 6 char code
    code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    
    # Save code to some 'handover_codes' collection mapped to child_id
    db.collection("handover_codes").document(code).set({
        "child_id": req.child_id,
        "hcw_id": req.hcw_uid,
        "createdAt": firestore.SERVER_TIMESTAMP
    })

    return {"code": code}

@router.post("/claim-profile")
def claim_profile(req: ClaimProfileRequest):
    """
    Parent submits handover code to link child to their account.
    """
    db = get_db()
    
    code_ref = db.collection("handover_codes").document(req.handover_code)
    doc = code_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Invalid or expired handover code.")

    data = doc.to_dict()
    child_id = data["child_id"]
    hcw_id = data["hcw_id"]

    # Link child to parent
    db.collection("children").document(child_id).update({
        "parentId": req.parent_uid
    })
    
    # Delete code
    code_ref.delete()

    # Trigger Notification to HCW (HCW-02)
    NotificationService.send_notification(
        uid=hcw_id,
        type_code="HCW-02",
        title="Profile Claimed",
        body="A parent has successfully claimed a child profile you created.",
        route=f"/child/{child_id}",
        child_id=child_id
    )

    # Trigger Notification to Parent (PAR-01)
    NotificationService.send_notification(
        uid=req.parent_uid,
        type_code="PAR-01",
        title="Profile Linked",
        body="Your child's profile is now linked to your account.",
        route=f"/child/{child_id}",
        child_id=child_id
    )

    return {"success": True, "child_id": child_id}

@router.post("/invite-teacher")
def invite_teacher(req: InviteTeacherRequest):
    """
    Parent invites a teacher via email to view child stats.
    """
    db = get_db()
    
    # Look up teacher by email in users dict (Simplified depending on structure)
    users = db.collection("users").where("email", "==", req.teacher_email).where("role", "==", "Teacher").get()
    
    if not users:
        raise HTTPException(status_code=404, detail="Teacher not found with that email.")
    
    teacher_uid = users[0].id

    # Create invite doc
    invite_ref = db.collection("invites").document()
    invite_ref.set({
        "parent_id": req.parent_uid,
        "teacher_id": teacher_uid,
        "child_id": req.child_id,
        "status": "pending",
        "createdAt": firestore.SERVER_TIMESTAMP
    })

    # Notify Teacher (TCH-01)
    NotificationService.send_notification(
        uid=teacher_uid,
        type_code="TCH-01",
        title="New Student Invite",
        body="You have been invited to view a student's profile.",
        route="/teacher/dashboard",
        invite_id=invite_ref.id,
        child_id=req.child_id
    )

    return {"success": True}

@router.post("/respond-invite")
def respond_invite(req: RespondInviteRequest):
    """
    Teacher accepts or declines invite.
    """
    db = get_db()
    invite_ref = db.collection("invites").document(req.invite_id)
    doc = invite_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Invite not found")

    data = doc.to_dict()
    status = "accepted" if req.accept else "declined"
    
    invite_ref.update({"status": status})

    if req.accept:
        # Array union teacher to child object
        db.collection("children").document(data['child_id']).update({
            "teacherIds": firestore.ArrayUnion([req.teacher_uid])
        })

    # Notify Parent (PAR-05 for accept, PAR-06 for decline)
    type_code = "PAR-05" if req.accept else "PAR-06"
    title = "Invite Accepted" if req.accept else "Invite Declined"
    body = "A teacher has accepted your invite." if req.accept else "A teacher has declined your invite."

    NotificationService.send_notification(
        uid=data["parent_id"],
        type_code=type_code,
        title=title,
        body=body,
        route=f"/child/{data['child_id']}",
        child_id=data['child_id']
    )

    return {"success": True, "status": status}
