import asyncio
import os
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse
from services.referral_ai_service import ReferralAIService

router = APIRouter()


def _absolute_url(request: Request, url: str) -> str:
    if url.startswith("http://") or url.startswith("https://"):
        return url
    base = str(request.base_url).rstrip("/")
    return f"{base}{url}"

def _use_local_mlx() -> bool:
    return os.getenv("REFERRAL_USE_LOCAL_MODEL", "").strip().lower() in (
        "1",
        "true",
        "yes",
    )

@router.post("/generate-referral-chat")
async def generate_referral_chat(body: dict):
    try:
        ai = ReferralAIService.get_instance()

        # MLX needs the main thread GPU stream; Gemini can run in a worker thread
        if _use_local_mlx() and ai.has_local_model:
            text = ai.generate(
                child_data=body["childData"],
                hcw_instruction=body["hcwInstruction"],
            )
        else:
            text = await asyncio.to_thread(
                ai.generate,
                child_data=body["childData"],
                hcw_instruction=body["hcwInstruction"],
            )

        print(f"[REFERRAL] Response ready, {len(text)} chars")
        payload = {"referralText": text, "success": True}
        if getattr(ai, "last_generation_source", None) == "gemini":
            payload["fallback"] = True
        return payload
    except Exception as e:
        print(f"[REFERRAL] Primary failed: {e}, trying fallback...")
        try:
            return await gemini_fallback(body)
        except Exception as e2:
            print(f"[REFERRAL] Fallback also failed: {e2}")
            return {"referralText": f"Sorry, referral generation is temporarily unavailable. Please try again in a moment.\n\nError: {e2}", "success": False}

@router.get("/referral-exports/{filename}")
async def download_referral_export(filename: str):
    """Serve PDF/DOCX files when Cloudinary is not configured."""
    if ".." in filename or "/" in filename or "\\" in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")
    path = ReferralAIService.exports_dir() / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    media = (
        "application/pdf"
        if filename.lower().endswith(".pdf")
        else "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
    return FileResponse(path, media_type=media, filename=filename)


@router.post("/export-referral-pdf")
async def export_pdf(body: dict, request: Request):
    ai = ReferralAIService.get_instance()
    try:
        result = await asyncio.to_thread(
            ai.to_pdf_cloudinary, body["referralText"], body["childName"]
        )
    except Exception as e:
        print(f"[REFERRAL-EXPORT] PDF failed: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from e
    return {
        "pdfUrl": _absolute_url(request, result["url"]),
        "storage": result.get("storage", "unknown"),
        "filename": result.get("filename"),
    }


@router.post("/export-referral-docx")
async def export_docx(body: dict, request: Request):
    ai = ReferralAIService.get_instance()
    try:
        result = await asyncio.to_thread(
            ai.to_docx_cloudinary, body["referralText"], body["childName"]
        )
    except Exception as e:
        print(f"[REFERRAL-EXPORT] DOCX failed: {e}")
        raise HTTPException(status_code=500, detail=str(e)) from e
    return {
        "docxUrl": _absolute_url(request, result["url"]),
        "storage": result.get("storage", "unknown"),
        "filename": result.get("filename"),
    }

# ── GEMINI FALLBACK (only used if local model fails) ──────────────────────────
async def gemini_fallback(body: dict):
    from google import genai
    import os
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not set")
    client = genai.Client(api_key=api_key)
    child = body["childData"]
    prompt = f"""Generate a formal paediatric hearing referral letter.
Patient: {child['name']}, {child['age']}, Risk: {child['riskLevel'].upper()} ({child['riskScore']}/100)
HCW: {child['hcwName']}, {child['hcwHospital']}
Instructions: {body['hcwInstruction']}
Write complete letter:"""

    def _call():
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        return response.text or ""

    text = await asyncio.to_thread(_call)
    print(f"[REFERRAL] Gemini fallback used, {len(text)} chars")
    return {"referralText": text, "success": True, "fallback": True}