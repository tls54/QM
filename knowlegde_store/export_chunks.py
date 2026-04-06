"""
export_chunks.py

Exports all chunks from the Chroma 'first_aid' collection to a JSON file
suitable for bundling in the iOS app.

Output: first_aid_chunks.json (in this directory)
Copy the output file to QM/Resources/first_aid_chunks.json before building.

Usage:
    python export_chunks.py
"""

import json
import chromadb

CHROMA_PATH = "chroma_db"
COLLECTION_NAME = "first_aid"
OUTPUT_PATH = "first_aid_chunks.json"


def main():
    client = chromadb.PersistentClient(path=CHROMA_PATH)
    collection = client.get_collection(COLLECTION_NAME)

    results = collection.get(include=["documents", "metadatas"])

    chunks = []
    for doc_id, document, metadata in zip(
        results["ids"], results["documents"], results["metadatas"]
    ):
        chunks.append(
            {
                "id": doc_id,
                "condition": metadata.get("condition", ""),
                "category": metadata.get("category", ""),
                "severity": metadata.get("severity", ""),
                "source": metadata.get("source", ""),
                "pageRange": metadata.get("page_range", ""),
                "text": document,
            }
        )

    # Sort by category then condition for deterministic output
    chunks.sort(key=lambda c: (c["category"], c["condition"]))

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(chunks, f, indent=2, ensure_ascii=False)

    print(f"Exported {len(chunks)} chunks to {OUTPUT_PATH}")
    for category in sorted({c["category"] for c in chunks}):
        count = sum(1 for c in chunks if c["category"] == category)
        print(f"  {category}: {count} condition(s)")


if __name__ == "__main__":
    main()
