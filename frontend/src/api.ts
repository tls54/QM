const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000";

const TOKEN_KEY = "qm_webapp_token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers ?? {}),
    },
  });
  if (!res.ok) {
    if (res.status === 401) {
      clearToken();
      window.dispatchEvent(new Event("qm-unauthorized"));
    }
    const body = await res.text();
    throw new ApiError(res.status, body || res.statusText);
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

export async function login(password: string): Promise<string> {
  const res = await request<{ token: string }>("/webapp/login", {
    method: "POST",
    body: JSON.stringify({ password }),
  });
  return res.token;
}

// ── Types ──────────────────────────────────────────────────────────────────

export type Kit = {
  id: string;
  name: string;
  is_store: boolean;
  kit_category: string;
  kit_icon: string;
  kit_icon_color: string;
};

export type KitItem = {
  id: string;
  kit_id: string;
  name: string;
  category: string;
  quantity: number;
  expiry_date: string | null;
  notes: string;
  track_stock: boolean;
  size: string | null;
};

export type Bundle = {
  id: string;
  name: string;
  notes: string;
  kit_icon: string;
  kit_icon_color: string;
  kits?: Kit[];
  items?: BundleItem[];
};

export type BundleItem = {
  id: string;
  bundle_id: string;
  // Link-only rows (cherry-picked from a kit via the MCP add_item_to_bundle
  // tool) carry no name/category of their own — display falls back to "—".
  name: string | null;
  category: string | null;
  quantity: number;
  expiry_date: string | null;
  notes: string;
};

export type ShoppingItem = {
  id: string;
  name: string;
  notes: string;
  status: "needed" | "ordered" | "acquired";
  source: "user" | "llm";
  kit_id: string | null;
  bundle_id: string | null;
};

// ── Kits ───────────────────────────────────────────────────────────────────

export const listKits = () => request<Kit[]>("/inventory/kits");
export const createKit = (body: {
  name: string;
  is_store?: boolean;
  kit_category?: string;
  kit_icon?: string;
  kit_icon_color?: string;
}) =>
  request<Kit>("/inventory/kits", {
    method: "POST",
    body: JSON.stringify(body),
  });
export const updateKit = (kitId: string, body: Partial<Kit>) =>
  request<Kit>(`/inventory/kits/${kitId}`, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
export const listKitItems = (kitId: string) =>
  request<KitItem[]>(`/inventory/kits/${kitId}/items`);
export const createItem = (
  kitId: string,
  body: {
    name: string;
    category: string;
    quantity?: number;
    expiry_date?: string | null;
    notes?: string;
    track_stock?: boolean;
    size?: string | null;
  },
) =>
  request<KitItem>(`/inventory/kits/${kitId}/items`, {
    method: "POST",
    body: JSON.stringify(body),
  });
export const updateItem = (itemId: string, body: Partial<KitItem>) =>
  request<KitItem>(`/inventory/items/${itemId}`, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
export const deleteItem = (itemId: string) =>
  request<void>(`/inventory/items/${itemId}`, { method: "DELETE" });

export const getSyncSnapshot = () =>
  request<{ kits: (Kit & { items: KitItem[] })[] }>("/inventory/sync");

// ── Bundles ────────────────────────────────────────────────────────────────

export const listBundles = () => request<Bundle[]>("/inventory/bundles");
export const createBundle = (body: {
  name: string;
  notes?: string;
  kit_icon?: string;
  kit_icon_color?: string;
}) =>
  request<Bundle>("/inventory/bundles", {
    method: "POST",
    body: JSON.stringify(body),
  });
export const getBundle = (bundleId: string) =>
  request<Bundle>(`/inventory/bundles/${bundleId}`);
export const addKitToBundle = (bundleId: string, kitId: string) =>
  request<Bundle>(`/inventory/bundles/${bundleId}/kits`, {
    method: "POST",
    body: JSON.stringify({ kit_id: kitId }),
  });
export const createBundleItem = (
  bundleId: string,
  body: {
    name: string;
    category: string;
    quantity?: number;
    expiry_date?: string | null;
    notes?: string;
    track_stock?: boolean;
    size?: string | null;
  },
) =>
  request<BundleItem>(`/inventory/bundles/${bundleId}/items`, {
    method: "POST",
    body: JSON.stringify(body),
  });

// ── Shopping list ──────────────────────────────────────────────────────────

export const listShopping = (includeAcquired = false) =>
  request<ShoppingItem[]>(`/inventory/shopping?include_acquired=${includeAcquired}`);
export const updateShoppingItem = (itemId: string, body: Partial<ShoppingItem>) =>
  request<ShoppingItem>(`/inventory/shopping/${itemId}`, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
export const deleteShoppingItem = (itemId: string) =>
  request<void>(`/inventory/shopping/${itemId}`, { method: "DELETE" });
export const createShoppingItem = (body: { name: string; notes?: string }) =>
  request<ShoppingItem>("/inventory/shopping", {
    method: "POST",
    body: JSON.stringify(body),
  });
