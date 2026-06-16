"""Stealth runtime cloud generation provider."""

from __future__ import annotations

import json
from urllib import error, request

from heartech_ai.runtime.runtime_credentials import RuntimeCredentials, load_runtime_credentials


class RuntimeCloudProvider:
    _API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
    _DEFAULT_MODEL = "gemini-2.0-flash"
    _ALIAS_MAP = {
        "flash": _DEFAULT_MODEL,
    }

    def _load_config(self) -> RuntimeCredentials:
        return load_runtime_credentials()

    @classmethod
    def _resolve_model(cls, config_model: str) -> str:
        clean = config_model.strip().removeprefix("models/").strip()
        if not clean:
            return cls._DEFAULT_MODEL
        return cls._ALIAS_MAP.get(clean.lower(), clean)

    @classmethod
    def _is_supported_model_name(cls, model_name: str) -> bool:
        return model_name.startswith("gemini-")

    @staticmethod
    def _bucket_error(code: str) -> str:
        if code.startswith("http_429"):
            return "rate_limit"
        if code.startswith("http_404"):
            return "bad_model_or_endpoint"
        if code.startswith("http_"):
            return "http_other"
        if code == "network":
            return "network"
        return "request"

    @staticmethod
    def _error_code(exc: Exception) -> str:
        if isinstance(exc, error.HTTPError):
            if exc.code == 429:
                try:
                    body = exc.read().decode("utf-8", "ignore").lower()
                except Exception:
                    body = ""
                if "quota" in body or "resource_exhausted" in body:
                    return "http_429_quota"
                return "http_429"
            return f"http_{exc.code}"
        if isinstance(exc, error.URLError):
            return "network"
        return "request_error"

    def is_available(self) -> bool:
        return self._load_config().enabled

    def generate(self, prompt: str, *, max_tokens: int) -> str:
        cfg = self._load_config()
        if not cfg.enabled:
            raise RuntimeError("runtime_cloud_unavailable")

        model_name = self._resolve_model(cfg.model)
        if not self._is_supported_model_name(model_name):
            print("[REFERRAL-AI] v5_fused_retry cloud config warning (model alias unsupported).")

        bucket_counts: dict[str, int] = {
            "rate_limit": 0,
            "bad_model_or_endpoint": 0,
            "http_other": 0,
            "network": 0,
            "request": 0,
        }
        try:
            text = self._generate_once(
                base=self._API_BASE,
                model_name=model_name,
                api_key=cfg.key,
                prompt=prompt,
                max_tokens=max_tokens,
            )
            if text:
                return text
            raise RuntimeError("runtime_cloud_failed")
        except Exception as exc:
            error_code = self._error_code(exc)
            bucket = self._bucket_error(error_code)
            bucket_counts[bucket] = bucket_counts.get(bucket, 0) + 1
            print(f"[REFERRAL-AI] v5_fused_retry cloud attempt failed ({error_code}).")
            print(f"[REFERRAL-AI] v5_fused_retry cloud failure buckets: {bucket_counts}.")
            if bucket == "rate_limit":
                print(
                    "[REFERRAL-AI] v5_fused_retry cloud hint: check key quota/billing "
                    "and per-minute request limits."
                )
            if bucket == "bad_model_or_endpoint":
                print(
                    "[REFERRAL-AI] v5_fused_retry cloud hint: check runtime model alias "
                    "in backend/.runtime/credentials."
                )
            raise RuntimeError("runtime_cloud_failed") from exc

    @staticmethod
    def _generate_once(
        *,
        base: str,
        model_name: str,
        api_key: str,
        prompt: str,
        max_tokens: int,
    ) -> str:
        url = f"{base}/{model_name}:generateContent?key={api_key}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.0,
                "topP": 0.95,
                "maxOutputTokens": min(max(max_tokens, 420), 512),
            },
        }
        req = request.Request(
            url=url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
        data = json.loads(raw)
        candidates = data.get("candidates") or []
        if not candidates:
            return ""
        parts = candidates[0].get("content", {}).get("parts", [])
        return "\n".join(p.get("text", "").strip() for p in parts if p.get("text")).strip()
