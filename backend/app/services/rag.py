import os
from functools import lru_cache

import chromadb
import voyageai

from app.config import get_settings

# Path to the persisted Chroma index, relative to the backend root
_CHROMA_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "chroma_db")
_COLLECTION_NAME = "first_aid"


@lru_cache
def _get_collection() -> chromadb.Collection:
    client = chromadb.PersistentClient(path=os.path.abspath(_CHROMA_PATH))
    return client.get_collection(_COLLECTION_NAME)


@lru_cache
def _get_voyage() -> voyageai.Client:
    return voyageai.Client(api_key=get_settings().voyage_api_key)


def retrieve(query: str, top_k: int = 3) -> list[str]:
    """Embed the query with Voyage AI and return the top-k knowledge base chunks."""
    voyage = _get_voyage()
    result = voyage.embed([query], model="voyage-4", input_type="query")
    query_embedding = result.embeddings[0]

    collection = _get_collection()
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=top_k,
        include=["documents", "metadatas"],
    )

    chunks = []
    for doc, meta in zip(results["documents"][0], results["metadatas"][0]):
        condition = meta.get("condition", "")
        category = meta.get("category", "")
        header = f"[{category} — {condition}]" if condition and category else ""
        chunks.append(f"{header}\n{doc}".strip())

    return chunks
