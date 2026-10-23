import { useEffect, useState } from "react";
import { getBundle, listBundles, type Bundle } from "../api";
import { KitIcon } from "../icons";

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
        <span className="chevron">{open ? "▾" : "▸"}</span>
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
                          <span className="item-name">{i.name}</span>
                          <span className="item-category">{i.category}</span>
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
            </>
          )}
        </div>
      )}
    </section>
  );
}

export default function Bundles() {
  const [bundles, setBundles] = useState<Bundle[] | null>(null);

  useEffect(() => {
    listBundles().then(setBundles);
  }, []);

  if (bundles === null) return <p className="muted">Loading…</p>;
  if (bundles.length === 0) return <p className="muted">No bundles yet</p>;

  return (
    <div className="page">
      {bundles.map((b) => (
        <BundleSection key={b.id} summary={b} />
      ))}
    </div>
  );
}
