from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from app.config import get_settings

_bearer = HTTPBearer()


def require_auth(credentials: HTTPAuthorizationCredentials = Depends(_bearer)) -> None:
    if credentials.credentials != get_settings().secret_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or missing token")
