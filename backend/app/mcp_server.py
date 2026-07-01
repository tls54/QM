"""FastMCP server mounted at /mcp on the FastAPI app.

Auth is enforced via an ASGI wrapper applied when mounting — see main.py.
"""

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("QM Kit Manager")


# ── Tools ─────────────────────────────────────────────────────────────────────

@mcp.tool()
def ping() -> str:
    """Confirm the QM MCP server is reachable and auth is working."""
    return "QM Kit Manager is online and your token is valid."
