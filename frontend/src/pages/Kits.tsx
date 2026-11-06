import { useEffect, useState } from "react";
import { ChevronDown, Minus, Plus, ToggleLeft, ToggleRight, Trash2 } from "lucide-react";
import { KIT_COLORS } from "../icons";
import {
  createItem,
  createKit,
  deleteItem,
  getSyncSnapshot,
  updateItem,
  updateKit,
  type Kit,
  type KitItem,
} from "../api";
import { ColorRow, IconGrid, IconPreviewButton } from "../components/IconPicker";
import { categoryStyle, ITEM_CATEGORIES } from "../categories";

type KitWithItems = Kit & { items: KitItem[] };

function expiryStatus(expiry: string | null): "expired" | "soon" | "ok" | "none" {
  if (!expiry) return "none";
  const days = (new Date(expiry).getTime() - Date.now()) / 86_400_000;
  if (days < 0) return "expired";
  if (days < 30) return "soon";
  return "ok";
}

function AddItemForm({ kitId, onAdd }: { kitId: string; onAdd: (item: KitItem) => void }) {
  const [name, setName] = useState("");
  const [category, setCategory] = useState<string>(ITEM_CATEGORIES[0]);
  const [quantity, setQuantity] = useState(1);
  const [expiry, setExpiry] = useState("");
  const [trackStock, setTrackStock] = useState(true);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    const created = await createItem(kitId, {
      name: name.trim(),
      category,
      quantity,
      expiry_date: expiry || null,
      track_stock: trackStock,
    });
    onAdd(created);
    setName("");
    setQuantity(1);
    setExpiry("");
    setTrackStock(true);
  }

  return (
    <form className="add-item-form" onSubmit={submit}>
      <input
        placeholder="Item name…"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />
      <select value={category} onChange={(e) => setCategory(e.target.value)}>
        {ITEM_CATEGORIES.map((c) => (
          <option key={c} value={c}>
            {c}
          </option>
        ))}
      </select>
      {trackStock && (
        <input
          type="number"
          min={0}
          className="qty-input"
          value={quantity}
          onChange={(e) => setQuantity(Number(e.target.value))}
        />
      )}
      <input
        type="date"
        value={expiry}
        onChange={(e) => setExpiry(e.target.value)}
      />
      <label className="track-check">
        <input
          type="checkbox"
          checked={trackStock}
          onChange={(e) => setTrackStock(e.target.checked)}
        />
        Track stock
      </label>
      <button type="submit">Add item</button>
    </form>
  );
}

function KitSection({
  kit,
  onKitChange,
}: {
  kit: KitWithItems;
  onKitChange: (kit: KitWithItems) => void;
}) {
  const items = kit.items;
  const [open, setOpen] = useState(kit.is_store);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [addOpen, setAddOpen] = useState(false);

  function setItems(next: KitItem[]) {
    onKitChange({ ...kit, items: next });
  }

  async function bump(item: KitItem, delta: number) {
    const quantity = Math.max(0, item.quantity + delta);
    const optimistic = items.map((i) => (i.id === item.id ? { ...i, quantity } : i));
    setItems(optimistic);
    const updated = await updateItem(item.id, { quantity });
    setItems(optimistic.map((i) => (i.id === item.id ? updated : i)));
  }

  async function remove(item: KitItem) {
    if (!confirm(`Delete "${item.name}"?`)) return;
    await deleteItem(item.id);
    setItems(items.filter((i) => i.id !== item.id));
  }

  async function toggleTrack(item: KitItem) {
    const updated = await updateItem(item.id, { track_stock: !item.track_stock });
    setItems(items.map((i) => (i.id === item.id ? updated : i)));
  }

  async function setIcon(kit_icon: string) {
    const updated = await updateKit(kit.id, { kit_icon });
    onKitChange({ ...updated, items });
  }

  async function setColor(kit_icon_color: string) {
    const updated = await updateKit(kit.id, { kit_icon_color });
    onKitChange({ ...updated, items });
  }

  const accent = KIT_COLORS[kit.kit_icon_color] ?? KIT_COLORS.teal;

  return (
    <section className="card kit-card" style={{ "--kit-accent": accent } as React.CSSProperties}>
      <div className="card-header">
        <IconPreviewButton
          icon={kit.kit_icon}
          color={kit.kit_icon_color}
          onClick={() => setPickerOpen((p) => !p)}
        />
        <button className="kit-title-btn" onClick={() => setOpen((o) => !o)}>
          <span className="kit-name">{kit.name}</span>
        </button>
        <button className="kit-title kit-meta" onClick={() => setOpen((o) => !o)}>
          <span className="kit-count">{items.length}</span>
          <span className={`chevron ${open ? "chevron-open" : ""}`}>
            <ChevronDown size={16} />
          </span>
        </button>
      </div>

      {pickerOpen && (
        <div className="icon-picker-panel">
          <ColorRow value={kit.kit_icon_color} onChange={setColor} />
          <IconGrid value={kit.kit_icon} onChange={setIcon} />
        </div>
      )}

      {open && (
        <ul className="item-list">
          {items.length === 0 && <li className="muted">No items</li>}
          {items.map((item) => (
            <li key={item.id} className={`item-row status-${expiryStatus(item.expiry_date)}`}>
              <div className="item-main">
                <span className="item-name">{item.name}</span>
                <span className="item-category" style={categoryStyle(item.category)}>
                  {item.category}
                </span>
                {item.expiry_date && (
                  <span className="item-expiry">exp {item.expiry_date}</span>
                )}
              </div>
              <div className="item-actions">
                {item.track_stock ? (
                  <>
                    <button onClick={() => bump(item, -1)} aria-label="Decrease quantity">
                      <Minus size={14} />
                    </button>
                    <span className="qty">{item.quantity}</span>
                    <button onClick={() => bump(item, 1)} aria-label="Increase quantity">
                      <Plus size={14} />
                    </button>
                  </>
                ) : (
                  <span className="not-tracked">Not tracked</span>
                )}
                <button
                  className="track-toggle"
                  onClick={() => toggleTrack(item)}
                  aria-label={item.track_stock ? "Stop tracking stock" : "Track stock"}
                  title={item.track_stock ? "Stop tracking stock" : "Track stock"}
                >
                  {item.track_stock ? <ToggleRight size={14} /> : <ToggleLeft size={14} />}
                </button>
                <button className="danger" onClick={() => remove(item)} aria-label="Delete item">
                  <Trash2 size={14} />
                </button>
              </div>
            </li>
          ))}
          <li className="item-row add-item-row">
            {addOpen ? (
              <AddItemForm
                kitId={kit.id}
                onAdd={(item) => {
                  setItems([...items, item]);
                  setAddOpen(false);
                }}
              />
            ) : (
              <button className="add-link" onClick={() => setAddOpen(true)}>
                + Add item
              </button>
            )}
          </li>
        </ul>
      )}
    </section>
  );
}

function NewKitForm({ onCreate }: { onCreate: (kit: Kit) => void }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [category, setCategory] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    const created = await createKit({ name: name.trim(), kit_category: category.trim() });
    onCreate(created);
    setName("");
    setCategory("");
    setOpen(false);
  }

  if (!open) {
    return (
      <button className="new-btn" onClick={() => setOpen(true)}>
        + New kit
      </button>
    );
  }

  return (
    <form className="new-form card" onSubmit={submit}>
      <input
        placeholder="Kit name…"
        value={name}
        onChange={(e) => setName(e.target.value)}
        autoFocus
      />
      <input
        placeholder="Category (optional)…"
        value={category}
        onChange={(e) => setCategory(e.target.value)}
      />
      <div className="new-form-actions">
        <button
          type="button"
          className="ghost"
          onClick={() => {
            setName("");
            setCategory("");
            setOpen(false);
          }}
        >
          Cancel
        </button>
        <button type="submit">Create kit</button>
      </div>
    </form>
  );
}

function StatStrip({ kits }: { kits: KitWithItems[] }) {
  const allItems = kits.flatMap((k) => k.items);
  const lowStock = allItems.filter((i) => i.track_stock && i.quantity <= 1).length;
  const expiring = allItems.filter((i) => {
    const s = expiryStatus(i.expiry_date);
    return s === "expired" || s === "soon";
  }).length;

  return (
    <div className="stat-strip">
      <div className="stat-tile">
        <span className="stat-value">{kits.length}</span>
        <span className="stat-label">Kits</span>
      </div>
      <div className="stat-tile">
        <span className="stat-value">{allItems.length}</span>
        <span className="stat-label">Items</span>
      </div>
      <div className={`stat-tile ${lowStock > 0 ? "stat-warn" : ""}`}>
        <span className="stat-value">{lowStock}</span>
        <span className="stat-label">Low stock</span>
      </div>
      <div className={`stat-tile ${expiring > 0 ? "stat-danger" : ""}`}>
        <span className="stat-value">{expiring}</span>
        <span className="stat-label">Expiring</span>
      </div>
    </div>
  );
}

export default function Kits() {
  const [kits, setKits] = useState<KitWithItems[] | null>(null);

  useEffect(() => {
    getSyncSnapshot().then((snapshot) => setKits(snapshot.kits));
  }, []);

  function updateKitInList(updated: KitWithItems) {
    setKits((prev) => prev!.map((k) => (k.id === updated.id ? updated : k)));
  }

  function addKit(kit: Kit) {
    setKits((prev) => [...(prev ?? []), { ...kit, items: [] }]);
  }

  if (kits === null) return <p className="muted">Loading…</p>;

  return (
    <div className="page">
      <StatStrip kits={kits} />
      {kits.map((kit) => (
        <KitSection key={kit.id} kit={kit} onKitChange={updateKitInList} />
      ))}
      <NewKitForm onCreate={addKit} />
    </div>
  );
}
