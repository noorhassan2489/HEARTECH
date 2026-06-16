"""Child access authorization — verify caller is linked to a child profile."""
from fastapi import HTTPException
from firebase_admin import firestore

db = firestore.client()


def get_child_data(child_id: str) -> dict:
    """Load child document or raise 404."""
    child_doc = db.collection("children").document(child_id).get()
    if not child_doc.exists:
        raise HTTPException(status_code=404, detail="Child not found")
    return child_doc.to_dict() or {}


def assert_child_access(uid: str, child_id: str) -> dict:
    """
    Verify uid is a linked HCW, parent, or teacher for the child.
    Returns child data on success.
    """
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid auth token")

    child_data = get_child_data(child_id)
    hcw_ids = child_data.get("hcwIds", [])
    teacher_ids = child_data.get("teacherIds", [])
    parent_id = child_data.get("parentId", "")

    if uid in hcw_ids or uid == parent_id or uid in teacher_ids:
        return child_data

    raise HTTPException(status_code=403, detail="Not authorized for this child")


_CHILD_SUBCOLLECTIONS = (
    "screenings",
    "teacherObservations",
    "referrals",
    "speechLogs",
    "notes",
)


def _delete_collection(coll_ref, batch_size: int = 200) -> None:
    """Delete all documents in a collection reference."""
    while True:
        docs = list(coll_ref.limit(batch_size).stream())
        if not docs:
            break
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()


def delete_child_tree(child_id: str) -> None:
    """Delete a child document and all known subcollections."""
    child_ref = db.collection("children").document(child_id)
    for sub in _CHILD_SUBCOLLECTIONS:
        _delete_collection(child_ref.collection(sub))
    child_ref.delete()


def assert_token_uid(token: dict, expected_uid: str) -> None:
    """Verify JWT uid matches the uid claimed in the request body."""
    token_uid = token.get("uid", "")
    if not token_uid or token_uid != expected_uid:
        raise HTTPException(status_code=403, detail="Not authorized")
