import { useEffect, useState } from "react";
import {
  deleteItem,
  listKitItems,
  listKits,
  updateItem,
  updateKit,
  type Kit,
  type KitItem,
} from "../api";
import { ColorRow, IconGrid, IconPreviewButton } from "../components/IconPicker";

function expiryStatus(expiry: string | null): "expired" | "soon" | "ok" | "none" {
  if (!expiry) return "none";
  const days = (new Date(expiry).getTime() - Date.now()) / 86_400_000;
  if (days < 0) return "expired";
  if (days < 30) return "soon";
  return "ok";
}

function KitSection({ kit, onKitChange }: { kit: Kit; onKitChange: (kit: Kit) => void }) {
  const [items, setItems] = useState<KitItem[] | null>(null);
  const [open, setOpen] = useState(kit.is_store);
  const [pickerOpen, setPickerOpen] = useState(false);

  useEffect(() => {
    if (open && items === null) {
      listKitItems(kit.id).then(setItems);
    }
  }, [open, items, kit.id]);

  async function bump(item: KitItem, delta: number) {
    let quantity = 0;
    setItems((prev) =>
      prev!.map((i) => {
        if (i.id !== item.id) return i;
        quantity = Math.max(0, i.quantity + delta);
        return { ...i, quantity };
      }),
    );
    const updated = await updateItem(item.id, { quantity });
    setItems((prev) => prev!.map((i) => (i.id === item.id ? updated : i)));
  }

  async function remove(item: KitItem) {
    if (!confirm(`Delete "${item.name}"?`)) return;
    await deleteItem(item.id);
    setItems((prev) => prev!.filter((i) => i.id !== item.id));
  }

  async function setIcon(kit_icon: string) {
    onKitChange(await updateKit(kit.id, { kit_icon }));
  }

  async function setColor(kit_icon_color: string) {
    onKitChange(await updateKit(kit.id, { kit_icon_color }));
  }

  return (
    <section className="card">
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
          {items && <span className="kit-count">{items.length}</span>}
          <span className="chevron">{open ? "▾" : "▸"}</span>
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
          {items === null && <li className="muted">Loading…</li>}
          {items?.length === 0 && <li className="muted">No items</li>}
          {items?.map((item) => (
            <li key={item.id} className={`item-row status-${expiryStatus(item.expiry_date)}`}>
              <div className="item-main">
                <span className="item-name">{item.name}</span>
                <span className="item-category">{item.category}</span>
                {item.expiry_date && (
                  <span className="item-expiry">exp {item.expiry_date}</span>
                )}
              </div>
              <div className="item-actions">
                <button onClick={() => bump(item, -1)}>−</button>
                <span className="qty">{item.quantity}</span>
                <button onClick={() => bump(item, 1)}>+</button>
                <button className="danger" onClick={() => remove(item)}>
                  ×
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function Kits() {
  const [kits, setKits] = useState<Kit[] | null>(null);

  useEffect(() => {
    listKits().then(setKits);
  }, []);

  function updateKitInList(updated: Kit) {
    setKits((prev) => prev!.map((k) => (k.id === updated.id ? updated : k)));
  }

  if (kits === null) return <p className="muted">Loading…</p>;

  return (
    <div className="page">
      {kits.map((kit) => (
        <KitSection key={kit.id} kit={kit} onKitChange={updateKitInList} />
      ))}
    </div>
  );
}
