from pydantic import BaseModel
from typing import Optional


# ── Inventory context sent from the iOS app ──────────────────────────────────

class KitItem(BaseModel):
    name: str
    category: str
    quantity: int
    expiry_date: Optional[str] = None  # ISO 8601 date string
    notes: Optional[str] = None


class Kit(BaseModel):
    name: str
    is_store: bool
    kit_category: Optional[str] = None
    items: list[KitItem] = []


class InventoryContext(BaseModel):
    kits: list[Kit] = []


# ── Ask endpoint ──────────────────────────────────────────────────────────────

class ConversationMessage(BaseModel):
    role: str      # "user" | "assistant"
    content: str


class AskRequest(BaseModel):
    query: str
    mode: str = "ask"          # "ask" | "emergency"
    inventory: Optional[InventoryContext] = None
    history: list[ConversationMessage] = []
    use_rag: bool = True       # set False to skip knowledge base retrieval
    model: Optional[str] = None  # overrides server default if provided


class AskResponse(BaseModel):
    answer: str
    mode: str
    sources: list[str] = []    # knowledge base references (populated once RAG is wired in)


# ── Health endpoint ───────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    status: str
    version: str
