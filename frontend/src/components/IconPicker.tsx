import { ICON_CATEGORIES, ICON_MAP, KIT_COLORS, KitIcon } from "../icons";

export function IconGrid({
  value,
  onChange,
}: {
  value: string;
  onChange: (icon: string) => void;
}) {
  return (
    <div className="icon-grid-wrap">
      {ICON_CATEGORIES.map((cat) => (
        <div key={cat.name} className="icon-category">
          <h5>{cat.name}</h5>
          <div className="icon-grid">
            {cat.icons.map((icon) => {
              const Comp = ICON_MAP[icon];
              if (!Comp) return null;
              return (
                <button
                  key={icon}
                  type="button"
                  className={`icon-swatch ${value === icon ? "selected" : ""}`}
                  onClick={() => onChange(icon)}
                  title={icon}
                >
                  <Comp size={18} strokeWidth={2.25} />
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

export function ColorRow({
  value,
  onChange,
}: {
  value: string;
  onChange: (color: string) => void;
}) {
  return (
    <div className="color-row">
      {Object.entries(KIT_COLORS).map(([name, hex]) => (
        <button
          key={name}
          type="button"
          className={`color-swatch ${value === name ? "selected" : ""}`}
          style={{ background: hex }}
          onClick={() => onChange(name)}
          title={name}
        />
      ))}
    </div>
  );
}

export function IconPreviewButton({
  icon,
  color,
  onClick,
}: {
  icon: string;
  color: string;
  onClick: () => void;
}) {
  return (
    <button type="button" className="kit-badge kit-badge-edit" onClick={onClick} title="Change icon">
      <KitIcon icon={icon} color={color} size={16} />
    </button>
  );
}
