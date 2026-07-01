"""CRUD layer over Kit/KitItem/Bundle/ShoppingItem — the data layer the MCP tools call into."""

import uuid

from sqlalchemy.orm import Session

from app.models.db import Bundle, BundleItem, Kit, KitItem, ShoppingItem


# ── Kits ──────────────────────────────────────────────────────────────────────


def list_kits(db: Session) -> list[Kit]:
    return db.query(Kit).order_by(Kit.is_store.desc(), Kit.name).all()


def get_kit(db: Session, kit_id: uuid.UUID) -> Kit | None:
    return db.get(Kit, kit_id)


def create_kit(
    db: Session,
    name: str,
    is_store: bool = False,
    kit_category: str = "",
    kit_icon: str = "cross.case.fill",
    kit_icon_color: str = "teal",
) -> Kit:
    kit = Kit(
        name=name,
        is_store=is_store,
        kit_category=kit_category,
        kit_icon=kit_icon,
        kit_icon_color=kit_icon_color,
    )
    db.add(kit)
    db.commit()
    db.refresh(kit)
    return kit


# ── Kit items ─────────────────────────────────────────────────────────────────


def list_items(
    db: Session, kit_id: uuid.UUID | None = None, category: str | None = None
) -> list[KitItem]:
    query = db.query(KitItem)
    if kit_id is not None:
        query = query.filter(KitItem.kit_id == kit_id)
    if category is not None:
        query = query.filter(KitItem.category == category)
    return query.order_by(KitItem.name).all()


def get_item(db: Session, item_id: uuid.UUID) -> KitItem | None:
    return db.get(KitItem, item_id)


def create_item(
    db: Session,
    kit_id: uuid.UUID,
    name: str,
    category: str,
    quantity: int = 1,
    expiry_date=None,
    notes: str = "",
    track_stock: bool = True,
    size: str | None = None,
) -> KitItem:
    item = KitItem(
        kit_id=kit_id,
        name=name,
        category=category,
        quantity=quantity,
        expiry_date=expiry_date,
        notes=notes,
        track_stock=track_stock,
        size=size,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def update_item(db: Session, item_id: uuid.UUID, **fields) -> KitItem | None:
    item = db.get(KitItem, item_id)
    if item is None:
        return None
    for key, value in fields.items():
        setattr(item, key, value)
    db.commit()
    db.refresh(item)
    return item


# ── Bundles ───────────────────────────────────────────────────────────────────


def list_bundles(db: Session) -> list[Bundle]:
    return db.query(Bundle).order_by(Bundle.name).all()


def get_bundle(db: Session, bundle_id: uuid.UUID) -> Bundle | None:
    return db.get(Bundle, bundle_id)


def create_bundle(
    db: Session,
    name: str,
    notes: str = "",
    kit_icon: str = "shippingbox.fill",
    kit_icon_color: str = "teal",
) -> Bundle:
    bundle = Bundle(name=name, notes=notes, kit_icon=kit_icon, kit_icon_color=kit_icon_color)
    db.add(bundle)
    db.commit()
    db.refresh(bundle)
    return bundle


def add_kit_to_bundle(db: Session, bundle_id: uuid.UUID, kit_id: uuid.UUID) -> Bundle | None:
    bundle = db.get(Bundle, bundle_id)
    kit = db.get(Kit, kit_id)
    if bundle is None or kit is None:
        return None
    if kit not in bundle.kits:
        bundle.kits.append(kit)
        db.commit()
        db.refresh(bundle)
    return bundle


def create_bundle_item(
    db: Session,
    bundle_id: uuid.UUID,
    name: str,
    category: str,
    quantity: int = 1,
    expiry_date=None,
    notes: str = "",
    track_stock: bool = True,
    size: str | None = None,
) -> BundleItem:
    item = BundleItem(
        bundle_id=bundle_id,
        name=name,
        category=category,
        quantity=quantity,
        expiry_date=expiry_date,
        notes=notes,
        track_stock=track_stock,
        size=size,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


# ── Shopping list ─────────────────────────────────────────────────────────────


def list_shopping_items(db: Session, include_acquired: bool = False) -> list[ShoppingItem]:
    query = db.query(ShoppingItem)
    if not include_acquired:
        query = query.filter(ShoppingItem.status != "acquired")
    return query.order_by(ShoppingItem.created_at.desc()).all()


def create_shopping_item(
    db: Session,
    name: str,
    notes: str = "",
    status: str = "needed",
    source: str = "user",
    kit_id: uuid.UUID | None = None,
    bundle_id: uuid.UUID | None = None,
) -> ShoppingItem:
    item = ShoppingItem(
        name=name,
        notes=notes,
        status=status,
        source=source,
        kit_id=kit_id,
        bundle_id=bundle_id,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def update_shopping_item(db: Session, item_id: uuid.UUID, **fields) -> ShoppingItem | None:
    item = db.get(ShoppingItem, item_id)
    if item is None:
        return None
    for key, value in fields.items():
        setattr(item, key, value)
    db.commit()
    db.refresh(item)
    return item
