import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, Table, Column
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)


bundle_kits = Table(
    "bundle_kits",
    Base.metadata,
    Column("bundle_id", UUID(as_uuid=True), ForeignKey("bundles.id", ondelete="CASCADE"), primary_key=True),
    Column("kit_id", UUID(as_uuid=True), ForeignKey("kits.id", ondelete="CASCADE"), primary_key=True),
)


class Kit(Base):
    __tablename__ = "kits"

    id: Mapped[uuid.UUID] = _uuid_pk()
    name: Mapped[str] = mapped_column(String, nullable=False)
    is_store: Mapped[bool] = mapped_column(Boolean, default=False)
    kit_category: Mapped[str] = mapped_column(String, default="")
    kit_icon: Mapped[str] = mapped_column(String, default="cross.case.fill")
    kit_icon_color: Mapped[str] = mapped_column(String, default="teal")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    items: Mapped[list["KitItem"]] = relationship(
        back_populates="kit", cascade="all, delete-orphan"
    )
    bundles: Mapped[list["Bundle"]] = relationship(
        secondary=bundle_kits, back_populates="kits"
    )


class KitItem(Base):
    __tablename__ = "kit_items"

    id: Mapped[uuid.UUID] = _uuid_pk()
    kit_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("kits.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String, nullable=False)
    category: Mapped[str] = mapped_column(String, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    expiry_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    notes: Mapped[str] = mapped_column(String, default="")
    track_stock: Mapped[bool] = mapped_column(Boolean, default=True)
    size: Mapped[str | None] = mapped_column(String, nullable=True)

    kit: Mapped["Kit"] = relationship(back_populates="items")


class Bundle(Base):
    __tablename__ = "bundles"

    id: Mapped[uuid.UUID] = _uuid_pk()
    name: Mapped[str] = mapped_column(String, nullable=False)
    notes: Mapped[str] = mapped_column(String, default="")
    kit_icon: Mapped[str] = mapped_column(String, default="shippingbox.fill")
    kit_icon_color: Mapped[str] = mapped_column(String, default="teal")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    kits: Mapped[list["Kit"]] = relationship(secondary=bundle_kits, back_populates="bundles")
    items: Mapped[list["BundleItem"]] = relationship(
        back_populates="bundle", cascade="all, delete-orphan"
    )


class BundleItem(Base):
    """Loose items in a bundle that don't belong to any kit."""

    __tablename__ = "bundle_items"

    id: Mapped[uuid.UUID] = _uuid_pk()
    bundle_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("bundles.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String, nullable=False)
    category: Mapped[str] = mapped_column(String, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    expiry_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    notes: Mapped[str] = mapped_column(String, default="")
    track_stock: Mapped[bool] = mapped_column(Boolean, default=True)
    size: Mapped[str | None] = mapped_column(String, nullable=True)

    bundle: Mapped["Bundle"] = relationship(back_populates="items")


class ShoppingItem(Base):
    __tablename__ = "shopping_items"

    id: Mapped[uuid.UUID] = _uuid_pk()
    name: Mapped[str] = mapped_column(String, nullable=False)
    notes: Mapped[str] = mapped_column(String, default="")
    status: Mapped[str] = mapped_column(String, default="needed")  # needed | ordered | acquired
    source: Mapped[str] = mapped_column(String, default="user")  # user | llm
    kit_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("kits.id", ondelete="SET NULL"), nullable=True
    )
    bundle_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("bundles.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
