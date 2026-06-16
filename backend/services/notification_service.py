import asyncio
import httpx
import os
from firebase_admin import firestore
from datetime import datetime

db = firestore.client()

# Matches lib/core/constants/app_constants.dart default when env is unset.
_DEFAULT_ONESIGNAL_APP_ID = "0200ac21-f1e9-417b-84de-38682079fb6b"


class NotificationService:
    """
    Send notifications via Firestore (in-app) and OneSignal (push).
    Single entry point for all 28+ notification types.
    """

    ONESIGNAL_APP_ID = os.environ.get("ONESIGNAL_APP_ID", _DEFAULT_ONESIGNAL_APP_ID)
    ONESIGNAL_REST_API_KEY = os.environ.get("ONESIGNAL_REST_API_KEY", "")

    @staticmethod
    async def send(
        uid: str,
        notif_type: str,
        title: str,
        body: str,
        data: dict = None,
        priority: str = "normal",
        navigation_route: str = None,
        related_child_id: str = None,
        related_invite_id: str = None,
        related_referral_id: str = None,
        skip_push: bool = False,
    ):
        """
        Step 1: Write to Firestore (in-app notification).
        Step 2: Check user preferences (push only).
        Step 3: Send via OneSignal (push notification).
        """
        if data is None:
            data = {}

        notif_id = db.collection("notifications").document().id

        # Step 1: Write to Firestore
        notif_data = {
            "notifId": notif_id,
            "type": notif_type,
            "title": title,
            "body": body,
            "read": False,
            "priority": priority,
            "createdAt": datetime.now(),
            "navigationRoute": navigation_route,
            "relatedChildId": related_child_id,
            "relatedInviteId": related_invite_id,
            "relatedReferralId": related_referral_id,
        }

        db.collection("notifications").document(uid).collection("items").document(
            notif_id
        ).set(notif_data)

        if skip_push:
            return

        # Step 2: Check preferences (skip push only — Firestore write already done)
        if priority != "high":
            user_doc = db.collection("users").document(uid).get()
            if user_doc.exists:
                prefs = user_doc.to_dict().get("notificationPrefs", {})
                pref_key = notif_type.replace("-", "_")
                if pref_key in prefs and not prefs[pref_key]:
                    return

        # Step 3: Send push via OneSignal
        if not NotificationService.ONESIGNAL_APP_ID or not NotificationService.ONESIGNAL_REST_API_KEY:
            print(
                "[PUSH] OneSignal not configured. Set ONESIGNAL_APP_ID and "
                "ONESIGNAL_REST_API_KEY in backend/.env"
            )
            return

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://onesignal.com/api/v1/notifications",
                    headers={
                        "Authorization": f"Basic {NotificationService.ONESIGNAL_REST_API_KEY}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "app_id": NotificationService.ONESIGNAL_APP_ID,
                        "include_aliases": {"external_id": [uid]},
                        "target_channel": "push",
                        "headings": {"en": title},
                        "contents": {"en": body},
                        "data": {
                            "type": notif_type,
                            "navigationRoute": navigation_route,
                            **data,
                        },
                        "priority": 10 if priority == "high" else 5,
                    },
                    timeout=15.0,
                )
                if response.status_code >= 400:
                    print(f"[PUSH] OneSignal error {response.status_code}: {response.text}")
        except Exception as e:
            print(f"[PUSH] Failed to send push notification: {e}")

    @staticmethod
    def send_sync(**kwargs):
        """Sync wrapper for APScheduler cron jobs (background thread)."""
        asyncio.run(NotificationService.send(**kwargs))
