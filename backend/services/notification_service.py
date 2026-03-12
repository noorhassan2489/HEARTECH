import os
import requests
from firebase_admin import firestore
from datetime import datetime, timezone

ONESIGNAL_APP_ID = os.environ.get("ONESIGNAL_APP_ID", "YOUR-APP-ID")
ONESIGNAL_REST_API_KEY = os.environ.get("ONESIGNAL_REST_API_KEY", "YOUR-REST-KEY")

class NotificationService:
    @staticmethod
    def send_notification(uid: str, type_code: str, title: str, body: str, priority: str = "normal", route: str = "/", **related_ids):
        """
        1. Write notification to Firestore under /notifications/{uid}/items/
        2. Trigger OneSignal push notification to the external user ID (uid)
        """
        # 1. Firestore Write
        try:
            db = firestore.client()
            doc_ref = db.collection("notifications").document(uid).collection("items").document()
            
            payload = {
                "type": type_code,
                "title": title,
                "body": body,
                "read": False,
                "createdAt": datetime.now(timezone.utc),
                "priority": priority,
                "navigationRoute": route,
            }

            # Map related IDs
            if "child_id" in related_ids:
                payload["relatedChildId"] = related_ids["child_id"]
            if "screening_id" in related_ids:
                payload["relatedScreeningId"] = related_ids["screening_id"]
            if "referral_id" in related_ids:
                payload["relatedReferralId"] = related_ids["referral_id"]
            if "invite_id" in related_ids:
                payload["relatedInviteId"] = related_ids["invite_id"]

            doc_ref.set(payload)
        except Exception as e:
            print(f"Error writing notification to Firestore: {e}")

        # 2. OneSignal Push
        try:
            headers = {
                "Authorization": f"Basic {ONESIGNAL_REST_API_KEY}",
                "Content-Type": "application/json; charset=utf-8"
            }
            
            data = {
                "app_id": ONESIGNAL_APP_ID,
                "headings": {"en": title},
                "contents": {"en": body},
                "include_external_user_ids": [uid],
                "data": {
                    "route": route,
                    "type": type_code
                }
            }

            requests.post("https://onesignal.com/api/v1/notifications", headers=headers, json=data)
        except Exception as e:
            print(f"Error sending OneSignal push: {e}")
