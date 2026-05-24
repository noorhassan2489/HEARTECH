from fastapi import APIRouter, Depends, HTTPException
from services.referral_ai_service import ReferralAIService
from services.notification_service import NotificationService

router = APIRouter()

@router.post("/api/generate-referral-chat")
async def generate_referral_chat(body: dict):
    try:
        ai = ReferralAIService.get_instance()
        text = ai.generate(
            child_data=body["childData"],
            hcw_instruction=body["hcwInstruction"]
        )
        return {"referralText": text, "success": True}
    except Exception as e:
        # FALLBACK — if local model fails, use Gemini
        return await gemini_fallback(body)

@router.post("/api/export-referral-pdf")
async def export_pdf(body: dict):
    ai = ReferralAIService.get_instance()
    url = ai.to_pdf_cloudinary(body["referralText"], body["childName"])
    return {"pdfUrl": url}

@router.post("/api/export-referral-docx")
async def export_docx(body: dict):
    ai = ReferralAIService.get_instance()
    url = ai.to_docx_cloudinary(body["referralText"], body["childName"])
    return {"docxUrl": url}

# ── GEMINI FALLBACK (only used if local model fails) ──────────────────────────
async def gemini_fallback(body: dict):
    import google.generativeai as genai
    import os
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-2.5-flash")
    child = body["childData"]
    prompt = f"""Generate a formal paediatric hearing referral letter.
Patient: {child['name']}, {child['age']}, Risk: {child['riskLevel'].upper()} ({child['riskScore']}/100)
HCW: {child['hcwName']}, {child['hcwHospital']}
Instructions: {body['hcwInstruction']}
Write complete letter:"""
    response = model.generate_content(prompt)
    return {"referralText": response.text, "success": True, "fallback": True}