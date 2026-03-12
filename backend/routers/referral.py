import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import google.generativeai as genai
from io import BytesIO
from fastapi.responses import StreamingResponse

# reportlab imports for PDF generation
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet

router = APIRouter()

# Configure Gemini with the API Key
# Make sure to set GEMINI_API_KEY in your environment variables
genai.configure(api_key=os.environ.get("GEMINI_API_KEY", "YOUR_API_KEY_HERE"))

class ReferralRequest(BaseModel):
    child_name: str
    age_bracket: str
    risk_level: str
    clinical_flags: list[str]
    notes: str
    hcw_name: str

class ReferralResponse(BaseModel):
    referral_text: str

@router.post("/generate-referral", response_model=ReferralResponse)
async def generate_referral(req: ReferralRequest):
    try:
        model = genai.GenerativeModel('gemini-pro')
        
        prompt = f"""
        You are a pediatric audiology assistant. Generate a professional medical referral letter for an audiologist based on the following hearing screening results.
        
        Child Name: {req.child_name}
        Age: {req.age_bracket}
        Screening Risk Level: {req.risk_level}
        Clinical Flags Identified: {', '.join(req.clinical_flags) if req.clinical_flags else 'None'}
        Healthcare Worker Notes: {req.notes}
        Referred By: {req.hcw_name}
        
        The letter should be professional, empathetic, and highlight the urgency based on the risk level. Keep it concise (around 3 paragraphs) and clinical.
        """
        
        response = model.generate_content(prompt)
        text = response.text
        
        # If API key is invalid or model fails, fallback
        if not text:
            text = f"Subject: Hearing Referral for {req.child_name}\n\nThis is a system-generated fallback referral due to AI unavailability. The patient is classified as {req.risk_level} risk."
            
        return ReferralResponse(referral_text=text)
    except Exception as e:
        print(f"Gemini API Error: {e}")
        # Fallback if API fails
        fallback_text = f"MEDICAL REFERRAL\n\nPatient: {req.child_name}\nAge: {req.age_bracket}\nRisk Level: {req.risk_level}\n\nClinical details: {req.notes}\n\nPlease evaluate for hearing loss.\n\nReferred by: {req.hcw_name}"
        return ReferralResponse(referral_text=fallback_text)

class PDFRequest(BaseModel):
    referral_text: str
    child_name: str

@router.post("/generate-referral-pdf")
async def generate_referral_pdf(req: PDFRequest):
    try:
        buffer = BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=letter)
        styles = getSampleStyleSheet()
        story = []
        
        # Title
        story.append(Paragraph("HearTech Medical Referral", styles['Title']))
        story.append(Spacer(1, 12))
        
        # Split text into paragraphs
        for p in req.referral_text.split('\n'):
            if p.strip():
                story.append(Paragraph(p.strip(), styles['Normal']))
                story.append(Spacer(1, 6))
                
        doc.build(story)
        buffer.seek(0)
        
        headers = {
            'Content-Disposition': f'attachment; filename="Referral_{req.child_name.replace(" ", "_")}.pdf"'
        }
        return StreamingResponse(buffer, media_type="application/pdf", headers=headers)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF Generation failed: {str(e)}")
