from fastapi import APIRouter, Depends
from app.auth import require_auth
from app.services.llm import get_client

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/models")
def list_models() -> list[dict]:
    """Return available Groq models, sorted by ID."""
    client = get_client()
    response = client.models.list()
    models = [
        {"id": m.id, "owned_by": m.owned_by}
        for m in sorted(response.data, key=lambda m: m.id)
    ]
    return models
