from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime, timedelta
from firebase_admin import firestore

from services.notification_service import NotificationService

db = firestore.client()


def setup_cron_jobs():
    """
    Initialize APScheduler cron jobs for HearTech notification triggers.
    5 automated jobs that check Firestore and fire notifications.
    """
    scheduler = BackgroundScheduler()

    # ─────────────────────────────────────────────────────────────────────────
    # JOB 1: Every hour — check handover codes expiring in ≤2h → HCW-01
    # ─────────────────────────────────────────────────────────────────────────
    @scheduler.scheduled_job("interval", hours=1, id="check_handover_codes")
    def check_handover_codes():
        try:
            now = datetime.now()
            two_hours = now + timedelta(hours=2)
            children = db.collection("children").stream()

            for doc in children:
                data = doc.to_dict()
                hc = data.get("handoverCode", {})
                if hc.get("expiryWarningSent"):
                    continue
                expires = hc.get("expiresAt")
                if not expires:
                    continue
                if hasattr(expires, "seconds"):
                    exp_dt = datetime.fromtimestamp(expires.seconds)
                elif isinstance(expires, datetime):
                    exp_dt = expires
                else:
                    continue

                if now < exp_dt <= two_hours and not data.get("parentId"):
                    hcw_id = data.get("createdByHcwId")
                    if hcw_id:
                        NotificationService.send_sync(
                            uid=hcw_id,
                            notif_type="HCW-01",
                            title="Handover Code Expiring",
                            body=f"Code for {data.get('name', 'Unknown')} expires in less than 2 hours.",
                            priority="high",
                            related_child_id=doc.id,
                            navigation_route=f"/hcw/child/{doc.id}",
                        )
                        db.collection("children").document(doc.id).update({
                            "handoverCode.expiryWarningSent": True,
                        })
            print(f"[CRON] Handover codes checked at {now}")
        except Exception as e:
            print(f"[CRON] Error checking handover codes: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # JOB 2: Daily 08:00 — check overdue follow-up screenings → HCW-06
    # ─────────────────────────────────────────────────────────────────────────
    @scheduler.scheduled_job("cron", hour=8, minute=0, id="check_followups")
    def check_followup_screenings():
        try:
            now = datetime.now()
            three_months_ago = now - timedelta(days=90)
            children = db.collection("children").where(
                "riskLevel", "in", ["medium", "high"]
            ).stream()

            for doc in children:
                data = doc.to_dict()
                if data.get("nextScreeningReminderSent"):
                    continue
                last = data.get("lastScreeningDate")
                if not last:
                    continue
                if hasattr(last, "seconds"):
                    last = datetime.fromtimestamp(last.seconds)
                if isinstance(last, datetime) and last < three_months_ago:
                    sent = False
                    for hcw_id in data.get("hcwIds", []):
                        NotificationService.send_sync(
                            uid=hcw_id,
                            notif_type="HCW-06",
                            title="Follow-Up Overdue",
                            body=(
                                f"{data.get('name', 'Unknown')} is overdue for a follow-up "
                                f"screening (last: {last.strftime('%b %d')})."
                            ),
                            priority="normal",
                            related_child_id=doc.id,
                            navigation_route=f"/hcw/child/{doc.id}",
                        )
                        sent = True
                    if sent:
                        db.collection("children").document(doc.id).update({
                            "nextScreeningReminderSent": True,
                        })
            print(f"[CRON] Follow-up screenings checked at {now}")
        except Exception as e:
            print(f"[CRON] Error checking follow-ups: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # JOB 3: Daily 09:00 — teacher observation gaps 14+ days → TCH-07
    # ─────────────────────────────────────────────────────────────────────────
    @scheduler.scheduled_job("cron", hour=9, minute=0, id="check_observations")
    def check_teacher_observations():
        try:
            now = datetime.now()
            two_weeks_ago = now - timedelta(days=14)
            children = db.collection("children").stream()

            for doc in children:
                data = doc.to_dict()
                teacher_ids = data.get("teacherIds", [])
                if not teacher_ids:
                    continue
                if data.get("observationReminderSent"):
                    continue

                obs = (
                    db.collection(f"children/{doc.id}/teacherObservations")
                    .order_by("date", direction=firestore.Query.DESCENDING)
                    .limit(1)
                    .stream()
                )
                latest = None
                for o in obs:
                    latest = o.to_dict().get("date")
                    break

                needs_alert = False
                if latest is None:
                    needs_alert = True
                else:
                    if hasattr(latest, "seconds"):
                        latest = datetime.fromtimestamp(latest.seconds)
                    if isinstance(latest, datetime) and latest < two_weeks_ago:
                        needs_alert = True

                if needs_alert:
                    for tid in teacher_ids:
                        NotificationService.send_sync(
                            uid=tid,
                            notif_type="TCH-07",
                            title="Observation Reminder",
                            body=(
                                f"It's been 14+ days since your last observation of "
                                f"{data.get('name', 'Unknown')}."
                            ),
                            priority="normal",
                            related_child_id=doc.id,
                            navigation_route=f"/teacher/child/{doc.id}",
                        )
                    db.collection("children").document(doc.id).update({
                        "observationReminderSent": True,
                    })
            print(f"[CRON] Teacher observations checked at {now}")
        except Exception as e:
            print(f"[CRON] Error checking observations: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # JOB 4: Daily 10:00 — parent home screening gaps 30+ days → PAR-09
    # ─────────────────────────────────────────────────────────────────────────
    @scheduler.scheduled_job("cron", hour=10, minute=0, id="check_home_screenings")
    def check_parent_screenings():
        try:
            now = datetime.now()
            thirty_days_ago = now - timedelta(days=30)
            children = db.collection("children").stream()

            for doc in children:
                data = doc.to_dict()
                parent_id = data.get("parentId")
                if not parent_id:
                    continue
                if data.get("homeScreeningReminderSent"):
                    continue

                last = data.get("lastScreeningDate")
                needs_reminder = last is None
                if not needs_reminder:
                    if hasattr(last, "seconds"):
                        last = datetime.fromtimestamp(last.seconds)
                    if isinstance(last, datetime) and last < thirty_days_ago:
                        needs_reminder = True

                if needs_reminder:
                    NotificationService.send_sync(
                        uid=parent_id,
                        notif_type="PAR-09",
                        title="Time for a Check-In",
                        body=(
                            f"Run a home screening for {data.get('name', 'Unknown')} "
                            "to track their progress."
                        ),
                        priority="normal",
                        related_child_id=doc.id,
                        navigation_route="/parent/screening",
                    )
                    db.collection("children").document(doc.id).update({
                        "homeScreeningReminderSent": True,
                    })
            print(f"[CRON] Parent screenings checked at {now}")
        except Exception as e:
            print(f"[CRON] Error checking parent screenings: {e}")

    # ─────────────────────────────────────────────────────────────────────────
    # JOB 5: Every hour — pending invites expiring in ≤6h → TCH-02 / HCW-11 / PAR-06
    # ─────────────────────────────────────────────────────────────────────────
    @scheduler.scheduled_job("interval", hours=1, id="check_invite_expiry")
    def check_invite_expiry():
        try:
            now = datetime.now()
            six_hours = now + timedelta(hours=6)
            invites = db.collection("invites").where("status", "==", "pending").stream()

            for doc in invites:
                data = doc.to_dict()
                if data.get("inviteExpirySent"):
                    continue
                expires = data.get("expiresAt")
                if not expires:
                    continue
                if hasattr(expires, "seconds"):
                    expires = datetime.fromtimestamp(expires.seconds)
                if not (now < expires <= six_hours):
                    continue

                invite_type = data.get("inviteType", "teacher")
                parent_id = data.get("parentUid")
                child_name = data.get("childName", "the child")

                if invite_type == "hcw":
                    hcw_uid = data.get("hcwUid")
                    if hcw_uid:
                        NotificationService.send_sync(
                            uid=hcw_uid,
                            notif_type="HCW-11",
                            title="Patient Invite Expiring",
                            body=f"Your invite to care for {child_name} expires in less than 6 hours.",
                            priority="normal",
                            related_invite_id=doc.id,
                            related_child_id=data.get("childId"),
                            navigation_route="/hcw/invites",
                        )
                    if parent_id:
                        NotificationService.send_sync(
                            uid=parent_id,
                            notif_type="PAR-06",
                            title="Healthcare Worker Invite Expiring",
                            body="Your healthcare worker invite is expiring soon.",
                            priority="normal",
                            related_invite_id=doc.id,
                            navigation_route=f"/parent/invite-hcw/{data.get('childId', '')}",
                        )
                else:
                    teacher_uid = data.get("teacherUid")
                    if teacher_uid:
                        NotificationService.send_sync(
                            uid=teacher_uid,
                            notif_type="TCH-02",
                            title="Invite Expiring Soon",
                            body="Your invite to observe a child expires in less than 6 hours.",
                            priority="normal",
                            related_invite_id=doc.id,
                            navigation_route="/teacher/invites",
                        )
                    if parent_id:
                        NotificationService.send_sync(
                            uid=parent_id,
                            notif_type="PAR-06",
                            title="Teacher Invite Expiring",
                            body="Your teacher invite is expiring soon. They may not have seen it.",
                            priority="normal",
                            related_invite_id=doc.id,
                            navigation_route=f"/parent/invite-teacher/{data.get('childId', '')}",
                        )

                db.collection("invites").document(doc.id).update({
                    "inviteExpirySent": True,
                })
            print(f"[CRON] Invite expiry checked at {now}")
        except Exception as e:
            print(f"[CRON] Error checking invite expiry: {e}")

    scheduler.start()
    print("[CRON] APScheduler started with 5 jobs")
