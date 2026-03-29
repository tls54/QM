from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── API security ──────────────────────────────────────────────────────────
    secret_key: str  # Bearer token required on all protected endpoints

    # ── Groq credentials ──────────────────────────────────────────────────────
    groq_api_key: str

    # ── Model selection ───────────────────────────────────────────────────────
    # Primary: qwen/qwen3-32b (500k context, supports thinking)
    # Fallback: llama-3.3-70b-versatile (100k context)
    model: str = "qwen/qwen3-32b"

    # ── Generation parameters ─────────────────────────────────────────────────
    max_tokens: int = 2048
    temperature: float = 0.7
    top_p: float = 1.0

    # ── Thinking / reasoning ──────────────────────────────────────────────────
    # Groq exposes thinking via `reasoning_effort` for supported models.
    # Values: "none" | "default" | "turbo"
    # - "none"    → thinking disabled, fastest response
    # - "default" → model decides effort level
    # - "turbo"   → maximum thinking, slower but more thorough
    # Set to None to omit the parameter entirely (safest for models that
    # don't support it — Groq will raise an error if passed unsupported params).
    reasoning_effort: Optional[str] = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
