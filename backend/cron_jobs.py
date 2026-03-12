from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from services.notification_service import NotificationService
from firebase_admin import firestore
from datetime import datetime, timedelta, timezone

def check_due_followups():
    """
    Runs daily. Checks for child screenings that require a follow-up 
    and sends notification to the attached HCW.
    """
    print("Checking for due followups...")
    # Add implementation connecting to Firestore 
    pass

def check_expired_handover_codes():
    """
    Runs periodically. Clears handover codes older than 48 hours.
    """
    print("Checking expired handover codes...")
    db = firestore.client()
    now = datetime.now(timezone.utc)
    threshold = now - timedelta(hours=48)
    
    # Needs valid indexing in production
    codes = db.collection("handover_codes").where("createdAt", "<", threshold).stream()
    
    count = 0
    for doc in codes:
        doc.reference.delete()
        count += 1
    
    if count > 0:
        print(f"Deleted {count} expired handover codes.")

def start_cron_jobs():
    scheduler = BackgroundScheduler()
    
    # Dummy schedules for demonstration/phase 3 extension
    scheduler.add_job(check_due_followups, 'interval', days=1)
    scheduler.add_job(check_expired_handover_codes, 'interval', hours=1)
    
    scheduler.start()
    return scheduler

if __name__ == "__main__":
    start_cron_jobs()
