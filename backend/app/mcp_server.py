"""FastMCP server mounted at /mcp on the FastAPI app.

Auth is enforced via an ASGI wrapper applied when mounting — see main.py.
DB sessions are opened per tool call and closed immediately after.
"""

import os
from datetime import date

from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings

from app.database import SessionLocal
from app.services import inventory as svc

# Allow the Railway public hostname (and localhost for local dev).
_extra = [h.strip() for h in os.getenv("MCP_ALLOWED_HOSTS", "").split(",") if h.strip()]
_allowed_hosts = ["localhost", "localhost:*", "127.0.0.1", "127.0.0.1:*", *_extra]

mcp = FastMCP(
    "QM Kit Manager",
    stateless_http=True,  # no in-memory sessions — survives redeployment without reconnecting
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=_allowed_hosts,
    ),
)


def _db():
    """Open a short-lived DB session for a single tool call."""
    return SessionLocal()


# ── Connectivity ──────────────────────────────────────────────────────────────

@mcp.tool()
def ping() -> str:
    """Confirm the QM MCP server is reachable and auth is working."""
    return "QM Kit Manager is online and your token is valid."


# ── Kits ──────────────────────────────────────────────────────────────────────

@mcp.tool()
def list_kits() -> list[dict]:
    """List all kits. The Store kit (is_store=true) is always first."""
    db = _db()
    try:
        return [
            {
                "id": str(k.id),
                "name": k.name,
                "is_store": k.is_store,
                "kit_category": k.kit_category,
                "item_count": len(k.items),
            }
            for k in svc.list_kits(db)
        ]
    finally:
        db.close()


@mcp.tool()
def get_kit_contents(kit_id: str) -> dict:
    """Get a kit and all its items. kit_id is a UUID string."""
    db = _db()
    try:
        kit = svc.get_kit(db, kit_id)
        if kit is None:
            return {"error": f"Kit {kit_id} not found"}
        return {
            "id": str(kit.id),
            "name": kit.name,
            "is_store": kit.is_store,
            "kit_category": kit.kit_category,
            "items": [
                {
                    "id": str(i.id),
                    "name": i.name,
                    "category": i.category,
                    "quantity": i.quantity,
                    "expiry_date": i.expiry_date.isoformat() if i.expiry_date else None,
                    "notes": i.notes,
                    "size": i.size,
                    "track_stock": i.track_stock,
                }
                for i in sorted(kit.items, key=lambda x: x.name)
            ],
        }
    finally:
        db.close()


@mcp.tool()
def create_kit(name: str, kit_category: str = "") -> dict:
    """Create a new kit. Returns the created kit with its id."""
    db = _db()
    try:
        kit = svc.create_kit(db, name=name, kit_category=kit_category)
        return {"id": str(kit.id), "name": kit.name, "kit_category": kit.kit_category}
    finally:
        db.close()


# ── Items ─────────────────────────────────────────────────────────────────────

@mcp.tool()
def list_items(kit_id: str | None = None, category: str | None = None) -> list[dict]:
    """List items, optionally filtered by kit_id (UUID string) and/or category.

    Valid categories: Wound Care, Sanitisation, Medications, Airway & Breathing,
    Immobilisation, Footcare, Tools & Equipment, Navigation, Shelter,
    Cooking & Water, Lighting, Communication, Other.
    """
    db = _db()
    try:
        import uuid as _uuid
        kit_uuid = _uuid.UUID(kit_id) if kit_id else None
        return [
            {
                "id": str(i.id),
                "kit_id": str(i.kit_id),
                "name": i.name,
                "category": i.category,
                "quantity": i.quantity,
                "expiry_date": i.expiry_date.isoformat() if i.expiry_date else None,
                "notes": i.notes,
                "size": i.size,
                "track_stock": i.track_stock,
            }
            for i in svc.list_items(db, kit_id=kit_uuid, category=category)
        ]
    finally:
        db.close()


@mcp.tool()
def add_item(
    kit_id: str,
    name: str,
    category: str,
    quantity: int = 1,
    expiry_date: str | None = None,
    notes: str = "",
    size: str | None = None,
) -> dict:
    """Add an item to a kit.

    kit_id: UUID string of the target kit.
    category: must be one of the valid ItemCategory values.
    expiry_date: ISO date string (YYYY-MM-DD) or omit if no expiry.
    Returns the created item with its id.
    """
    db = _db()
    try:
        import uuid as _uuid
        parsed_expiry = date.fromisoformat(expiry_date) if expiry_date else None
        item = svc.create_item(
            db,
            kit_id=_uuid.UUID(kit_id),
            name=name,
            category=category,
            quantity=quantity,
            expiry_date=parsed_expiry,
            notes=notes,
            size=size,
        )
        return {
            "id": str(item.id),
            "kit_id": str(item.kit_id),
            "name": item.name,
            "category": item.category,
            "quantity": item.quantity,
            "expiry_date": item.expiry_date.isoformat() if item.expiry_date else None,
        }
    finally:
        db.close()


@mcp.tool()
def update_item(
    item_id: str,
    quantity: int | None = None,
    notes: str | None = None,
    expiry_date: str | None = None,
    name: str | None = None,
    category: str | None = None,
    size: str | None = None,
) -> dict:
    """Update one or more fields on an existing item. Only provided fields are changed.

    item_id: UUID string.
    expiry_date: ISO date string (YYYY-MM-DD) or null to clear.
    """
    db = _db()
    try:
        import uuid as _uuid
        fields = {}
        if quantity is not None:
            fields["quantity"] = quantity
        if notes is not None:
            fields["notes"] = notes
        if name is not None:
            fields["name"] = name
        if category is not None:
            fields["category"] = category
        if size is not None:
            fields["size"] = size
        if expiry_date is not None:
            fields["expiry_date"] = date.fromisoformat(expiry_date)

        item = svc.update_item(db, _uuid.UUID(item_id), **fields)
        if item is None:
            return {"error": f"Item {item_id} not found"}
        return {
            "id": str(item.id),
            "name": item.name,
            "quantity": item.quantity,
            "notes": item.notes,
            "expiry_date": item.expiry_date.isoformat() if item.expiry_date else None,
        }
    finally:
        db.close()


@mcp.tool()
def delete_item(item_id: str) -> dict:
    """Permanently delete an item from a kit. item_id is a UUID string."""
    db = _db()
    try:
        from app.models.db import KitItem
        import uuid as _uuid
        item = db.get(KitItem, _uuid.UUID(item_id))
        if item is None:
            return {"error": f"Item {item_id} not found"}
        db.delete(item)
        db.commit()
        return {"deleted": item_id}
    finally:
        db.close()


# ── Bundles ───────────────────────────────────────────────────────────────────

@mcp.tool()
def list_bundles() -> list[dict]:
    """List all bundles with their kit count and loose item count."""
    db = _db()
    try:
        return [
            {
                "id": str(b.id),
                "name": b.name,
                "notes": b.notes,
                "kit_count": len(b.kits),
                "loose_item_count": len(b.items),
            }
            for b in svc.list_bundles(db)
        ]
    finally:
        db.close()


@mcp.tool()
def get_bundle_contents(bundle_id: str) -> dict:
    """Get a bundle with its kits (and their items) and any loose items."""
    db = _db()
    try:
        bundle = svc.get_bundle(db, bundle_id)
        if bundle is None:
            return {"error": f"Bundle {bundle_id} not found"}
        return {
            "id": str(bundle.id),
            "name": bundle.name,
            "notes": bundle.notes,
            "kits": [
                {
                    "id": str(k.id),
                    "name": k.name,
                    "item_count": len(k.items),
                    "items": [
                        {
                            "id": str(i.id),
                            "name": i.name,
                            "category": i.category,
                            "quantity": i.quantity,
                            "expiry_date": i.expiry_date.isoformat() if i.expiry_date else None,
                        }
                        for i in sorted(k.items, key=lambda x: x.name)
                    ],
                }
                for k in bundle.kits
            ],
            "loose_items": [
                {
                    "id": str(i.id),
                    "name": i.name,
                    "category": i.category,
                    "quantity": i.quantity,
                }
                for i in bundle.items
            ],
        }
    finally:
        db.close()


# ── Shopping list ─────────────────────────────────────────────────────────────

@mcp.tool()
def list_shopping_items(include_acquired: bool = False) -> list[dict]:
    """List shopping list items. By default excludes acquired items."""
    db = _db()
    try:
        return [
            {
                "id": str(i.id),
                "name": i.name,
                "notes": i.notes,
                "status": i.status,
                "source": i.source,
            }
            for i in svc.list_shopping_items(db, include_acquired=include_acquired)
        ]
    finally:
        db.close()


@mcp.tool()
def add_shopping_item(
    name: str,
    notes: str = "",
    kit_id: str | None = None,
) -> dict:
    """Add an item to the shopping list (source=llm).

    Use this to suggest items that should be restocked or purchased.
    kit_id: optional UUID string of the kit this item is for.
    """
    db = _db()
    try:
        import uuid as _uuid
        item = svc.create_shopping_item(
            db,
            name=name,
            notes=notes,
            source="llm",
            kit_id=_uuid.UUID(kit_id) if kit_id else None,
        )
        return {"id": str(item.id), "name": item.name, "status": item.status}
    finally:
        db.close()


@mcp.tool()
def update_shopping_item(item_id: str, status: str) -> dict:
    """Update the status of a shopping list item.

    item_id: UUID string.
    status: one of 'needed', 'ordered', 'acquired'.
    """
    db = _db()
    try:
        import uuid as _uuid
        if status not in ("needed", "ordered", "acquired"):
            return {"error": "status must be one of: needed, ordered, acquired"}
        item = svc.update_shopping_item(db, _uuid.UUID(item_id), status=status)
        if item is None:
            return {"error": f"Shopping item {item_id} not found"}
        return {"id": str(item.id), "name": item.name, "status": item.status}
    finally:
        db.close()


# ── Gap analysis ──────────────────────────────────────────────────────────────

@mcp.tool()
def get_inventory_summary() -> dict:
    """Return a full inventory snapshot for gap analysis and restock planning.

    Includes all kits with item counts, expiry status, and stock levels.
    Use this as context before suggesting shopping list additions.
    """
    db = _db()
    try:
        from datetime import date as _date
        today = _date.today()
        kits = svc.list_kits(db)
        result = []
        for kit in kits:
            items_out = []
            for i in sorted(kit.items, key=lambda x: x.name):
                expiry_flag = None
                if i.expiry_date:
                    if i.expiry_date < today:
                        expiry_flag = "expired"
                    elif (i.expiry_date - today).days <= 30:
                        expiry_flag = "expiring_soon"
                items_out.append({
                    "name": i.name,
                    "category": i.category,
                    "quantity": i.quantity,
                    "expiry_flag": expiry_flag,
                    "out_of_stock": i.track_stock and i.quantity == 0,
                })
            result.append({
                "id": str(kit.id),
                "name": kit.name,
                "is_store": kit.is_store,
                "kit_category": kit.kit_category,
                "items": items_out,
                "expired_count": sum(1 for x in items_out if x["expiry_flag"] == "expired"),
                "expiring_soon_count": sum(1 for x in items_out if x["expiry_flag"] == "expiring_soon"),
                "out_of_stock_count": sum(1 for x in items_out if x["out_of_stock"]),
            })
        shopping = svc.list_shopping_items(db)
        return {
            "kits": result,
            "shopping_list": [{"name": s.name, "status": s.status} for s in shopping],
        }
    finally:
        db.close()
