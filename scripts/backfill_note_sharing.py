#!/usr/bin/env python3
"""One-off: backfill note sharing fields for parent/teacher visibility queries."""
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("backend/service-account-key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

children = db.collection("children").stream()
updated = 0

for child_doc in children:
    child = child_doc.to_dict() or {}
    parent_id = child.get("parentId")
    teacher_ids = child.get("teacherIds") or []

    notes = child_doc.reference.collection("notes").stream()
    for note_doc in notes:
        note = note_doc.to_dict() or {}
        patch = {}

        if note.get("isPublic") and parent_id and note.get("parentId") != parent_id:
            patch["parentId"] = parent_id
        elif not note.get("isPublic") and "parentId" in note:
            patch["parentId"] = firestore.DELETE_FIELD

        if note.get("isTeacherVisible") and teacher_ids:
            if note.get("visibleToTeacherIds") != teacher_ids:
                patch["visibleToTeacherIds"] = teacher_ids
        elif not note.get("isTeacherVisible") and note.get("visibleToTeacherIds"):
            patch["visibleToTeacherIds"] = firestore.DELETE_FIELD

        if patch:
            note_doc.reference.update(patch)
            updated += 1
            print(f"Updated {child_doc.id}/notes/{note_doc.id}: {list(patch.keys())}")

print(f"Done. Updated {updated} note(s).")
