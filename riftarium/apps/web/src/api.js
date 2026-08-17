import { reactive } from "vue";

const TOKEN_KEY = "riftarium_token";
const HANDLE_KEY = "riftarium_handle";

export const session = reactive({
  token: localStorage.getItem(TOKEN_KEY),
  handle: localStorage.getItem(HANDLE_KEY)
});

export function setSession(token, handle) {
  session.token = token;
  session.handle = handle;
  if (token) {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(HANDLE_KEY, handle);
  } else {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(HANDLE_KEY);
  }
}

export async function api(path, { method = "GET", body } = {}) {
  const headers = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (session.token) headers["Authorization"] = `Bearer ${session.token}`;

  const response = await fetch(path, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined
  });

  if (response.status === 401) {
    setSession(null, null);
    throw new ApiError(401, "Connexion requise");
  }
  if (response.status === 204) return null;

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new ApiError(response.status, data.detail || "Erreur inattendue");
  }
  return data;
}

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export const DOMAINS = {
  Fury: { label: "Fureur", color: "var(--fury)" },
  Calm: { label: "Calme", color: "var(--calm)" },
  Mind: { label: "Esprit", color: "var(--mind)" },
  Body: { label: "Corps", color: "var(--body)" },
  Chaos: { label: "Chaos", color: "var(--chaos)" },
  Order: { label: "Ordre", color: "var(--order)" },
  Colorless: { label: "Neutre", color: "var(--muted)" }
};

export const TYPES = {
  Unit: "Unité",
  Spell: "Sort",
  Gear: "Équipement",
  Rune: "Rune",
  Legend: "Légende",
  Battlefield: "Champ de bataille"
};

export const RARITIES = {
  Common: "Commun",
  Uncommon: "Peu commun",
  Rare: "Rare",
  Epic: "Épique",
  Showcase: "Vitrine",
  Promo: "Promo"
};
