import asyncio
from fastapi import APIRouter, HTTPException, Request, Depends
from fastapi.responses import FileResponse
from services.referral_ai_service import ReferralAIService
from auth_dependency import verify_firebase_token
from child_auth import assert_child_access

router = APIRouter()


def _child_id_from_body(body: dict) -> str:
    return body.get("childId") or (body.get("childData") or {}).get("childId") or ""


def _verify_referral_child_access(body: dict, token: dict) -> None:
    child_id = _child_id_from_body(body)
    if child_id:
        assert_child_access(token.get("uid", ""), child_id)


def _absolute_url(request: Request, url: str) -> str:
    if url.startswith("http://") or url.startswith("https://"):
        return url
    base = str(request.base_url).rstrip("/")
    return f"{base}{url}"


@router.post("/generate-referral-chat")
async def generate_referral_chat(body: dict, token: dict = Depends(verify_firebase_token)):
    """Generate referral/chat response with v5 runtime guardrails."""
    _verify_referral_child_access(body, token)
    ai = ReferralAIService.get_instance()
    try:
        # MLX GPU stream must run on the main thread
        result = ai.generate(
            child_data=body["childData"],
            hcw_instruction=body["hcwInstruction"],
        )
        print(
            "[REFERRAL] Response ready, "
            f"{len(result.text)} chars, intent={result.intent}, "
            f"clarify={result.needs_clarification}"
        )
        return {
            "referralText": result.text,
            "success": result.success,
            "source": result.source,
            "intent": result.intent,
            "needsClarification": result.needs_clarification,
            "normalizedPrompt": result.normalized_prompt,
        }
    except Exception as e:
        print("[REFERRAL] Generation failed.")
        return {
            "referralText": (
                "Sorry, generation is temporarily unavailable. "
                "Please retry once after restarting the backend service."
            ),
            "success": False,
            "source": "error",
            "intent": "error",
            "needsClarification": False,
            "normalizedPrompt": "",
        }


@router.get("/referral-exports/{filename}")
async def download_referral_export(filename: str, user=Depends(verify_firebase_token)):
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
async def export_pdf(body: dict, request: Request, token: dict = Depends(verify_firebase_token)):
    _verify_referral_child_access(body, token)
    ai = ReferralAIService.get_instance()
    try:
        result = await asyncio.to_thread(
            ai.to_pdf_cloudinary, body["referralText"], body["childName"]
        )
    except Exception as e:
        print(f"[REFERRAL-EXPORT] PDF failed: {e}")
        raise HTTPException(status_code=500, detail="PDF export failed.") from e
    return {
        "pdfUrl": _absolute_url(request, result["url"]),
        "storage": result.get("storage", "unknown"),
        "filename": result.get("filename"),
    }


@router.post("/export-referral-docx")
async def export_docx(body: dict, request: Request, token: dict = Depends(verify_firebase_token)):
    _verify_referral_child_access(body, token)
    ai = ReferralAIService.get_instance()
    try:
        result = await asyncio.to_thread(
            ai.to_docx_cloudinary, body["referralText"], body["childName"]
        )
    except Exception as e:
        print(f"[REFERRAL-EXPORT] DOCX failed: {e}")
        raise HTTPException(status_code=500, detail="DOCX export failed.") from e
    return {
        "docxUrl": _absolute_url(request, result["url"]),
        "storage": result.get("storage", "unknown"),
        "filename": result.get("filename"),
    }
