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
- **Track items** — quantity, expiry date, notes, and 11 item categories covering first aid and outdoor gear
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
- `AppSchema.swift` manages versioned schema migrations — future model changes can be made without data loss

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
- `POST /ask` — accepts a query, mode, and inventory context; returns an AI-generated response
- `GET /docs` — interactive Swagger UI for testing endpoints

**Configuration**

All config is driven by environment variables. Only `GROQ_API_KEY` is required — everything else has defaults.

| Variable | Default | Description |
|----------|---------|-------------|
| `GROQ_API_KEY` | — | Required. Your Groq API key. |
| `MODEL` | `qwen/qwen3-32b` | LLM model to use |
| `MAX_TOKENS` | `2048` | Maximum tokens in response |
| `TEMPERATURE` | `0.7` | Sampling temperature (0.0–2.0) |
| `TOP_P` | `1.0` | Nucleus sampling |
| `REASONING_EFFORT` | unset | Thinking level for supported models: `none`, `default`, `turbo` |

For production deployment, set these as environment variables in your host rather than using a `.env` file. The backend is currently deployed on Railway — configure the public URL in the iOS app under **Settings → Backend**.

**Architecture**
- FastAPI + Uvicorn
- Groq API for LLM inference (primary: `qwen/qwen3-32b`, 500k context)
- RAG pipeline over a first aid knowledge base (in progress — `services/rag.py`)
- Inventory is sent per-request as JSON — no shared database between app and backend

---

## AI modes (Stream 3)

**Ask mode** — conversational interface for planning and advice. Inventory context and RAG-retrieved knowledge base chunks are injected into each request.

**Emergency mode** — fast, tap-based interface designed for in-situation use. User selects an injury or scenario and gets a clean numbered protocol with relevant inventory items surfaced inline (have ✓ / missing ✗). Designed to be usable under stress, no typing required.

---

## Secrets

Never commit API keys. The `secrets/` directory and `.env` files are gitignored. Use `.env.example` as a template.
