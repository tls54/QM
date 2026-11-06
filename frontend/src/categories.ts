import type { CSSProperties } from "react";

export const ITEM_CATEGORIES = [
  "Wound Care",
  "Sanitisation",
  "Medications",
  "Airway & Breathing",
  "Immobilisation",
  "Footcare",
  "Tools & Equipment",
  "Navigation",
  "Shelter",
  "Cooking & Water",
  "Lighting",
  "Communication",
  "Other",
] as const;

// Deterministic vivid hue per category — used for item chips so the list
// reads as color-coded without hand-maintaining a lookup table per name.
const HUES = [352, 18, 38, 160, 176, 200, 226, 262, 292, 320, 140, 8, 60];

export function categoryHue(category: string | null | undefined): number {
  if (!category) return 0;
  const i = ITEM_CATEGORIES.indexOf(category as (typeof ITEM_CATEGORIES)[number]);
  if (i >= 0) return HUES[i];
  let hash = 0;
  for (let c = 0; c < category.length; c++) hash = (hash * 31 + category.charCodeAt(c)) >>> 0;
  return hash % 360;
}

export function categoryStyle(category: string | null | undefined): CSSProperties {
  return { "--chip-hue": categoryHue(category) } as CSSProperties;
}
