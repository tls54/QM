import json
from fastapi import APIRouter, Depends, HTTPException
from app.auth import require_auth
from app.models.schemas import AskRequest, AskResponse
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

    base = f"""You are QM, an AI assistant for first aid kit management and outdoor preparedness.
You have access to the user's current inventory and a first aid knowledge base.

## User's Inventory
{inventory_summary}

## Knowledge Base Context
{knowledge}
"""

    if mode == "emergency":
        base += """
## Instructions
The user is in or preparing for an emergency situation. Be concise and direct.
Respond with a numbered step-by-step protocol. Surface any relevant items from
their inventory inline (mark as ✓ if they have it, ✗ if missing).
Do not add preamble or caveats — get straight to the steps.
"""
    else:
        base += """
## Instructions
Answer the user's question helpfully and accurately using the knowledge base and
inventory context above. If inventory is relevant, reference it specifically.
Be clear and practical.
"""
    return base


@router.post("/ask", response_model=AskResponse)
async def ask(request: AskRequest) -> AskResponse:
    if not request.query.strip():
        raise HTTPException(status_code=400, detail="Query must not be empty")

    context_chunks = rag.retrieve(request.query)
    inventory_summary = _inventory_summary(request)
    system_prompt = _build_system_prompt(request.mode, context_chunks, inventory_summary)

    history = [{"role": m.role, "content": m.content} for m in request.history]
    answer = llm.chat(system_prompt=system_prompt, history=history, user_message=request.query)

    return AskResponse(
        answer=answer,
        mode=request.mode,
        sources=context_chunks,
    )
