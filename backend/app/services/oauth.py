"""OAuth 2.0 Authorization Code + PKCE logic for the QM backend.

Single-user personal tool — no user database. The SECRET_KEY env var serves
as both the JWT signing secret and the approval password on the consent page.
"""

import base64
import hashlib
import os
import secrets
import time
from datetime import datetime, timezone

import jwt

from app.config import get_settings

# ── Token lifetimes ───────────────────────────────────────────────────────────

ACCESS_TOKEN_TTL  = 60 * 60          # 1 hour
REFRESH_TOKEN_TTL = 60 * 60 * 24 * 90  # 90 days
DEVICE_TOKEN_TTL  = 60 * 60 * 24 * 365  # 1 year (iOS long-lived)
AUTH_CODE_TTL     = 60 * 10          # 10 minutes

# ── In-memory auth code store ─────────────────────────────────────────────────
# Single Railway instance + single user → a plain dict is fine.

_codes: dict[str, dict] = {}


def _signing_key() -> str:
    return get_settings().secret_key


# ── PKCE helpers ──────────────────────────────────────────────────────────────

def _verify_pkce(verifier: str, challenge: str, method: str) -> bool:
    if method == "S256":
        digest = hashlib.sha256(verifier.encode()).digest()
        computed = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()
        return computed == challenge
    if method == "plain":
        return verifier == challenge
    return False


# ── Auth code ─────────────────────────────────────────────────────────────────

def create_auth_code(
    redirect_uri: str,
    code_challenge: str,
    code_challenge_method: str,
) -> str:
    code = secrets.token_urlsafe(32)
    _codes[code] = {
        "redirect_uri": redirect_uri,
        "code_challenge": code_challenge,
        "code_challenge_method": code_challenge_method,
        "expires_at": time.time() + AUTH_CODE_TTL,
    }
    return code


def exchange_code(
    code: str,
    code_verifier: str,
    redirect_uri: str,
) -> tuple[str, str] | None:
    entry = _codes.pop(code, None)
    if entry is None:
        return None
    if time.time() > entry["expires_at"]:
        return None
    if entry["redirect_uri"] != redirect_uri:
        return None
    if not _verify_pkce(code_verifier, entry["code_challenge"], entry["code_challenge_method"]):
        return None
    return _issue_tokens()


# ── JWT helpers ───────────────────────────────────────────────────────────────

def _issue_tokens() -> tuple[str, str]:
    """Return (access_token, refresh_token)."""
    return (
        _make_jwt("access", ACCESS_TOKEN_TTL),
        _make_jwt("refresh", REFRESH_TOKEN_TTL),
    )


def _make_jwt(token_type: str, ttl: int) -> str:
    now = int(time.time())
    payload = {
        "sub": "qm-owner",
        "type": token_type,
        "iat": now,
        "exp": now + ttl,
    }
    return jwt.encode(payload, _signing_key(), algorithm="HS256")


def refresh_access_token(refresh_token: str) -> str | None:
    try:
        claims = jwt.decode(refresh_token, _signing_key(), algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    if claims.get("type") != "refresh":
        return None
    return _make_jwt("access", ACCESS_TOKEN_TTL)


def issue_device_token() -> str:
    """Long-lived token for the iOS app — issued once via the bootstrap endpoint."""
    return _make_jwt("device", DEVICE_TOKEN_TTL)


def verify_token(token: str) -> dict | None:
    """Return claims if valid access/device token, else None."""
    try:
        claims = jwt.decode(token, _signing_key(), algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    if claims.get("type") not in ("access", "device"):
        return None
    return claims
