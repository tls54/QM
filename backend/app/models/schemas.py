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


class ShoppingItemContext(BaseModel):
    name: str
    notes: Optional[str] = None
    status: str  # "needed" | "ordered"


class AskRequest(BaseModel):
    query: str
    mode: str = "ask"          # "ask" | "search" (emergency mode removed)
    inventory: Optional[InventoryContext] = None
    shopping_list: list[ShoppingItemContext] = []
    history: list[ConversationMessage] = []
    use_rag: bool = True       # set False to skip knowledge base retrieval
    model: Optional[str] = None  # overrides server default if provided
    shopping_list_enabled: bool = False    # whether LLM has shopping list write access
    change_mode: str = "off"               # "off" | "apply"
    reasoning_effort: Optional[str] = None  # "none" | "low" | "medium" | "high"


class AskResponse(BaseModel):
    answer: str
    mode: str
    sources: list[str] = []    # knowledge base references (populated once RAG is wired in)


# ── Health endpoint ───────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    status: str
    version: str
