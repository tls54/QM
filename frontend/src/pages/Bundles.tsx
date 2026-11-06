import { useEffect, useState } from "react";
import {
  addKitToBundle,
  createBundle,
  createBundleItem,
  getBundle,
  listBundles,
  listKits,
  type Bundle,
  type BundleItem,
  type Kit,
} from "../api";
import { KitIcon } from "../icons";
import { ChevronDown } from "lucide-react";
import { categoryStyle, ITEM_CATEGORIES } from "../categories";

function AddKitToBundle({
  bundleId,
  existingKitIds,
  onAdded,
}: {
  bundleId: string;
  existingKitIds: string[];
  onAdded: (bundle: Bundle) => void;
}) {
  const [open, setOpen] = useState(false);
  const [kits, setKits] = useState<Kit[] | null>(null);
  const [selected, setSelected] = useState("");

  useEffect(() => {
    if (open && kits === null) {
      listKits().then(setKits);
    }
  }, [open, kits]);

  const options = (kits ?? []).filter((k) => !existingKitIds.includes(k.id));

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!selected) return;
    const updated = await addKitToBundle(bundleId, selected);
    onAdded(updated);
    setSelected("");
    setOpen(false);
  }

  if (!open) {
    return (
      <button className="add-link" onClick={() => setOpen(true)}>
        + Add kit
      </button>
    );
  }

  return (
    <form className="add-item-form" onSubmit={submit}>
      <select value={selected} onChange={(e) => setSelected(e.target.value)}>
        <option value="">Select a kit…</option>
        {options.map((k) => (
          <option key={k.id} value={k.id}>
            {k.name}
          </option>
        ))}
      </select>
      <button type="submit">Add</button>
    </form>
  );
}

function AddBundleItemForm({
  bundleId,
  onAdd,
}: {
  bundleId: string;
  onAdd: (item: BundleItem) => void;
}) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [category, setCategory] = useState<string>(ITEM_CATEGORIES[0]);
  const [quantity, setQuantity] = useState(1);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    const created = await createBundleItem(bundleId, {
      name: name.trim(),
      category,
      quantity,
    });
    onAdd(created);
    setName("");
    setQuantity(1);
    setOpen(false);
  }

  if (!open) {
    return (
      <button className="add-link" onClick={() => setOpen(true)}>
        + Add loose item
      </button>
    );
  }

  return (
    <form className="add-item-form" onSubmit={submit}>
      <input
        placeholder="Item name…"
        value={name}
        onChange={(e) => setName(e.target.value)}
        autoFocus
      />
      <select value={category} onChange={(e) => setCategory(e.target.value)}>
        {ITEM_CATEGORIES.map((c) => (
          <option key={c} value={c}>
            {c}
          </option>
        ))}
      </select>
      <input
        type="number"
        min={0}
        className="qty-input"
        value={quantity}
        onChange={(e) => setQuantity(Number(e.target.value))}
      />
      <button type="submit">Add</button>
    </form>
  );
}

function BundleSection({ summary }: { summary: Bundle }) {
  const [bundle, setBundle] = useState<Bundle | null>(null);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (open && bundle === null) {
      getBundle(summary.id).then(setBundle);
    }
  }, [open, bundle, summary.id]);

  return (
    <section className="card">
      <button className="card-header" onClick={() => setOpen((o) => !o)}>
        <span className="kit-title">
          <span className="kit-badge">
            <KitIcon icon={summary.kit_icon} color={summary.kit_icon_color} fallback="📦" />
          </span>
          <span className="kit-name">{summary.name}</span>
        </span>
        <span className={`chevron ${open ? "chevron-open" : ""}`}>
          <ChevronDown size={16} />
        </span>
      </button>
      {open && (
        <div className="bundle-body">
          {bundle === null && <p className="muted">Loading…</p>}
          {bundle && (
            <>
              {bundle.kits && bundle.kits.length > 0 && (
                <>
                  <h4>Kits</h4>
                  <ul className="item-list">
                    {bundle.kits.map((k) => (
                      <li key={k.id} className="item-row">
                        <div className="item-main">
                          <span className="item-name">{k.name}</span>
                        </div>
                      </li>
                    ))}
                  </ul>
                </>
              )}
              {bundle.items && bundle.items.length > 0 && (
                <>
                  <h4>Loose items</h4>
                  <ul className="item-list">
                    {bundle.items.map((i) => (
                      <li key={i.id} className="item-row">
                        <div className="item-main">
                          <span className="item-name">{i.name ?? "(from kit)"}</span>
                          {i.category && (
                            <span className="item-category" style={categoryStyle(i.category)}>
                              {i.category}
                            </span>
                          )}
                        </div>
                        <div className="item-actions">
                          <span className="qty">{i.quantity}</span>
                        </div>
                      </li>
                    ))}
                  </ul>
                </>
              )}
              {(!bundle.kits || bundle.kits.length === 0) &&
                (!bundle.items || bundle.items.length === 0) && (
                  <p className="muted">Empty bundle</p>
                )}
              <div className="bundle-add-actions">
                <AddKitToBundle
                  bundleId={bundle.id}
                  existingKitIds={(bundle.kits ?? []).map((k) => k.id)}
                  onAdded={setBundle}
                />
                <AddBundleItemForm
                  bundleId={bundle.id}
                  onAdd={(item) =>
                    setBundle((prev) =>
                      prev ? { ...prev, items: [...(prev.items ?? []), item] } : prev,
                    )
                  }
                />
              </div>
            </>
          )}
        </div>
      )}
    </section>
  );
}

function NewBundleForm({ onCreate }: { onCreate: (bundle: Bundle) => void }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [notes, setNotes] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    const created = await createBundle({ name: name.trim(), notes: notes.trim() });
    onCreate(created);
    setName("");
    setNotes("");
    setOpen(false);
  }

  if (!open) {
    return (
      <button className="new-btn" onClick={() => setOpen(true)}>
        + New bundle
      </button>
    );
  }

  return (
    <form className="new-form card" onSubmit={submit}>
      <input
        placeholder="Bundle name…"
        value={name}
        onChange={(e) => setName(e.target.value)}
        autoFocus
      />
      <input
        placeholder="Notes (optional)…"
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
      />
      <div className="new-form-actions">
        <button
          type="button"
          className="ghost"
          onClick={() => {
            setName("");
            setNotes("");
            setOpen(false);
          }}
        >
          Cancel
        </button>
        <button type="submit">Create bundle</button>
      </div>
    </form>
  );
}

export default function Bundles() {
  const [bundles, setBundles] = useState<Bundle[] | null>(null);

  useEffect(() => {
    listBundles().then(setBundles);
  }, []);

  function addBundle(bundle: Bundle) {
    setBundles((prev) => [...(prev ?? []), bundle]);
  }

  if (bundles === null) return <p className="muted">Loading…</p>;

  return (
    <div className="page">
      {bundles.length === 0 && <p className="muted">No bundles yet</p>}
      {bundles.map((b) => (
        <BundleSection key={b.id} summary={b} />
      ))}
      <NewBundleForm onCreate={addBundle} />
    </div>
  );
}
