import { reactive } from "vue"

const SESSION_FLAG_KEY = "riftarium_session"
const HANDLE_KEY = "riftarium_handle"
const AVATAR_KEY = "riftarium_avatar"
const LEGACY_TOKEN_KEY = "riftarium_token"

try {
  localStorage.removeItem(LEGACY_TOKEN_KEY)
} catch {
  /* stockage indisponible (tests / mode privé) */
}

function readFlag() {
  try {
    return localStorage.getItem(SESSION_FLAG_KEY)
  } catch {
    return null
  }
}

export const session = reactive({
  token: readFlag(),
  handle: localStorage.getItem(HANDLE_KEY),
  avatarUrl: localStorage.getItem(AVATAR_KEY),
  /* Renseigné après /api/auth/me (email_verified). null = inconnu. Jamais persisté. */
  emailVerified: null
})

export function setSession(token, handle, avatarUrl = null) {
  const loggedIn = Boolean(token)
  session.token = loggedIn ? "1" : null
  session.handle = loggedIn ? handle : null
  session.avatarUrl = loggedIn ? avatarUrl || null : null
  if (!loggedIn) session.emailVerified = null
  try {
    if (loggedIn) {
      localStorage.setItem(SESSION_FLAG_KEY, "1")
      localStorage.setItem(HANDLE_KEY, handle)
      if (avatarUrl) localStorage.setItem(AVATAR_KEY, avatarUrl)
      else localStorage.removeItem(AVATAR_KEY)
    } else {
      localStorage.removeItem(SESSION_FLAG_KEY)
      localStorage.removeItem(HANDLE_KEY)
      localStorage.removeItem(AVATAR_KEY)
      localStorage.removeItem(LEGACY_TOKEN_KEY)
    }
  } catch {
    /* ignore */
  }
}

/* FastAPI renvoie parfois `detail` sous forme de liste (erreurs 422) : on en tire un message lisible. */
function readableDetail(detail) {
  if (typeof detail === "string" && detail) return detail
  if (Array.isArray(detail)) return detail[0]?.msg || "Requête invalide"
  if (detail) return "Requête invalide"
  return "Erreur inattendue"
}

export async function api(path, { method = "GET", body } = {}) {
  const headers = {}
  if (body !== undefined) headers["Content-Type"] = "application/json"

  const response = await fetch(path, {
    method,
    headers,
    credentials: "include",
    body: body !== undefined ? JSON.stringify(body) : undefined
  })

  if (response.status === 401) {
    setSession(null, null)
    /* Prévient l'application (App.vue redirige vers la connexion) sans coupler api.js au routeur. */
    if (typeof window !== "undefined") {
      window.dispatchEvent(new CustomEvent("riftarium:session-expired"))
    }
    throw new ApiError(401, "Connexion requise")
  }
  if (response.status === 204) return null

  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new ApiError(response.status, readableDetail(data.detail))
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

/* `color` sert aux pastilles et chips graphiques ; `text` est la variante assombrie,
   réservée au texte sur fond parchemin (contraste ≥ 4.5:1). */
export const DOMAINS = {
  Fury: { label: "Fureur", color: "var(--fury)", text: "var(--fury-text)" },
  Calm: { label: "Calme", color: "var(--calm)", text: "var(--calm-text)" },
  Mind: { label: "Esprit", color: "var(--mind)", text: "var(--mind-text)" },
  Body: { label: "Corps", color: "var(--body)", text: "var(--body-text)" },
  Chaos: { label: "Chaos", color: "var(--chaos)", text: "var(--chaos-text)" },
  Order: { label: "Ordre", color: "var(--order)", text: "var(--order-text)" },
  Colorless: { label: "Neutre", color: "var(--muted)", text: "var(--muted)" }
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
