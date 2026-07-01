"""FastMCP server mounted at /mcp on the FastAPI app.

Auth is enforced via an ASGI wrapper applied when mounting — see main.py.
"""

import os

from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings

# Allow the Railway public hostname (and localhost for local dev).
# Populated from MCP_ALLOWED_HOSTS env var (comma-separated) so no code
# change is needed when the hostname changes.
_extra = [h.strip() for h in os.getenv("MCP_ALLOWED_HOSTS", "").split(",") if h.strip()]
_allowed_hosts = ["localhost", "127.0.0.1", *_extra]

mcp = FastMCP(
    "QM Kit Manager",
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=_allowed_hosts,
    ),
)


# ── Tools ─────────────────────────────────────────────────────────────────────

@mcp.tool()
def ping() -> str:
    """Confirm the QM MCP server is reachable and auth is working."""
    return "QM Kit Manager is online and your token is valid."
