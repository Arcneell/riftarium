import { reactive } from "vue"

const TOKEN_KEY = "riftarium_token"
const HANDLE_KEY = "riftarium_handle"
const AVATAR_KEY = "riftarium_avatar"

export const session = reactive({
  token: localStorage.getItem(TOKEN_KEY),
  handle: localStorage.getItem(HANDLE_KEY),
  avatarUrl: localStorage.getItem(AVATAR_KEY)
})

export function setSession(token, handle, avatarUrl = null) {
  session.token = token
  session.handle = handle
  session.avatarUrl = avatarUrl || null
  if (token) {
    localStorage.setItem(TOKEN_KEY, token)
    localStorage.setItem(HANDLE_KEY, handle)
    if (avatarUrl) localStorage.setItem(AVATAR_KEY, avatarUrl)
    else localStorage.removeItem(AVATAR_KEY)
  } else {
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(HANDLE_KEY)
    localStorage.removeItem(AVATAR_KEY)
  }
}

export async function api(path, { method = "GET", body } = {}) {
  const headers = {}
  if (body !== undefined) headers["Content-Type"] = "application/json"
  if (session.token) headers["Authorization"] = `Bearer ${session.token}`

  const response = await fetch(path, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined
  })

  if (response.status === 401) {
    setSession(null, null)
    throw new ApiError(401, "Connexion requise")
  }
  if (response.status === 204) return null

  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new ApiError(response.status, data.detail || "Erreur inattendue")
  }
  return data
}

/** Redimensionne une URL CDN Riot (`w=`) pour éviter de charger le visuel plein format. */
export function cardThumb(url, width = 280) {
  if (!url) return url
  if (/[?&]w=\d+/.test(url)) return url.replace(/w=\d+/, `w=${width}`)
  return `${url}${url.includes("?") ? "&" : "?"}auto=format&fit=max&w=${width}`
}

export class ApiError extends Error {
  constructor(status, message) {
    super(message)
    this.status = status
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
}

export const TYPES = {
  Unit: "Unité",
  Spell: "Sort",
  Gear: "Équipement",
  Rune: "Rune",
  Legend: "Légende",
  Battlefield: "Champ de bataille"
}

/* Échelle Cardmarket, du neuf au très abîmé. */
export const CONDITIONS = {
  MT: "Mint",
  NM: "Near Mint",
  EX: "Excellent",
  GD: "Good",
  LP: "Light Played",
  PL: "Played",
  PO: "Poor"
}

export const LANGS = {
  EN: "Anglais",
  FR: "Français",
  DE: "Allemand",
  ES: "Espagnol",
  IT: "Italien",
  JP: "Japonais",
  KO: "Coréen",
  ZH: "Chinois"
}

/* Ordre officiel Riot : Commune → Peu commune → Rare → Épique, puis impressions spéciales. */
export const RARITIES = {
  Common: "Commun",
  Uncommon: "Peu commun",
  Rare: "Rare",
  Epic: "Épique",
  Showcase: "Showcase",
  Promo: "Promo"
}
