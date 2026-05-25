"""
ReferralAIService — Loads fine-tuned Llama 3.2-3B (LoRA adapters via MLX)
for generating paediatric hearing referral letters.

Falls back to Gemini 2.5 Flash if local model fails or output is degenerate.
"""
import os
import re
import shutil
import tempfile
from collections import Counter
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

# Llama 3 special tokens that must not appear in clinical letters
_LLAMA_SPECIAL_TOKENS = (
    "<|begin_of_text|>",
    "<|end_of_text|>",
    "<|eot_id|>",
    "<|start_header_id|>",
    "<|end_header_id|>",
)

# Training data starts the letter at this marker (see heartech_dataset/*.jsonl)
_LETTER_START_MARKERS = ("Date:", "Dear Colleague", "CLINICAL SUMMARY")

_BACKEND_DIR = Path(__file__).resolve().parent.parent
load_dotenv(_BACKEND_DIR / ".env")

# Resolve paths relative to this file
_BASE_DIR = _BACKEND_DIR / "heartech_ai"
_MODEL_PATH = str(_BASE_DIR / "heartech_referral_model")
_ADAPTER_PATH = str(_BASE_DIR / "heartech_adapters")
_EXPORTS_DIR = _BACKEND_DIR / "referral_exports"
_EXPORTS_DIR.mkdir(parents=True, exist_ok=True)


class ReferralAIService:
    """Singleton — loads the fine-tuned LLaMA model once, reuses for all requests."""

    _instance = None
    _model = None
    _tokenizer = None

    def __init__(self):
        self.last_generation_source = "unknown"
        self._load_model()

    @staticmethod
    def _prefer_gemini() -> bool:
        """Fast path: use Gemini when configured unless local is explicitly requested."""
        use_local = os.getenv("REFERRAL_USE_LOCAL_MODEL", "").strip().lower()
        if use_local in ("1", "true", "yes"):
            print("[REFERRAL-AI] REFERRAL_USE_LOCAL_MODEL enabled — using local MLX model.")
            return False
        if os.getenv("GEMINI_API_KEY"):
            return True
        return False

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    @property
    def has_local_model(self) -> bool:
        return self._model is not None and self._tokenizer is not None

    # ── Load model ────────────────────────────────────────────────────────
    def _load_model(self):
        """Load the fine-tuned Llama model with LoRA adapters via MLX."""
        try:
            from mlx_lm import load

            print(f"[REFERRAL-AI] Loading model from {_MODEL_PATH}")
            print(f"[REFERRAL-AI] Loading adapters from {_ADAPTER_PATH}")

            self._model, self._tokenizer = load(
                _MODEL_PATH,
                adapter_path=_ADAPTER_PATH,
            )
            print("[REFERRAL-AI] Model loaded successfully.")
        except Exception as e:
            print(f"[REFERRAL-AI] WARNING: Failed to load local model: {e}")
            print("[REFERRAL-AI] Will fall back to Gemini for inference.")
            self._model = None
            self._tokenizer = None

    # ── Build prompt matching training format ─────────────────────────────
    def _build_prompt(self, child_data: dict, hcw_instruction: str) -> str:
        flags = child_data.get("flags", [])
        flags_str = "; ".join(flags) if flags else "None reported"

        return (
            "You are a clinical audiologist assistant for HearTech, "
            "a paediatric hearing screening system.\n\n"
            "Generate a formal paediatric hearing referral letter "
            "using the following data:\n\n"
            f"Patient Name: {child_data.get('name', 'Unknown')}\n"
            f"Age: {child_data.get('age', 'Unknown')}\n"
            f"Gender: {child_data.get('gender', 'Unknown')}\n"
            f"Date of Birth: {child_data.get('dob', 'Unknown')}\n"
            f"Risk Score: {child_data.get('riskScore', 'N/A')}/100\n"
            f"Risk Level: {child_data.get('riskLevel', 'Unknown').upper()}\n"
            f"Age Bracket: {child_data.get('ageBracket', 'Unknown')}\n"
            f"Clinical Risk Flags: {flags_str}\n"
            f"Referring Clinician: {child_data.get('hcwTitle', '')} "
            f"{child_data.get('hcwName', 'Unknown')} "
            f"({child_data.get('hcwSpec', '')}), "
            f"{child_data.get('hcwHospital', 'Unknown')}\n"
            f"Clinician Instruction: {hcw_instruction}\n\n"
            "Write the complete referral letter:\n\n"
        )

    # ── Generate (sync — called via asyncio.to_thread from router) ────────
    def generate(self, child_data: dict, hcw_instruction: str) -> str:
        """Generate a referral letter — Gemini when configured, else local + fallback."""
        prompt = self._build_prompt(child_data, hcw_instruction)

        if self._prefer_gemini():
            print("[REFERRAL-AI] Using Gemini (REFERRAL_USE_LOCAL_MODEL not set).")
            self.last_generation_source = "gemini"
            return self._generate_gemini(prompt)

        # Try local model first
        if self._model is not None and self._tokenizer is not None:
            try:
                text = self._generate_local(prompt)
                if not self._is_degenerate(text):
                    self.last_generation_source = "local"
                    return text
                print("[REFERRAL-AI] Local output looked degenerate; using Gemini.")
            except Exception as e:
                print(f"[REFERRAL-AI] Local generation failed: {e}")
                print("[REFERRAL-AI] Falling back to Gemini...")

        # Fallback to Gemini
        self.last_generation_source = "gemini"
        return self._generate_gemini(prompt)

    def _clean_response(self, raw: str, prompt: str) -> str:
        """Strip special tokens, echoed prompt, and garbage tails."""
        text = raw
        for tok in _LLAMA_SPECIAL_TOKENS:
            text = text.replace(tok, "")

        # If the model re-emitted the instruction block, keep only the letter part
        letter_marker = "Write the complete referral letter:"
        if letter_marker in text:
            text = text.split(letter_marker, 1)[-1].strip()

        if prompt in text:
            text = text.replace(prompt, "", 1).strip()

        for marker in _LETTER_START_MARKERS:
            idx = text.find(marker)
            if idx != -1:
                text = text[idx:]
                break

        # Cut off classic repetition loops ("the of the of...")
        loop_match = re.search(r"(?:\bthe of\b\s+){8,}", text, flags=re.IGNORECASE)
        if loop_match:
            text = text[: loop_match.start()].rstrip()

        return text.strip()

    def _degenerate_reason(self, text: str) -> str | None:
        """Return why output is unusable, or None if it looks acceptable."""
        if len(text) < 80:
            return "too_short"

        if any(tok in text for tok in _LLAMA_SPECIAL_TOKENS):
            return "special_tokens"

        if text.lower().count("the of") >= 8:
            return "the_of_loop"

        words = re.findall(r"[a-zA-Z']+", text.lower())
        if len(words) >= 60:
            trigrams = Counter(zip(words, words[1:], words[2:]))
            top = trigrams.most_common(1)
            if top and top[0][1] >= 10:
                return f"repeated_trigram:{top[0][0]}"

        looks_like_letter = any(m in text for m in _LETTER_START_MARKERS)
        if not looks_like_letter and len(text) > 400:
            return "not_a_letter"

        return None

    def _is_degenerate(self, text: str) -> bool:
        return self._degenerate_reason(text) is not None

    def _generate_local(self, prompt: str) -> str:
        """Run inference using the local MLX model.
        Must be called from the main thread (where the model was loaded)
        to have access to the GPU stream."""
        from mlx_lm import generate as mlx_generate
        from mlx_lm.sample_utils import make_sampler, make_logits_processors

        # Match training jsonl: plain text, no injected BOS/chat wrappers
        prompt_tokens = self._tokenizer.encode(prompt, add_special_tokens=False)

        sampler = make_sampler(temp=0.35, top_p=0.85)
        logits_processors = make_logits_processors(
            repetition_penalty=1.12,
            repetition_context_size=80,
        )

        raw = mlx_generate(
            self._model,
            self._tokenizer,
            prompt=prompt_tokens,
            max_tokens=512,
            sampler=sampler,
            logits_processors=logits_processors,
        )
        cleaned = self._clean_response(raw, prompt)
        reason = self._degenerate_reason(cleaned)
        print(
            f"[REFERRAL-AI] Local model: raw={len(raw)} chars, "
            f"cleaned={len(cleaned)} chars, degenerate={reason or False}"
        )
        return cleaned

    def _generate_gemini(self, prompt: str) -> str:
        """Fallback: generate using Gemini 2.5 Flash (sync)."""
        from google import genai

        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("No local model available and GEMINI_API_KEY not set.")

        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        text = response.text or ""
        print(f"[REFERRAL-AI] Gemini fallback generated {len(text)} chars.")
        return text

    @classmethod
    def exports_dir(cls) -> Path:
        return _EXPORTS_DIR

    @staticmethod
    def _safe_export_stem(child_name: str) -> str:
        stem = re.sub(r"[^a-zA-Z0-9_-]+", "_", child_name.strip().lower())
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"referral_{stem}_{ts}"

    @staticmethod
    def _cloudinary_configured() -> bool:
        if os.getenv("CLOUDINARY_URL", "").strip():
            return True
        return all(
            os.getenv(k, "").strip()
            for k in (
                "CLOUDINARY_CLOUD_NAME",
                "CLOUDINARY_API_KEY",
                "CLOUDINARY_API_SECRET",
            )
        )

    @staticmethod
    def _configure_cloudinary() -> bool:
        import cloudinary

        url = os.getenv("CLOUDINARY_URL", "").strip()
        if url:
            cloudinary.config(cloudinary_url=url)
            return True
        cloud = os.getenv("CLOUDINARY_CLOUD_NAME", "").strip()
        key = os.getenv("CLOUDINARY_API_KEY", "").strip()
        secret = os.getenv("CLOUDINARY_API_SECRET", "").strip()
        if cloud and key and secret:
            cloudinary.config(cloud_name=cloud, api_key=key, api_secret=secret)
            return True
        return False

    def _publish_export_file(self, tmp_path: str, ext: str, child_name: str) -> dict:
        """Upload to Cloudinary when configured; otherwise serve from local exports dir."""
        stem = self._safe_export_stem(child_name)
        filename = f"{stem}.{ext}"

        if self._cloudinary_configured() and self._configure_cloudinary():
            import cloudinary.uploader

            try:
                result = cloudinary.uploader.upload(
                    tmp_path,
                    resource_type="raw",
                    folder="heartech/referrals",
                    public_id=stem,
                )
                url = result.get("secure_url", "")
                if url:
                    print(f"[REFERRAL-EXPORT] Uploaded to Cloudinary: {url[:80]}...")
                    return {"url": url, "storage": "cloudinary", "filename": filename}
            except Exception as e:
                print(f"[REFERRAL-EXPORT] Cloudinary upload failed ({e}); using local file.")

        dest = _EXPORTS_DIR / filename
        shutil.copy2(tmp_path, dest)
        local_path = f"/api/referral-exports/{filename}"
        print(f"[REFERRAL-EXPORT] Saved locally: {dest}")
        return {"url": local_path, "storage": "local", "filename": filename}

    # ── Export to PDF via ReportLab ───────────────────────────────────────
    def to_pdf_cloudinary(self, referral_text: str, child_name: str) -> dict:
        """Generate PDF; returns {url, storage, filename}."""
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
        from reportlab.lib.units import mm

        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            doc = SimpleDocTemplate(
                tmp_path, pagesize=A4,
                leftMargin=25 * mm, rightMargin=25 * mm,
                topMargin=20 * mm, bottomMargin=20 * mm,
            )
            styles = getSampleStyleSheet()
            title_style = ParagraphStyle(
                "ReferralTitle", parent=styles["Heading1"],
                fontSize=16, spaceAfter=12,
            )
            body_style = ParagraphStyle(
                "ReferralBody", parent=styles["Normal"],
                fontSize=11, leading=15, spaceAfter=6,
            )

            story = [
                Paragraph("Paediatric Hearing Referral", title_style),
                Paragraph(f"Patient: {child_name}", styles["Heading3"]),
                Paragraph(f"Date: {datetime.now().strftime('%d %B %Y')}", styles["Normal"]),
                Spacer(1, 12),
            ]

            for para in referral_text.split("\n"):
                para = para.strip()
                if para:
                    safe = para.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                    story.append(Paragraph(safe, body_style))

            doc.build(story)
            return self._publish_export_file(tmp_path, "pdf", child_name)
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    # ── Export to DOCX ────────────────────────────────────────────────────
    def to_docx_cloudinary(self, referral_text: str, child_name: str) -> dict:
        """Generate DOCX; returns {url, storage, filename}."""
        from docx import Document
        from docx.shared import Pt

        doc = Document()
        doc.add_heading("Paediatric Hearing Referral", level=1)
        doc.add_paragraph(f"Patient: {child_name}")
        doc.add_paragraph(f"Date: {datetime.now().strftime('%d %B %Y')}")
        doc.add_paragraph("")

        for para in referral_text.split("\n"):
            para = para.strip()
            if para:
                p = doc.add_paragraph(para)
                for run in p.runs:
                    run.font.size = Pt(11)

        with tempfile.NamedTemporaryFile(suffix=".docx", delete=False) as tmp:
            tmp_path = tmp.name
            doc.save(tmp_path)

        try:
            return self._publish_export_file(tmp_path, "docx", child_name)
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)