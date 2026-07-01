from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import Base, engine
from app.models import db as db_models  # noqa: F401 (registers ORM models with Base)
from app.mcp_server import mcp
from app.routers import health, ask, models, inventory, oauth
from app.services.oauth import verify_token


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    async with mcp.session_manager.run():
        yield


app = FastAPI(
    title="QM Backend",
    description="First aid and kit management AI assistant API",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(health.router)
app.include_router(oauth.router)
app.include_router(ask.router)
app.include_router(models.router)
app.include_router(inventory.router)

def _mcp_auth_wrapper(asgi_app):
    """Gate /mcp requests behind JWT auth; pass all other paths straight through.

    The Mount("/", ...) pattern intercepts everything FastAPI doesn't fully match
    (including method-not-allowed cases), so we must only enforce auth on /mcp.
    """
    async def wrapped(scope, receive, send):
        if scope["type"] == "http" and scope.get("path", "").startswith("/mcp"):
            headers = dict(scope.get("headers", []))
            host = headers.get(b"host", b"").decode()
            scheme = "https" if headers.get(b"x-forwarded-proto", b"http").decode() == "https" else "http"
            base = f"{scheme}://{host}"
            resource_meta = f"{base}/.well-known/oauth-protected-resource"

            auth = headers.get(b"authorization", b"").decode()
            token = auth.removeprefix("Bearer ").strip() if auth.startswith("Bearer ") else ""
            if not token or verify_token(token) is None:
                www_auth = f'Bearer realm="QM Kit Manager", resource_metadata="{resource_meta}"'
                await send({
                    "type": "http.response.start",
                    "status": 401,
                    "headers": [
                        (b"www-authenticate", www_auth.encode()),
                        (b"content-type", b"application/json"),
                    ],
                })
                await send({"type": "http.response.body", "body": b'{"error":"Unauthorized"}'})
                return
        await asgi_app(scope, receive, send)
    return wrapped


# The streamable_http_app exposes its own route at /mcp internally.
# Mounting at / (after all specific routes) lets FastAPI handle our routes
# first; unmatched /mcp requests fall through to the MCP sub-app.
app.mount("/", _mcp_auth_wrapper(mcp.streamable_http_app()))
