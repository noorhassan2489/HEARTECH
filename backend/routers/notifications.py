from fastapi import APIRouter, Request
from services.notification_service import NotificationService

router = APIRouter()

# ═══════════════════════════════════════════════════════════════════════════════
# NOTIFICATION TRIGGERS — Called by other routers / services when events happen
# Each function maps to one of the 28 notification types in the master prompt
# ═══════════════════════════════════════════════════════════════════════════════


# ─── HCW NOTIFICATIONS (10) ──────────────────────────────────────────────────

async def trigger_hcw_01_handover_expiring(hcw_uid: str, child_name: str, child_id: str):
    """HCW-01: Handover code about to expire."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-01", priority="high",
        title="Handover Code Expiring",
        body=f"Code for {child_name} expires in less than 2 hours. Share it now.",
        related_child_id=child_id,
        navigation_route=f"/hcw/child/{child_id}",
    )


async def trigger_hcw_02_profile_claimed(hcw_uid: str, child_name: str, parent_name: str, child_id: str):
    """HCW-02: Parent claimed child profile."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-02", priority="normal",
        title="Profile Claimed",
        body=f"{parent_name} has claimed {child_name}'s profile using the handover code.",
        related_child_id=child_id,
        navigation_route=f"/hcw/child/{child_id}",
    )


async def trigger_hcw_03_teacher_linked(hcw_uid: str, child_name: str, teacher_name: str, child_id: str):
    """HCW-03: Teacher linked to child."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-03", priority="normal",
        title="Teacher Linked",
        body=f"{teacher_name} has been linked to {child_name}'s profile.",
        related_child_id=child_id,
    )


async def trigger_hcw_04_observation_submitted(hcw_uid: str, child_name: str, teacher_name: str, child_id: str):
    """HCW-04: Teacher submitted observation."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-04", priority="normal",
        title="New Observation",
        body=f"{teacher_name} submitted a classroom observation for {child_name}.",
        related_child_id=child_id,
        navigation_route=f"/hcw/child/{child_id}",
    )


async def trigger_hcw_05_parent_screening(hcw_uid: str, child_name: str, risk_level: str, child_id: str):
    """HCW-05: Parent completed home screening."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-05", priority="normal" if risk_level == "low" else "high",
        title="Home Screening Completed",
        body=f"Parent completed a home screening for {child_name}. Result: {risk_level.upper()}.",
        related_child_id=child_id,
        navigation_route=f"/hcw/child/{child_id}",
    )


async def trigger_hcw_06_followup_overdue(hcw_uid: str, child_name: str, child_id: str):
    """HCW-06: Follow-up screening overdue (cron triggered)."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-06", priority="normal",
        title="Follow-Up Overdue",
        body=f"{child_name} is overdue for a follow-up screening.",
        related_child_id=child_id,
    )


async def trigger_hcw_07_referral_generated(hcw_uid: str, child_name: str, referral_id: str, child_id: str):
    """HCW-07: Referral PDF generated."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-07", priority="normal",
        title="Referral Ready",
        body=f"Clinical referral for {child_name} has been generated.",
        related_child_id=child_id, related_referral_id=referral_id,
        navigation_route=f"/hcw/child/{child_id}",
    )


async def trigger_hcw_08_speech_session(hcw_uid: str, child_name: str, game: str, child_id: str):
    """HCW-08: Speech game session completed."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-08", priority="normal",
        title="Speech Session Completed",
        body=f"{child_name} completed a {game} session.",
        related_child_id=child_id,
    )


async def trigger_hcw_09_risk_change(hcw_uid: str, child_name: str, old_level: str, new_level: str, child_id: str):
    """HCW-09: Risk level changed."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-09", priority="high",
        title="Risk Level Changed",
        body=f"{child_name}'s risk level changed from {old_level.upper()} to {new_level.upper()}.",
        related_child_id=child_id,
        navigation_route=f"/hcw/child/{child_id}",
    )


async def trigger_hcw_10_verification(hcw_uid: str, approved: bool):
    """HCW-10: Account verification result."""
    await NotificationService.send(
        uid=hcw_uid, notif_type="HCW-10", priority="high",
        title="Verification " + ("Approved" if approved else "Rejected"),
        body="Your HCW license has been " + ("approved. All clinical features are now unlocked." if approved else "rejected. Please contact support."),
    )


# ─── PARENT NOTIFICATIONS (10) ───────────────────────────────────────────────

async def trigger_par_01_screening_complete(parent_uid: str, child_name: str, risk_level: str, child_id: str):
    """PAR-01: HCW screening completed for child."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-01", priority="high",
        title="Screening Complete",
        body=f"Your healthcare worker completed a screening for {child_name}.",
        related_child_id=child_id,
        navigation_route=f"/parent/child/{child_id}",
    )


async def trigger_par_02_risk_change(parent_uid: str, child_name: str, new_level: str, child_id: str):
    """PAR-02: Risk level changed."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-02", priority="high",
        title="Risk Assessment Updated",
        body=f"{child_name}'s assessment has been updated.",
        related_child_id=child_id,
        navigation_route=f"/parent/child/{child_id}",
    )


async def trigger_par_03_referral_generated(parent_uid: str, child_name: str, child_id: str, referral_id: str):
    """PAR-03: HCW generated a referral."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-03", priority="high",
        title="Referral Generated",
        body=f"Your healthcare worker has generated a referral for {child_name}.",
        related_child_id=child_id, related_referral_id=referral_id,
    )


async def trigger_par_04_teacher_linked(parent_uid: str, child_name: str, teacher_name: str, child_id: str):
    """PAR-04: Teacher accepted invite."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-04", priority="normal",
        title="Teacher Connected",
        body=f"{teacher_name} has been linked to {child_name}'s profile.",
        related_child_id=child_id,
    )


async def trigger_par_05_teacher_declined(parent_uid: str, child_name: str, child_id: str):
    """PAR-05: Teacher declined invite."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-05", priority="normal",
        title="Invite Declined",
        body=f"The teacher invite for {child_name} was declined.",
        related_child_id=child_id,
    )


async def trigger_par_06_invite_expiring(parent_uid: str, invite_id: str):
    """PAR-06: Teacher invite about to expire (cron triggered)."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-06", priority="normal",
        title="Invite Expiring Soon",
        body="Your teacher invite expires in less than 6 hours.",
        related_invite_id=invite_id,
    )


async def trigger_par_07_observation_submitted(parent_uid: str, child_name: str, teacher_name: str, child_id: str):
    """PAR-07: Teacher submitted observation."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-07", priority="normal",
        title="Observation Submitted",
        body=f"{teacher_name} submitted a classroom observation for {child_name}.",
        related_child_id=child_id,
    )


async def trigger_par_08_speech_session(parent_uid: str, child_name: str, game: str, score: int, child_id: str):
    """PAR-08: Speech game session result."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-08", priority="normal",
        title="Speech Session Complete",
        body=f"{child_name} scored {score}% in {game}!",
        related_child_id=child_id,
    )


async def trigger_par_09_home_screening_reminder(parent_uid: str, child_name: str, child_id: str):
    """PAR-09: Time for home screening (cron triggered)."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-09", priority="normal",
        title="Time for a Check-In",
        body=f"It's been a while. Run a home screening for {child_name}.",
        related_child_id=child_id,
    )


async def trigger_par_10_hcw_note(parent_uid: str, child_name: str, child_id: str):
    """PAR-10: HCW added a note visible to parent."""
    await NotificationService.send(
        uid=parent_uid, notif_type="PAR-10", priority="normal",
        title="New Note from HCW",
        body=f"Your healthcare worker added a note about {child_name}.",
        related_child_id=child_id,
        navigation_route=f"/parent/child/{child_id}",
    )


# ─── TEACHER NOTIFICATIONS (8) ───────────────────────────────────────────────

async def trigger_tch_01_new_invite(teacher_uid: str, parent_name: str, invite_id: str):
    """TCH-01: New invite from parent."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-01", priority="high",
        title="New Student Invite",
        body=f"{parent_name} has invited you to observe their child.",
        related_invite_id=invite_id,
        navigation_route="/teacher/invites",
    )


async def trigger_tch_02_invite_expiring(teacher_uid: str, invite_id: str):
    """TCH-02: Invite about to expire (cron triggered)."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-02", priority="normal",
        title="Invite Expiring",
        body="A student invite expires in less than 6 hours.",
        related_invite_id=invite_id,
    )


async def trigger_tch_03_child_risk_change(teacher_uid: str, child_name: str, new_level: str, child_id: str):
    """TCH-03: Child risk level changed."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-03", priority="normal",
        title="Student Update",
        body=f"{child_name}'s hearing assessment has been updated.",
        related_child_id=child_id,
    )


async def trigger_tch_04_screening_complete(teacher_uid: str, child_name: str, child_id: str):
    """TCH-04: New screening completed for linked child."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-04", priority="normal",
        title="New Screening",
        body=f"A screening was completed for {child_name}.",
        related_child_id=child_id,
    )


async def trigger_tch_05_speech_session(teacher_uid: str, child_name: str, game: str, child_id: str):
    """TCH-05: Speech game completed for linked child."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-05", priority="normal",
        title="Speech Session",
        body=f"{child_name} completed a {game} session.",
        related_child_id=child_id,
    )


async def trigger_tch_06_hcw_note(teacher_uid: str, child_name: str, child_id: str):
    """TCH-06: HCW added note visible to teacher."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-06", priority="normal",
        title="Note from HCW",
        body=f"The healthcare worker added a note about {child_name}.",
        related_child_id=child_id,
    )


async def trigger_tch_07_observation_reminder(teacher_uid: str, child_name: str, child_id: str):
    """TCH-07: Observation overdue 14+ days (cron triggered)."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-07", priority="normal",
        title="Observation Reminder",
        body=f"It's been 14+ days since your last observation of {child_name}.",
        related_child_id=child_id,
    )


async def trigger_tch_08_removed(teacher_uid: str, child_name: str, child_id: str):
    """TCH-08: Teacher removed from child profile."""
    await NotificationService.send(
        uid=teacher_uid, notif_type="TCH-08", priority="normal",
        title="Access Removed",
        body=f"You have been removed from {child_name}'s profile.",
        related_child_id=child_id,
    )


# ─── REST ENDPOINTS ──────────────────────────────────────────────────────────

@router.post("/notifications/send")
async def send_notification(request: Request):
    """Generic endpoint to trigger a notification."""
    data = await request.json()
    await NotificationService.send(
        uid=data["uid"],
        notif_type=data["type"],
        title=data["title"],
        body=data["body"],
        priority=data.get("priority", "normal"),
        navigation_route=data.get("navigationRoute"),
        related_child_id=data.get("relatedChildId"),
        related_invite_id=data.get("relatedInviteId"),
        related_referral_id=data.get("relatedReferralId"),
    )
    return {"status": "sent"}


@router.get("/notifications/test")
async def test_notifications():
    """Health check endpoint."""
    return {"status": "Notification system active", "triggers": 28}
