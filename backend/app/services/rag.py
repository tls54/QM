# RAG pipeline — stub for now, to be implemented in Stream 3.
#
# Will be responsible for:
#   - Loading and chunking the first aid knowledge base
#   - Embedding and storing chunks in the vector store
#   - Retrieving relevant chunks given a query
#   - Returning context strings to be injected into the LLM prompt


def retrieve(query: str, top_k: int = 5) -> list[str]:
    """Return relevant knowledge base chunks for a given query.

    Stub: returns empty list until the knowledge base and vector store
    are wired in.
    """
    return []
