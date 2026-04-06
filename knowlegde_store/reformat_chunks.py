"""
reformat_chunks.py

Reads raw chunks from Chroma, uses Groq to reformat each one into a clean
structured format with overview, recognition, and treatment sections.

Outputs first_aid_chunks.json — replaces the existing file used by both
the Guide tab and the on-device vector search in the iOS app.

Usage:
    python reformat_chunks.py

Cost: ~46 LLM calls, small prompts. Fast and cheap.
"""

import json
import os
import time
import chromadb
from groq import Groq

CHROMA_PATH = "chroma_db"
COLLECTION_NAME = "first_aid"
OUTPUT_PATH = "first_aid_chunks.json"

SYSTEM_PROMPT = """You are a first aid content editor. Your job is to reformat raw first aid
reference text into clean, structured JSON for direct display in a mobile app.

Extract the content into these fields:
- "overview": 1-2 sentence plain-English summary of the condition and aims of treatment.
  Omit if there is nothing meaningful to say beyond what's in recognition/treatment.
- "recognition": array of concise bullet strings describing signs and symptoms to look for.
  Each bullet should be a short phrase, not a full sentence. No leading dashes or bullets.
- "treatment": array of clear numbered step strings. Each step should be one actionable
  instruction. Do not include sub-steps as separate items — fold them into the parent step
  with a colon. No leading numbers.

Rules:
- Preserve all clinical accuracy — do not invent, omit, or soften any medical content
- Remove PDF artefacts, repeated headers, page references, and publisher boilerplate
- If the source text has no clear Recognition section, use an empty array []
- Return ONLY valid JSON with keys: overview, recognition, treatment
- Do not wrap in markdown code fences"""

def reformat(client: Groq, chunk: dict) -> dict:
    prompt = f"""Condition: {chunk['condition']}
Category: {chunk['category']}

Raw text:
{chunk['text']}"""

    response = client.chat.completions.create(
        model="qwen-qwen3-32b" if False else "qwen/qwen3-32b",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
        max_tokens=1024,
        reasoning_effort="none",
    )

    raw = response.choices[0].message.content.strip()

    # Strip markdown fences if the model added them anyway
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    parsed = json.loads(raw)
    return {
        "overview": parsed.get("overview", ""),
        "recognition": parsed.get("recognition", []),
        "treatment": parsed.get("treatment", []),
    }


def main():
    api_key = os.environ.get("GROQ_API_KEY") or open(".env").read().split("=", 1)[1].strip()
    client = Groq(api_key=api_key)

    chroma = chromadb.PersistentClient(path=CHROMA_PATH)
    collection = chroma.get_collection(COLLECTION_NAME)
    results = collection.get(include=["documents", "metadatas"])

    raw_chunks = [
        {
            "id": doc_id,
            "condition": meta.get("condition", ""),
            "category": meta.get("category", ""),
            "severity": meta.get("severity", ""),
            "source": meta.get("source", ""),
            "pageRange": meta.get("page_range", ""),
            "text": doc,
        }
        for doc_id, doc, meta in zip(
            results["ids"], results["documents"], results["metadatas"]
        )
    ]

    raw_chunks.sort(key=lambda c: (c["category"], c["condition"]))

    output = []
    errors = []

    for i, chunk in enumerate(raw_chunks):
        print(f"[{i+1}/{len(raw_chunks)}] {chunk['condition']}...", end=" ", flush=True)
        try:
            structured = reformat(client, chunk)
            output.append({
                "id": chunk["id"],
                "condition": chunk["condition"],
                "category": chunk["category"],
                "severity": chunk["severity"],
                "source": chunk["source"],
                "pageRange": chunk["pageRange"],
                "overview": structured["overview"],
                "recognition": structured["recognition"],
                "treatment": structured["treatment"],
            })
            print("✓")
        except Exception as e:
            print(f"✗ ERROR: {e}")
            errors.append(chunk["condition"])
            # Keep original text as fallback so we don't lose chunks
            output.append({
                "id": chunk["id"],
                "condition": chunk["condition"],
                "category": chunk["category"],
                "severity": chunk["severity"],
                "source": chunk["source"],
                "pageRange": chunk["pageRange"],
                "overview": "",
                "recognition": [],
                "treatment": [chunk["text"]],
            })

        # Respect Groq rate limits
        time.sleep(0.3)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nDone. {len(output)} chunks written to {OUTPUT_PATH}")
    if errors:
        print(f"Errors on: {', '.join(errors)}")


if __name__ == "__main__":
    main()
