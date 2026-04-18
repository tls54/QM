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


def _build_system_prompt(mode: str, context_chunks: list[str], inventory_summary: str, change_mode: str = "off") -> str:
    knowledge = "\n\n".join(context_chunks) if context_chunks else "No knowledge base context available yet."

    base = f"""You are QM, an AI assistant specialising in first aid kit management and outdoor preparedness.
You have access to the user's current inventory and a first aid knowledge base.

Today's date: {date.today().isoformat()}

## User's Inventory
{inventory_summary}

## Knowledge Base Context
{knowledge}
"""

    if mode == "emergency":
        base += """
## Instructions
The user is in an emergency. Respond ONLY with a numbered step-by-step protocol.
- No preamble, no caveats, no sign-off
- One sentence per step, lead with a verb
- For each step requiring an item, append ✓ if the user has it or ✗ if missing, based on their inventory above
- If quantity is 0, treat as missing (✗)
"""
    else:
        base += """
## Instructions
- Answer clearly and practically using the knowledge base and inventory context above
- Use **bold** for key terms, numbered lists for steps, bullet points for lists of items
- Reference the user's inventory specifically when relevant (e.g. "You have X in your Trek kit")
- Keep responses concise — detailed when detail is needed, brief for simple questions
- Only reference items that are present in the inventory above — do not invent items the user doesn't have
- If the question is outside first aid, kit management, or outdoor preparedness, politely say so
"""

    if change_mode == "apply":
        base += """

## Kit Change Proposals
When your response recommends specific changes to the user's kit inventory, you MAY append a structured changeset at the very end of your response.

Include a changeset only when proposing concrete, actionable changes (e.g. "add X to your kit", "restock Y"). Do not include one for general advice or questions.

<changeset>
{"operations": [
  {"type": "create_item", "kit_name": "Exact Kit Name", "item": {"name": "Item Name", "category": "Category", "quantity": 1, "notes": ""}},
  {"type": "delete_item", "kit_name": "Exact Kit Name", "item_name": "Item Name"},
  {"type": "update_quantity", "kit_name": "Exact Kit Name", "item_name": "Item Name", "quantity": 5},
  {"type": "create_kit", "kit_name": "New Kit Name", "kit_category": "First Aid"}
]}
</changeset>

Rules — read carefully:
- ONLY include a changeset when the user has EXPLICITLY asked you to modify their kit (e.g. "add X to my kit", "can you add those items?", "update my inventory with these"). General questions, planning discussions, and advice responses do NOT warrant a changeset.
- A user saying "I'm thinking of making a kit for X" or "what would I need for Y?" is NOT an explicit request to apply changes — do not include a changeset.
- If you mention items in your advice but the user hasn't asked you to add them, do not include a changeset.
- Kit names MUST exactly match names from the user's inventory above — do not invent or paraphrase kit names.
- Valid categories: Wound Care, Sanitisation, Medications, Airway & Breathing, Immobilisation, Footcare, Tools & Equipment, Navigation, Shelter, Cooking & Water, Lighting, Communication, Other
- JSON must be valid — no trailing commas, no comments
- Place the changeset block at the very end of your response, after all text
- Do not wrap the changeset in a code block or markdown — output the raw tags
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
    system_prompt = _build_system_prompt(request.mode, context_chunks, inventory_summary, request.change_mode)
    history = [{"role": m.role, "content": m.content} for m in request.history]

    chunks = llm.stream(system_prompt=system_prompt, history=history, user_message=request.query, model=request.model, reasoning_effort=request.reasoning_effort)

    return StreamingResponse(_sse_generator(chunks), media_type="text/event-stream")
