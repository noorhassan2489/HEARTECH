"""Firebase JWT token verification dependency for FastAPI."""
from fastapi import HTTPException, Request
from firebase_admin import auth as firebase_auth


async def verify_firebase_token(request: Request):
    """Verify Firebase JWT on every endpoint except GET /health."""
    if request.url.path == "/health" and request.method == "GET":
        return None

    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing auth token")

    token = auth_header.split("Bearer ")[1]
    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid auth token")
