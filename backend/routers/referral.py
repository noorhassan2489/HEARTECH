from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

import os
import io
import cloudinary
import cloudinary.uploader
import google.generativeai as genai
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from main import verify_firebase_token

router = APIRouter()

# Configure APIs (Assumes environment variables or similar are set)
genai.configure(api_key=os.environ.get("GEMINI_API_KEY", ""))

# Cloudinary configuration will rely on standard OS env vars 
# or manual config if called. User requested:
# cloudinary.config(cloud_name=CLOUD_NAME, api_key=API_KEY, api_secret=API_SECRET)
# If not explicitly set here, Cloudinary python SDK picks up CLOUDINARY_URL env var automatically.

class ReferralRequest(BaseModel):
    childId: str
    screeningId: str
    riskScore: int
    answers: list
    hcwDescription: str
    hcwInfo: dict
    childInfo: dict

class ReferralPdfRequest(BaseModel):
    childId: str
    referralId: str
    referralText: str
    hcwInfo: dict
    childInfo: dict

@router.post("/generate-referral")
async def generate_referral(request: ReferralRequest, token: dict = Depends(verify_firebase_token)):
    """
    Generate a clinical referral letter using Gemini Pro based on HearTech prompt.
    """
    try:
        model = genai.GenerativeModel('gemini-1.5-pro')
        prompt = (
            "You are a clinical audiologist assistant. Generate a formal pediatric hearing "
            "referral letter in professional medical language. Include: patient demographics, "
            "clinical findings summary, risk assessment, recommended specialist "
            "(audiologist or ENT), urgency level, suggested investigations (OAE, ABR, "
            "pure-tone audiometry). End with a signature block. Return plain text only, "
            "no markdown formatting.\n\n"
            f"Child Info: {request.childInfo}\n"
            f"HCW Info: {request.hcwInfo}\n"
            f"Risk Score: {request.riskScore}\n"
            f"Clinical Note: {request.hcwDescription}\n"
            f"Answers: {request.answers}"
        )
        response = model.generate_content(prompt)
        # Ensure we just get plain text
        letter_text = response.text.replace('**', '').replace('--', '').strip()

        return {
            "referralText": letter_text,
            "childId": request.childId,
            "screeningId": request.screeningId,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini generation failed: {str(e)}")

@router.post("/generate-referral-pdf")
async def generate_referral_pdf(request: ReferralPdfRequest, token: dict = Depends(verify_firebase_token)):
    """
    Generate PDF from referral letter using ReportLab, upload to Cloudinary.
    """
    try:
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=letter, rightMargin=72, leftMargin=72, topMargin=72, bottomMargin=72)
        styles = getSampleStyleSheet()
        
        title_style = ParagraphStyle(
            'HearTechTitle',
            parent=styles['Heading1'],
            alignment=TA_CENTER,
            spaceAfter=20,
            textColor="#0F766E", # Deep Teal
        )
        body_style = styles["Normal"]
        body_style.spaceAfter = 12
        body_style.fontSize = 11
        body_style.leading = 16
        
        flowables = []
        # Letterhead
        flowables.append(Paragraph("<b>HearTech Early Detection</b>", title_style))
        flowables.append(Paragraph("Clinical Referral Report", ParagraphStyle('Sub', parent=styles['Heading3'], alignment=TA_CENTER, spaceAfter=24)))
        
        # Body
        paragraphs = request.referralText.split('\n')
        for p in paragraphs:
            text = p.strip()
            if text:
                flowables.append(Paragraph(text, body_style))
                
        doc.build(flowables)
        
        # Get PDF bytes
        pdf_bytes = buffer.getvalue()
        buffer.close()
        
        # Upload to Cloudinary
        result = cloudinary.uploader.upload(
            pdf_bytes, 
            resource_type="raw", 
            folder="referrals/",
            public_id=f"referral_{request.referralId}"
        )
        
        return {
            "pdfUrl": result["secure_url"],
            "referralId": request.referralId,
            "childId": request.childId,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF generation or upload failed: {str(e)}")
