# Kit Manager — Project Brief

## Product Vision

A three-stream iOS app for managing first aid and outdoor equipment inventory, with an AI assistant layer.

### Stream 1 — First Aid Kit Manager (MVP) ✓ COMPLETE
Track and manage first aid inventory across a store/stockroom and multiple individual first aid kits.
Core entities: Store inventory, First aid kits, Items (with quantity, expiry date, location).

**Implemented:**
- `Kit` — named kit with `isStore` flag, `kitCategory` (free text), `kitIcon` (SF Symbol), `kitIconColor` (8 presets); Store auto-seeded on first launch and cannot be deleted
- `KitItem` — name, category, quantity, optional expiry date, notes
- `ItemCategory` — 6 categories: Wound Care, Medications, Tools & Equipment, Airway & Breathing, Immobilisation, Other (all with filled SF Symbol icons)
- Expiry status: expired (<today), expiring soon (configurable threshold), ok, no expiry — natural language labels + colour/icon indicators
- Stock status: out of stock (qty=0) shown red, low stock (qty ≤ configurable threshold) shown orange — on item rows and kit list summary
- Move item between kits — available when editing an existing item
- **Kits tab**: Store section always first; regular kits grouped into sections by `kitCategory`; swipe-left edit, swipe-right delete
- **Inventory tab**: aggregates all items across all kits by name+category, summing quantities and surfacing worst expiry status
- Items grouped by category in both detail and inventory views; tap to edit, swipe to delete
- **Settings tab**: appearance (system/light/dark), expiry warning threshold (7/14/30/60/90 days), low stock threshold (1–20), clear all data, app version/build
- **Assets**: teal accent colour (`#0D9488`), app icon (light/dark/tinted variants) generated with cross + "QM"
- **Icon picker**: curated grid of ~60 SF Symbols across 6 categories; per-kit colour picker (8 options)
- **SwiftData migration plan** in place (`AppSchema.swift`) — future schema changes can be versioned without data loss

### Stream 2 — General Outdoors Kit Manager ✓ COMPLETE
Extend the inventory model beyond first aid to general outdoor gear and kits.
Same data model as Stream 1 — broader `ItemCategory` cases added: Navigation, Shelter, Cooking & Water, Lighting, Communication.

### Stream 3 — AI Assistant (In Progress)
Two UI modes, one knowledge base, one backend:

**"Ask" mode — conversational AI**
- Chat interface for calm/planning use
- Use cases: situational advice ("someone has a burn, what do I do?"), inventory-aware queries ("what can I treat with what I have?"), kit gap analysis, trip planning ("what do I need for a 4-person hiking trip?"), restock suggestions
- Full RAG + inventory context passed per request
- Takes time, returns detailed responses
- Requires network

**"Emergency" mode — guided protocol UI**
- Fast, tap-based interface for in-situation use
- User taps an injury/scenario type → gets a clean numbered protocol
- Relevant inventory items surfaced inline (have ✓ / missing ✗)
- No typing required, minimal reading, works under stress
- Protocols pre-mapped from the first aid knowledge base
- Should be usable offline where possible (cached protocols)
- This is a UI/UX priority — design for shaking hands

Both modes are powered by the same first aid knowledge base and FastAPI backend.

---

## Architecture Decisions

### iOS App
- **SwiftUI** for all UI
- **SwiftData** for local persistence (Swift-native ORM over SQLite)
- Local-first: app is fully functional offline; AI features require network
- No CloudKit sync in MVP

### AI Backend
- **FastAPI** (Python) — separate backend service
- Hosts RAG pipeline and LLM calls
- App sends inventory context as JSON payload with each AI request (no persistent sync needed for MVP)

### LLM Provider
- **Groq** for development and initial build — fast inference, generous free tier
- **Primary model**: `qwen/qwen3-32b` — 500k context window, preferred for RAG (large context useful for stuffing knowledge base)
- **Secondary model**: `llama-3.3-70b` — 100k context window, fallback or comparison
- Provider and model to be reassessed before any production release — likely migrate to Anthropic API
- Groq API key stored server-side in FastAPI, never in the iOS app

### RAG / Vector Store
- TBD — owner leads on this given Python/AI background
- Candidates: Chroma (local dev), Pinecone, Supabase pgvector
- Decision to be made when building the knowledge base

### Data Flow for AI Features
```
iOS App
  → serialise current kit inventory to JSON
  → POST to FastAPI endpoint with { query, inventory, mode }
  → FastAPI runs RAG retrieval over first aid knowledge base
  → constructs prompt with retrieved context + inventory
  → calls Groq API (qwen3-32b)
  → returns structured response
  → App renders result (chat bubble or protocol steps depending on mode)
```
No shared database between app and backend. Inventory is sent per-request.

---

## What Is Explicitly Out of Scope (MVP)
- CloudKit or iCloud sync
- Android / cross-platform
- Web interface
- User accounts / auth
- Sharing kits between users

---

## Build Order
1. ~~SwiftData models + CRUD UI (kits, items, quantities, expiry)~~ ✓
2. ~~Multi-kit management (store inventory layer)~~ ✓
3. FastAPI skeleton (health check, basic endpoint, Groq integration)
4. First aid knowledge base + RAG pipeline (Python, owner leads)
5. "Ask" mode — conversational chat UI in app
6. "Emergency" mode — guided protocol UI in app
7. QM suggester — gap analysis and restock (likely within Ask mode)

---

## Developer Context
- Owner has limited Swift/SwiftUI experience, not previously used Claude Code
- Owner has strong Python and AI/LLM integration experience
- This is a semi-casual vibe-coding project — output quality matters more than code education
- Claude Code should be directive and make sensible defaults rather than asking excessive questions

---

## Project Management
- Architecture and design decisions are discussed in Claude.ai chat (separate from Claude Code)
- This file is the source of truth for Claude Code — update it after significant design decisions
- Open questions and deferred decisions are tracked in the section below

---

## Open Questions / Deferred Decisions
- [ ] Which vector store for RAG (Chroma for local dev is likely default — Pinecone/pgvector for prod)
- [ ] FastAPI hosting (local dev only initially — Railway / Fly.io for prod TBD)
- [ ] LLM provider reassessment before prod — likely Anthropic API
- [ ] Emergency mode: fully offline (bundled protocols) vs cached-on-first-use vs network-required
- [x] App name: **QM**
- [ ] Bundle ID (currently placeholder `Atmoshpere.QM` — update when ready to distribute)
- [x] Stream 2 shares the same data model as Stream 1 ✓