"""Password login for the browser inventory webapp.

Not part of the OAuth flow used by the iOS app / MCP — just a shared
password exchanged for a long-lived JWT the SPA stores and sends as a
bearer token on /inventory/* requests.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.config import get_settings
from app.services.oauth import issue_webapp_token

router = APIRouter(prefix="/webapp", tags=["webapp"])


class LoginRequest(BaseModel):
    password: str


class LoginResponse(BaseModel):
    token: str


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest) -> LoginResponse:
    settings = get_settings()
    if not settings.webapp_password or body.password != settings.webapp_password:
        raise HTTPException(status_code=401, detail="Incorrect password")
    return LoginResponse(token=issue_webapp_token())
