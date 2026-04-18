from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from app.auth import require_auth
from app.models.schemas import AskRequest
from app.services import llm, rag

router = APIRouter(dependencies=[Depends(require_auth)])


def _inventory_summary(request: AskRequest) -> str:
    """Serialise the inventory context into a readable string for the prompt."""
    if not request.inventory or not request.inventory.kits:
        return "No inventory context provided."

    lines = []
    for kit in request.inventory.kits:
        label = f"[Store]" if kit.is_store else f"[Kit: {kit.name}]"
        if kit.kit_category:
            label += f" ({kit.kit_category})"
        lines.append(label)
        if kit.items:
            for item in kit.items:
                expiry = f", expires {item.expiry_date}" if item.expiry_date else ""
                notes = f" — {item.notes}" if item.notes else ""
                lines.append(f"  • {item.name} ({item.category}): qty {item.quantity}{expiry}{notes}")
        else:
            lines.append("  (empty)")
    return "\n".join(lines)


def _shopping_summary(request: AskRequest) -> str:
    if not request.shopping_list:
        return "Shopping list is empty."
    lines = []
    for item in request.shopping_list:
        notes = f" — {item.notes}" if item.notes else ""
        lines.append(f"  • {item.name} [{item.status}]{notes}")
    return "\n".join(lines)


def _build_system_prompt(context_chunks: list[str], inventory_summary: str, shopping_summary: str, shopping_list_enabled: bool = False, change_mode: str = "off") -> str:
    has_inventory = inventory_summary != "No inventory context provided."
    has_shopping  = shopping_list_enabled and shopping_summary != "Shopping list is empty."
    has_knowledge = bool(context_chunks)

    # Build a precise access statement so the model doesn't hallucinate capabilities
    access_parts = []
    if has_inventory: access_parts.append("the user's kit inventory")
    if has_shopping:  access_parts.append("their current shopping list")
    if has_knowledge: access_parts.append("a first aid knowledge base")
    if access_parts:
        access_line = "You have access to: " + ", ".join(access_parts) + "."
    else:
        access_line = "No inventory, shopping list, or knowledge base context has been provided for this request."

    knowledge = "\n\n".join(context_chunks) if context_chunks else "No knowledge base context available."

    base = f"""You are QM, a quarter master AI assistant specialising in kit management and outdoor preparedness.
{access_line}

Today's date: {date.today().isoformat()}

## User's Inventory
{inventory_summary}

## Shopping List (needed + ordered items)
{shopping_summary}

## Knowledge Base Context
{knowledge}
"""

    base += """
## Instructions
- Answer clearly and practically using the context provided above
- Use **bold** for key terms, numbered lists for steps, bullet points for lists of items
- Reference the user's inventory specifically when relevant (e.g. "You have X in your Trek kit")
- Keep responses concise — detailed when detail is needed, brief for simple questions
- Only reference items that are present in the inventory above — do not invent items the user doesn't have
- If the question is outside kit management or outdoor preparedness, politely say so
"""

    # Shopping list write — only when enabled by the user.
    # Clearly separate from <changeset> which targets kit inventory and requires user approval.
    if shopping_list_enabled:
        base += """
## Adding to the Shopping List
When your response identifies items the user should buy or restock, you MAY append a shopping block at the very end of your response. These are applied automatically — no confirmation required.

Do NOT include items already present in the Shopping List above.

<shopping>
{"items": [{"name": "Item Name", "notes": "optional context"}]}
</shopping>

Shopping list rules:
- Use this for "things to buy", not for changes to existing kit contents
- Only include when you are genuinely recommending the user acquire something
- Do not duplicate items already on the shopping list above
- Keep names short and clear; notes are optional
- JSON must be valid — no trailing commas
- Output raw tags — do not wrap in a code block
"""

    if change_mode == "apply":
        base += """
## Kit Inventory Changes (requires user approval)
IMPORTANT: This is separate from the shopping list above. A <changeset> modifies items already in the user's kits — it does NOT add things to the shopping list.

When the user has EXPLICITLY asked you to modify their kit inventory, you MAY append a changeset at the very end, after any <shopping> block.

<changeset>
{"operations": [
  {"type": "create_item", "kit_name": "Exact Kit Name", "item": {"name": "Item Name", "category": "Category", "quantity": 1, "notes": ""}},
  {"type": "delete_item", "kit_name": "Exact Kit Name", "item_name": "Item Name"},
  {"type": "update_quantity", "kit_name": "Exact Kit Name", "item_name": "Item Name", "quantity": 5},
  {"type": "create_kit", "kit_name": "New Kit Name", "kit_category": "First Aid"}
]}
</changeset>

Changeset rules — read carefully:
- ONLY include when the user has EXPLICITLY asked to modify their kit (e.g. "add X to my kit", "update my inventory"). General advice does NOT warrant a changeset.
- "I'm thinking of making a kit" or "what would I need for Y?" are NOT explicit requests — do not include a changeset.
- Kit names MUST exactly match names from the inventory above
- Valid categories: Wound Care, Sanitisation, Medications, Airway & Breathing, Immobilisation, Footcare, Tools & Equipment, Navigation, Shelter, Cooking & Water, Lighting, Communication, Other
- JSON must be valid — no trailing commas, no comments
- Output raw tags — do not wrap in a code block
"""

    return base


def _sse_generator(chunks):
    """Yield SSE-formatted tokens from a Groq streaming response."""
    for chunk in chunks:
        content = chunk.choices[0].delta.content
        if content:
            # Escape newlines so each SSE message stays on one line
            yield f"data: {content.replace(chr(10), '\\n')}\n\n"
    yield "data: [DONE]\n\n"


@router.post("/ask")
async def ask(request: AskRequest) -> StreamingResponse:
    if not request.query.strip():
        raise HTTPException(status_code=400, detail="Query must not be empty")

    context_chunks = rag.retrieve(request.query) if request.use_rag else []
    inventory_summary = _inventory_summary(request)
    shopping_summary = _shopping_summary(request)
    system_prompt = _build_system_prompt(context_chunks, inventory_summary, shopping_summary, request.shopping_list_enabled, request.change_mode)
    history = [{"role": m.role, "content": m.content} for m in request.history]

    chunks = llm.stream(system_prompt=system_prompt, history=history, user_message=request.query, model=request.model, reasoning_effort=request.reasoning_effort)

    return StreamingResponse(_sse_generator(chunks), media_type="text/event-stream")
