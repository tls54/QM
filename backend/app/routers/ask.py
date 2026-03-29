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


def _build_system_prompt(mode: str, context_chunks: list[str], inventory_summary: str) -> str:
    knowledge = "\n\n".join(context_chunks) if context_chunks else "No knowledge base context available yet."

    base = f"""You are QM, an AI assistant specialising in first aid kit management and outdoor preparedness.
You have access to the user's current inventory and a first aid knowledge base.

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
    system_prompt = _build_system_prompt(request.mode, context_chunks, inventory_summary)
    history = [{"role": m.role, "content": m.content} for m in request.history]

    chunks = llm.stream(system_prompt=system_prompt, history=history, user_message=request.query)

    return StreamingResponse(_sse_generator(chunks), media_type="text/event-stream")
