# QM — Kit Manager

A local-first iOS app for managing first aid and outdoor equipment inventory, with an AI assistant layer for situational advice and emergency protocols.

## Status

| Stream | Description | Status |
|--------|-------------|--------|
| 1 | First Aid Kit Manager | ✅ Complete |
| 2 | General Outdoors Kit Manager | ✅ Complete |
| 3 | AI Assistant (Ask mode live, Emergency mode pending) | 🚧 In Progress |

---

## What it does

- **Manage kits** — create named kits (Trek, Leader, Camp, etc.) with custom icons and colours, grouped by category (Medical, Sharps, Equipment, etc.)
- **Track items** — quantity, expiry date, size, notes, and 13 item categories covering first aid and outdoor gear
- **Store inventory** — a special store/stockroom kit that's always present; move items between kits
- **Inventory view** — aggregates quantities across all kits, surfaces the worst expiry status per item
- **Expiry and stock alerts** — configurable expiry warning threshold and low stock threshold
- **AI assistant** (Stream 3) — conversational Ask mode (live) and a tap-based Emergency mode with step-by-step protocols referenced against your current inventory (in progress)

---

## Repo structure

```
QM/                   iOS app (SwiftUI + SwiftData)
backend/              FastAPI AI backend (Python + Docker)
CLAUDE.md             Project brief and architecture decisions (source of truth)
```

---

## iOS App

**Requirements**
- Xcode 16+
- iOS 18+ deployment target
- Physical device or simulator

**Setup**

Open `QM.xcodeproj` in Xcode, select your target device, and build. No external dependencies — the app uses only Apple frameworks (SwiftUI, SwiftData).

The app is fully functional offline. AI features (Stream 3) require the backend to be running.

**Architecture**
- SwiftUI for all UI
- SwiftData for local persistence (SQLite under the hood)
- SwiftData handles schema migrations automatically — all changes to date have been additive (new model types, new optional properties)

---

## Backend

**Requirements**
- Docker and Docker Compose

**Setup**

```bash
cd backend
cp .env.example .env
# Add your GROQ_API_KEY to .env
docker compose up --build
```

The API will be available at `http://localhost:8000`.

- `GET /health` — returns status and version
- `POST /ask` — accepts a query, mode, inventory context, and optional model override; streams an AI-generated response via SSE
- `GET /models` — returns available Groq models (auth required)
- `GET /docs` — interactive Swagger UI for testing endpoints

**Configuration**

All config is driven by environment variables. See `.env.example` for the full list.

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | — | Required. Bearer token used by the iOS app to authenticate requests. |
| `GROQ_API_KEY` | — | Required. Your Groq API key. |
| `VOYAGE_API_KEY` | — | Required. Your Voyage AI key for query embeddings. |
| `MODEL` | `qwen/qwen3-32b` | LLM model to use |
| `MAX_TOKENS` | `2048` | Maximum tokens in response |
| `TEMPERATURE` | `0.7` | Sampling temperature (0.0–2.0) |
| `TOP_P` | `1.0` | Nucleus sampling |
| `REASONING_EFFORT` | unset | Thinking level for supported models: `none`, `default`, `turbo` |

For production deployment, set these as environment variables in Railway rather than using a `.env` file. Configure the public URL and secret key in the iOS app under **Settings → Backend**.

**Architecture**
- FastAPI + Uvicorn, deployed on Railway
- Groq API for LLM inference (`qwen/qwen3-32b`, streamed via SSE)
- RAG pipeline: Voyage AI (`voyage-4`) for query embeddings, Chroma for vector search (46 chunks, St John Ambulance First Aid Reference Guide)
- Chroma index ships baked into the Docker image (`backend/chroma_db/`)
- Bearer token auth on all `/ask` requests
- Inventory sent per-request as JSON — no shared database between app and backend

---

## AI modes (Stream 3)

**Ask mode** — conversational interface for planning and advice. Supports multi-turn conversation history, selective kit attachment, on-device chat history, toggleable first aid knowledge base, long-press to copy, and token-by-token streaming. Includes an AI disclaimer on first use and a persistent footer. Model can be overridden per-device in Settings.

**Search mode** — on-device semantic search over the first aid knowledge base using `NLContextualEmbedding`. Embeddings are built on first use and cached to disk. Results link to full condition detail views with structured Recognition and Treatment sections. Gated behind the Advanced toggle (see below).

**Guide tab** — browse and search the St John Ambulance First Aid Reference Guide by category, fully offline. Gated behind the Advanced toggle.

The **knowledge base toggle** (book icon) in Ask mode is also gated — when the Advanced toggle is off, the RAG pipeline is disabled and no SJA content is used at any point.

---

## Medical knowledge features

The Guide tab and Search mode are powered by content from the **St John Ambulance First Aid Reference Guide** (UK).

> **Personal use only.** This content is used under St John Ambulance's personal use terms and is not licensed for redistribution. These features are disabled by default and must be explicitly enabled in **Settings → Advanced → Medical Knowledge Features**. Do not enable this flag in any build intended for distribution until a redistribution licence has been obtained or the content has been replaced with original material.

---

## Secrets

Never commit API keys. The `secrets/` directory and `.env` files are gitignored. Use `.env.example` as a template.
