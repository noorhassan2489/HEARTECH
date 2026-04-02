import httpx
from firebase_admin import firestore
from datetime import datetime

db = firestore.client()


class NotificationService:
    """
    Send notifications via Firestore (in-app) and OneSignal (push).
    Full implementation in Phase 7.
    """

    ONESIGNAL_APP_ID = "0200ac21-f1e9-417b-84de-38682079fb6b"
    ONESIGNAL_REST_API_KEY = "os_v2_app_aiakyipr5faxxbg6hbuca6p3nmi6ocjftpfe33eryf7frpa2z7jnrbam6l3nws2jxzztedjr7aylmaxlhvgjejzli43ier2ffzao5sa"

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
    ):
        """
        Step 1: Write to Firestore (in-app notification).
        Step 2: Check user preferences.
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

        # Step 2: Check preferences (skip if high priority — cannot be disabled)
        if priority != "high":
            user_doc = db.collection("users").document(uid).get()
            if user_doc.exists:
                prefs = user_doc.to_dict().get("notificationPrefs", {})
                pref_key = notif_type.replace("-", "_")
                if pref_key in prefs and not prefs[pref_key]:
                    return  # User disabled this notification type

        # Step 3: Send push via OneSignal
        try:
            async with httpx.AsyncClient() as client:
                await client.post(
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
                )
        except Exception as e:
            print(f"[PUSH] Failed to send push notification: {e}")
