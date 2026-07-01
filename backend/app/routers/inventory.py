"""REST CRUD endpoints for kits, items, bundles and shopping list.

Used by the iOS app (and future sync layer). All writes return the updated
resource with its new updated_at so the iOS client can track sync state.
"""

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.auth import require_auth as verify_token
from app.database import get_db
from app.models.db import Bundle, BundleItem, Kit, KitItem, ShoppingItem
from app.services import inventory as svc

router = APIRouter(prefix="/inventory", tags=["inventory"], dependencies=[Depends(verify_token)])


# ── Shared response helpers ───────────────────────────────────────────────────

def _kit_out(kit: Kit) -> dict:
    return {
        "id": str(kit.id),
        "name": kit.name,
        "is_store": kit.is_store,
        "kit_category": kit.kit_category,
        "kit_icon": kit.kit_icon,
        "kit_icon_color": kit.kit_icon_color,
        "created_at": kit.created_at.isoformat(),
        "updated_at": kit.updated_at.isoformat(),
    }


def _item_out(item: KitItem) -> dict:
    return {
        "id": str(item.id),
        "kit_id": str(item.kit_id),
        "name": item.name,
        "category": item.category,
        "quantity": item.quantity,
        "expiry_date": item.expiry_date.isoformat() if item.expiry_date else None,
        "notes": item.notes,
        "track_stock": item.track_stock,
        "size": item.size,
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat(),
    }


def _bundle_out(bundle: Bundle, include_kits: bool = False) -> dict:
    out = {
        "id": str(bundle.id),
        "name": bundle.name,
        "notes": bundle.notes,
        "kit_icon": bundle.kit_icon,
        "kit_icon_color": bundle.kit_icon_color,
        "created_at": bundle.created_at.isoformat(),
        "updated_at": bundle.updated_at.isoformat(),
    }
    if include_kits:
        out["kits"] = [_kit_out(k) for k in bundle.kits]
        out["items"] = [_bundle_item_out(i) for i in bundle.items]
    return out


def _bundle_item_out(item: BundleItem) -> dict:
    return {
        "id": str(item.id),
        "bundle_id": str(item.bundle_id),
        "name": item.name,
        "category": item.category,
        "quantity": item.quantity,
        "expiry_date": item.expiry_date.isoformat() if item.expiry_date else None,
        "notes": item.notes,
        "track_stock": item.track_stock,
        "size": item.size,
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat(),
    }


def _shopping_out(item: ShoppingItem) -> dict:
    return {
        "id": str(item.id),
        "name": item.name,
        "notes": item.notes,
        "status": item.status,
        "source": item.source,
        "kit_id": str(item.kit_id) if item.kit_id else None,
        "bundle_id": str(item.bundle_id) if item.bundle_id else None,
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat(),
    }


# ── Kits ──────────────────────────────────────────────────────────────────────

class KitCreate(BaseModel):
    name: str
    is_store: bool = False
    kit_category: str = ""
    kit_icon: str = "cross.case.fill"
    kit_icon_color: str = "teal"

class KitUpdate(BaseModel):
    name: str | None = None
    kit_category: str | None = None
    kit_icon: str | None = None
    kit_icon_color: str | None = None


@router.get("/kits")
def list_kits(db: Session = Depends(get_db)):
    return [_kit_out(k) for k in svc.list_kits(db)]


@router.post("/kits", status_code=201)
def create_kit(body: KitCreate, db: Session = Depends(get_db)):
    kit = svc.create_kit(db, **body.model_dump())
    return _kit_out(kit)


@router.get("/kits/{kit_id}")
def get_kit(kit_id: uuid.UUID, db: Session = Depends(get_db)):
    kit = svc.get_kit(db, kit_id)
    if kit is None:
        raise HTTPException(404, "Kit not found")
    return _kit_out(kit)


@router.patch("/kits/{kit_id}")
def update_kit(kit_id: uuid.UUID, body: KitUpdate, db: Session = Depends(get_db)):
    kit = svc.get_kit(db, kit_id)
    if kit is None:
        raise HTTPException(404, "Kit not found")
    for key, value in body.model_dump(exclude_none=True).items():
        setattr(kit, key, value)
    db.commit()
    db.refresh(kit)
    return _kit_out(kit)


@router.delete("/kits/{kit_id}", status_code=204)
def delete_kit(kit_id: uuid.UUID, db: Session = Depends(get_db)):
    kit = svc.get_kit(db, kit_id)
    if kit is None:
        raise HTTPException(404, "Kit not found")
    if kit.is_store:
        raise HTTPException(400, "Cannot delete the Store")
    db.delete(kit)
    db.commit()


# ── Kit items ─────────────────────────────────────────────────────────────────

class ItemCreate(BaseModel):
    name: str
    category: str
    quantity: int = 1
    expiry_date: date | None = None
    notes: str = ""
    track_stock: bool = True
    size: str | None = None

class ItemUpdate(BaseModel):
    name: str | None = None
    category: str | None = None
    quantity: int | None = None
    expiry_date: date | None = None
    notes: str | None = None
    track_stock: bool | None = None
    size: str | None = None
    kit_id: uuid.UUID | None = None  # allows move between kits


@router.get("/kits/{kit_id}/items")
def list_items(kit_id: uuid.UUID, category: str | None = None, db: Session = Depends(get_db)):
    if svc.get_kit(db, kit_id) is None:
        raise HTTPException(404, "Kit not found")
    return [_item_out(i) for i in svc.list_items(db, kit_id=kit_id, category=category)]


@router.post("/kits/{kit_id}/items", status_code=201)
def create_item(kit_id: uuid.UUID, body: ItemCreate, db: Session = Depends(get_db)):
    if svc.get_kit(db, kit_id) is None:
        raise HTTPException(404, "Kit not found")
    item = svc.create_item(db, kit_id=kit_id, **body.model_dump())
    return _item_out(item)


@router.get("/items/{item_id}")
def get_item(item_id: uuid.UUID, db: Session = Depends(get_db)):
    item = svc.get_item(db, item_id)
    if item is None:
        raise HTTPException(404, "Item not found")
    return _item_out(item)


@router.patch("/items/{item_id}")
def update_item(item_id: uuid.UUID, body: ItemUpdate, db: Session = Depends(get_db)):
    item = svc.update_item(db, item_id, **body.model_dump(exclude_none=True))
    if item is None:
        raise HTTPException(404, "Item not found")
    return _item_out(item)


@router.delete("/items/{item_id}", status_code=204)
def delete_item(item_id: uuid.UUID, db: Session = Depends(get_db)):
    item = svc.get_item(db, item_id)
    if item is None:
        raise HTTPException(404, "Item not found")
    db.delete(item)
    db.commit()


# ── Bundles ───────────────────────────────────────────────────────────────────

class BundleCreate(BaseModel):
    name: str
    notes: str = ""
    kit_icon: str = "shippingbox.fill"
    kit_icon_color: str = "teal"

class BundleUpdate(BaseModel):
    name: str | None = None
    notes: str | None = None
    kit_icon: str | None = None
    kit_icon_color: str | None = None

class BundleKitBody(BaseModel):
    kit_id: uuid.UUID

class BundleItemCreate(BaseModel):
    name: str
    category: str
    quantity: int = 1
    expiry_date: date | None = None
    notes: str = ""
    track_stock: bool = True
    size: str | None = None


@router.get("/bundles")
def list_bundles(db: Session = Depends(get_db)):
    return [_bundle_out(b) for b in svc.list_bundles(db)]


@router.post("/bundles", status_code=201)
def create_bundle(body: BundleCreate, db: Session = Depends(get_db)):
    bundle = svc.create_bundle(db, **body.model_dump())
    return _bundle_out(bundle)


@router.get("/bundles/{bundle_id}")
def get_bundle(bundle_id: uuid.UUID, db: Session = Depends(get_db)):
    bundle = svc.get_bundle(db, bundle_id)
    if bundle is None:
        raise HTTPException(404, "Bundle not found")
    return _bundle_out(bundle, include_kits=True)


@router.patch("/bundles/{bundle_id}")
def update_bundle(bundle_id: uuid.UUID, body: BundleUpdate, db: Session = Depends(get_db)):
    bundle = svc.get_bundle(db, bundle_id)
    if bundle is None:
        raise HTTPException(404, "Bundle not found")
    for key, value in body.model_dump(exclude_none=True).items():
        setattr(bundle, key, value)
    db.commit()
    db.refresh(bundle)
    return _bundle_out(bundle)


@router.delete("/bundles/{bundle_id}", status_code=204)
def delete_bundle(bundle_id: uuid.UUID, db: Session = Depends(get_db)):
    bundle = svc.get_bundle(db, bundle_id)
    if bundle is None:
        raise HTTPException(404, "Bundle not found")
    db.delete(bundle)
    db.commit()


@router.post("/bundles/{bundle_id}/kits")
def add_kit_to_bundle(bundle_id: uuid.UUID, body: BundleKitBody, db: Session = Depends(get_db)):
    bundle = svc.add_kit_to_bundle(db, bundle_id, body.kit_id)
    if bundle is None:
        raise HTTPException(404, "Bundle or kit not found")
    return _bundle_out(bundle, include_kits=True)


@router.delete("/bundles/{bundle_id}/kits/{kit_id}", status_code=204)
def remove_kit_from_bundle(bundle_id: uuid.UUID, kit_id: uuid.UUID, db: Session = Depends(get_db)):
    bundle = svc.get_bundle(db, bundle_id)
    kit = svc.get_kit(db, kit_id)
    if bundle is None or kit is None:
        raise HTTPException(404, "Bundle or kit not found")
    if kit in bundle.kits:
        bundle.kits.remove(kit)
        db.commit()


@router.post("/bundles/{bundle_id}/items", status_code=201)
def create_bundle_item(bundle_id: uuid.UUID, body: BundleItemCreate, db: Session = Depends(get_db)):
    if svc.get_bundle(db, bundle_id) is None:
        raise HTTPException(404, "Bundle not found")
    item = svc.create_bundle_item(db, bundle_id=bundle_id, **body.model_dump())
    return _bundle_item_out(item)


# ── Shopping list ─────────────────────────────────────────────────────────────

class ShoppingCreate(BaseModel):
    name: str
    notes: str = ""
    status: str = "needed"
    source: str = "user"
    kit_id: uuid.UUID | None = None
    bundle_id: uuid.UUID | None = None

class ShoppingUpdate(BaseModel):
    name: str | None = None
    notes: str | None = None
    status: str | None = None


@router.get("/shopping")
def list_shopping(include_acquired: bool = False, db: Session = Depends(get_db)):
    return [_shopping_out(i) for i in svc.list_shopping_items(db, include_acquired=include_acquired)]


@router.post("/shopping", status_code=201)
def create_shopping_item(body: ShoppingCreate, db: Session = Depends(get_db)):
    item = svc.create_shopping_item(db, **body.model_dump())
    return _shopping_out(item)


@router.patch("/shopping/{item_id}")
def update_shopping_item(item_id: uuid.UUID, body: ShoppingUpdate, db: Session = Depends(get_db)):
    item = svc.update_shopping_item(db, item_id, **body.model_dump(exclude_none=True))
    if item is None:
        raise HTTPException(404, "Shopping item not found")
    return _shopping_out(item)


@router.delete("/shopping/{item_id}", status_code=204)
def delete_shopping_item(item_id: uuid.UUID, db: Session = Depends(get_db)):
    item = svc.update_shopping_item(db, item_id)
    if item is None:
        raise HTTPException(404, "Shopping item not found")
    db.delete(db.get(ShoppingItem, item_id))
    db.commit()


# ── Sync endpoint ─────────────────────────────────────────────────────────────

@router.get("/sync")
def sync_snapshot(db: Session = Depends(get_db)):
    """Full snapshot for iOS initial sync / re-sync after offline period.

    Returns all kits with their items, all bundles (with kit membership and
    loose items), and the active shopping list — everything the app needs to
    rebuild local SwiftData cache in one round-trip.
    """
    kits = svc.list_kits(db)
    kit_list = []
    for kit in kits:
        k = _kit_out(kit)
        k["items"] = [_item_out(i) for i in kit.items]
        kit_list.append(k)

    bundles = svc.list_bundles(db)
    bundle_list = [_bundle_out(b, include_kits=True) for b in bundles]

    shopping = svc.list_shopping_items(db)

    return {
        "kits": kit_list,
        "bundles": bundle_list,
        "shopping": [_shopping_out(s) for s in shopping],
    }
