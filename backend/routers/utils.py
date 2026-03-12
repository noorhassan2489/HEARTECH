from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from firebase_admin import auth

router = APIRouter()

class TokenRequest(BaseModel):
    token: str

class TokenResponse(BaseModel):
    uid: str
    email: Optional[str] = None
    role: Optional[str] = None

@router.post("/verify-token", response_model=TokenResponse)
async def verify_token(req: TokenRequest):
    try:
        decoded_token = auth.verify_id_token(req.token)
        uid = decoded_token.get('uid')
        email = decoded_token.get('email')
        
        # If custom claims are used for roles
        role = decoded_token.get('role')
        
        return TokenResponse(uid=uid, email=email, role=role)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

@router.get("/age-bracket/{dob_str}")
async def get_age_bracket(dob_str: str):
    # expect format YYYY-MM-DD
    try:
        dob = datetime.strptime(dob_str, "%Y-%m-%d")
        now = datetime.now()
        
        days = (now - dob).days
        months = days / 30.44
        
        if months <= 6:
            bracket = "0-6 months"
        elif months <= 12:
            bracket = "6-12 months"
        elif months <= 24:
            bracket = "1-2 years"
        elif months <= 36:
            bracket = "2-3 years"
        else:
            bracket = "3+ years"
            
        return {
            "dob": dob_str,
            "age_months": round(months, 1),
            "age_bracket": bracket
        }
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.")
