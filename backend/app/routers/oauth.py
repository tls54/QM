"""OAuth 2.0 Authorization Code + PKCE endpoints plus iOS device-token bootstrap.

Endpoints
─────────
GET  /.well-known/oauth-authorization-server   — metadata discovery (claude.ai reads this)
GET  /oauth/authorize                           — consent page (HTML)
POST /oauth/authorize                           — approve: validate password → redirect with code
POST /oauth/token                               — exchange code or refresh token → JWT
GET  /auth/device-token                         — one-time iOS bootstrap: SECRET_KEY → long-lived JWT
"""

from urllib.parse import urlencode

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import get_settings
from app.services.oauth import (
    create_auth_code,
    exchange_code,
    issue_device_token,
    refresh_access_token,
    verify_token,
)

router = APIRouter()

_bearer = HTTPBearer()


# ── OAuth metadata discovery ──────────────────────────────────────────────────

@router.get("/.well-known/oauth-authorization-server", include_in_schema=False)
def oauth_metadata(request: Request):
    base = str(request.base_url).rstrip("/")
    return {
        "issuer": base,
        "authorization_endpoint": f"{base}/oauth/authorize",
        "token_endpoint": f"{base}/oauth/token",
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "code_challenge_methods_supported": ["S256"],
        "token_endpoint_auth_methods_supported": ["none"],
    }


# ── Consent page ──────────────────────────────────────────────────────────────

def _consent_html(
    client_id: str,
    redirect_uri: str,
    code_challenge: str,
    code_challenge_method: str,
    state: str,
    error: str = "",
) -> str:
    error_block = f'<p class="error">{error}</p>' if error else ""
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>QM — Authorise Access</title>
  <style>
    body {{ font-family: system-ui, sans-serif; max-width: 420px; margin: 80px auto; padding: 0 24px; color: #111; }}
    h1 {{ font-size: 1.4rem; margin-bottom: 4px; }}
    p  {{ color: #555; font-size: 0.95rem; }}
    .error {{ color: #c0392b; }}
    label {{ display:block; margin-top: 20px; font-weight: 600; font-size: 0.9rem; }}
    input[type=password] {{ width: 100%; padding: 10px; font-size: 1rem; border: 1px solid #ccc; border-radius: 6px; margin-top: 6px; box-sizing: border-box; }}
    button {{ margin-top: 20px; width: 100%; padding: 12px; background: #0d9488; color: #fff; border: none; border-radius: 6px; font-size: 1rem; cursor: pointer; }}
    button:hover {{ background: #0f766e; }}
    .meta {{ margin-top: 24px; font-size: 0.8rem; color: #999; word-break: break-all; }}
  </style>
</head>
<body>
  <h1>QM Kit Manager</h1>
  <p>A client is requesting access to your kit inventory.</p>
  {error_block}
  <form method="post">
    <input type="hidden" name="client_id"             value="{client_id}">
    <input type="hidden" name="redirect_uri"           value="{redirect_uri}">
    <input type="hidden" name="code_challenge"         value="{code_challenge}">
    <input type="hidden" name="code_challenge_method"  value="{code_challenge_method}">
    <input type="hidden" name="state"                  value="{state}">
    <label for="password">Secret key</label>
    <input type="password" id="password" name="password" autofocus placeholder="Enter your QM secret key">
    <button type="submit">Approve</button>
  </form>
  <p class="meta">Redirecting to: {redirect_uri}</p>
</body>
</html>"""


@router.get("/oauth/authorize", response_class=HTMLResponse, include_in_schema=False)
def authorize_get(
    response_type: str,
    client_id: str,
    redirect_uri: str,
    code_challenge: str,
    code_challenge_method: str = "S256",
    state: str = "",
):
    if response_type != "code":
        raise HTTPException(400, "Only response_type=code is supported")
    return _consent_html(client_id, redirect_uri, code_challenge, code_challenge_method, state)


@router.post("/oauth/authorize", response_class=HTMLResponse, include_in_schema=False)
def authorize_post(
    client_id: str        = Form(...),
    redirect_uri: str     = Form(...),
    code_challenge: str   = Form(...),
    code_challenge_method: str = Form("S256"),
    state: str            = Form(""),
    password: str         = Form(...),
):
    if password != get_settings().secret_key:
        return HTMLResponse(
            _consent_html(client_id, redirect_uri, code_challenge, code_challenge_method, state, error="Incorrect secret key."),
            status_code=401,
        )

    code = create_auth_code(redirect_uri, code_challenge, code_challenge_method)
    params = {"code": code}
    if state:
        params["state"] = state
    return RedirectResponse(f"{redirect_uri}?{urlencode(params)}", status_code=302)


# ── Token endpoint ────────────────────────────────────────────────────────────

@router.post("/oauth/token", include_in_schema=False)
def token(
    grant_type: str    = Form(...),
    code: str          = Form(None),
    redirect_uri: str  = Form(None),
    code_verifier: str = Form(None),
    refresh_token: str = Form(None),
):
    if grant_type == "authorization_code":
        if not (code and redirect_uri and code_verifier):
            raise HTTPException(400, "Missing code, redirect_uri, or code_verifier")
        result = exchange_code(code, code_verifier, redirect_uri)
        if result is None:
            raise HTTPException(400, "Invalid or expired code")
        access_token, new_refresh = result
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 3600,
            "refresh_token": new_refresh,
        }

    if grant_type == "refresh_token":
        if not refresh_token:
            raise HTTPException(400, "Missing refresh_token")
        access_token = refresh_access_token(refresh_token)
        if access_token is None:
            raise HTTPException(400, "Invalid or expired refresh token")
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 3600,
        }

    raise HTTPException(400, f"Unsupported grant_type: {grant_type}")


# ── iOS device-token bootstrap ────────────────────────────────────────────────

@router.get("/auth/device-token")
def device_token(credentials: HTTPAuthorizationCredentials = Depends(_bearer)):
    """One-time call from the iOS app (sends SECRET_KEY as Bearer) → returns a long-lived JWT.

    After this, the iOS app stores the JWT and uses it for all future requests.
    The raw SECRET_KEY is never sent again after the initial bootstrap.
    """
    if credentials.credentials != get_settings().secret_key:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid secret key")
    return {"access_token": issue_device_token(), "token_type": "bearer"}
