import { useEffect, useState } from "react";
import { Trash2 } from "lucide-react";
import {
  createShoppingItem,
  deleteShoppingItem,
  listShopping,
  updateShoppingItem,
  type ShoppingItem,
} from "../api";

export default function Shopping() {
  const [items, setItems] = useState<ShoppingItem[] | null>(null);
  const [newName, setNewName] = useState("");

  useEffect(() => {
    listShopping().then(setItems);
  }, []);

  async function addItem(e: React.FormEvent) {
    e.preventDefault();
    if (!newName.trim()) return;
    const created = await createShoppingItem({ name: newName.trim() });
    setItems((prev) => [created, ...(prev ?? [])]);
    setNewName("");
  }

  async function setStatus(item: ShoppingItem, status: ShoppingItem["status"]) {
    const updated = await updateShoppingItem(item.id, { status });
    setItems((prev) => prev!.map((i) => (i.id === item.id ? updated : i)));
  }

  async function remove(item: ShoppingItem) {
    await deleteShoppingItem(item.id);
    setItems((prev) => prev!.filter((i) => i.id !== item.id));
  }

  if (items === null) return <p className="muted">Loading…</p>;

  return (
    <div className="page">
      <form className="add-row" onSubmit={addItem}>
        <input
          placeholder="Add item…"
          value={newName}
          onChange={(e) => setNewName(e.target.value)}
        />
        <button type="submit">Add</button>
      </form>
      <ul className="item-list">
        {items.length === 0 && <li className="muted">Nothing on the list</li>}
        {items.map((item) => (
          <li key={item.id} className={`item-row shopping-${item.status}`}>
            <div className="item-main">
              <span className="item-name">{item.name}</span>
              {item.source === "llm" && <span className="tag">AI</span>}
            </div>
            <div className="item-actions">
              <select
                value={item.status}
                onChange={(e) => setStatus(item, e.target.value as ShoppingItem["status"])}
              >
                <option value="needed">Needed</option>
                <option value="ordered">Ordered</option>
                <option value="acquired">Acquired</option>
              </select>
              <button className="danger" onClick={() => remove(item)} aria-label="Delete item">
                <Trash2 size={14} />
              </button>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
