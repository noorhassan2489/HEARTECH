from fastapi import APIRouter
from datetime import datetime, date

router = APIRouter()


@router.get("/age-bracket/{dob}")
async def get_age_bracket(dob: str):
    """
    Compute age bracket from date of birth string (YYYY-MM-DD).
    Returns bracket number (1-5), label, and age in months.
    """
    try:
        birth_date = date.fromisoformat(dob)
    except ValueError:
        return {"error": "Invalid date format. Use YYYY-MM-DD."}

    today = date.today()
    age_months = (today.year - birth_date.year) * 12 + (today.month - birth_date.month)
    if today.day < birth_date.day:
        age_months -= 1

    age_years = age_months / 12

    if age_months <= 6:
        bracket = 1
        label = "0-6 months"
    elif age_months <= 12:
        bracket = 2
        label = "7-12 months"
    elif age_years <= 2:
        bracket = 3
        label = "1-2 years"
    elif age_years <= 5:
        bracket = 4
        label = "3-5 years"
    else:
        bracket = 5
        label = "6-12 years"

    return {
        "bracket": bracket,
        "label": label,
        "ageMonths": age_months,
        "ageYears": round(age_years, 1),
    }


@router.post("/cloudinary-signature")
async def cloudinary_signature():
    """
    Generate signed upload parameters for Cloudinary.
    TODO: Implement with Cloudinary SDK in Phase 3.
    """
    return {
        "timestamp": int(datetime.now().timestamp()),
        "signature": "placeholder_signature",
    }
