import { reactive } from "vue"
import { api, session } from "./api.js"

/* Échanges entre joueurs : appels de l'API `/api/trades` et libellés partagés par
   la page Échanges, la fiche carte et le profil.
   Contrat : docs/echanges.md — source de vérité API / mobile / web. */

/* La Réunion seulement pour l'instant : l'ordre est celui de l'affichage. */
export const TRADE_ZONES = [
  { value: "nord", label: "Nord" },
  { value: "sud", label: "Sud" },
  { value: "est", label: "Est" },
  { value: "ouest", label: "Ouest" }
]

export function zoneLabel(zone) {
  return TRADE_ZONES.find((item) => item.value === zone)?.label ?? ""
}

const STATUS_LABELS = {
  pending: "En attente",
  accepted: "Acceptée",
  declined: "Refusée",
  cancelled: "Annulée",
  done: "Échange fait"
}

export function statusLabel(status) {
  return STATUS_LABELS[status] ?? status
}

export const CONTACT_MAX = 80
export const MESSAGE_MAX = 280

/* ---------- Réglages et offres ---------- */

/** Réglages d'échange (`trade_enabled`, `trade_zone`, `trade_contact`, `notify_trades`). Renvoie le `user_out`. */
export function updateTradeSettings(patch) {
  return api("/api/auth/me", { method: "PATCH", body: patch })
}

/** Mes offres : `[{id, entry_id, card, condition, lang, qty, entry_qty}]`. */
export function getOffers() {
  return api("/api/trades/offers")
}

/** Quantité proposée sur un de mes lots ; 0 retire l'offre (204). */
export function setOffer(entryId, qty) {
  return api(`/api/trades/offers/${entryId}`, { method: "PUT", body: { qty } })
}

/* ---------- Correspondances ---------- */

function matchParams({ zone = "", q = "", page = 1, size = 24 } = {}) {
  const params = new URLSearchParams({ page: String(page), size: String(size) })
  if (zone) params.set("zone", zone)
  if (q) params.set("q", q)
  return params
}

/** « Ils ont ce que je cherche » : `{items: [{card, wanted_qty, offers}], total, page, size}`. */
export function getWanted(options) {
  return api(`/api/trades/matches/wanted?${matchParams(options)}`)
}

/** « Ils cherchent ce que j'ai » : `{items: [{user, cards}], total, page, size}`. */
export function getOffered({ zone = "", page = 1, size = 24 } = {}) {
  return api(`/api/trades/matches/offered?${matchParams({ zone, page, size })}`)
}

/** Offres des autres sur une carte : `{offers, total, in_my_zone}`. */
export function getCardOffers(cardId) {
  return api(`/api/trades/cards/${encodeURIComponent(cardId)}/offers`)
}

/* ---------- Demandes ---------- */

export function sendRequest(offerId, message = "") {
  return api("/api/trades/requests", { method: "POST", body: { offer_id: offerId, message: message.trim() } })
}

/** Demandes reçues (`in`) ou envoyées (`out`), les plus récentes d'abord. */
export function getRequests(box, { status = "", page = 1, size = 50 } = {}) {
  const params = new URLSearchParams({ box, page: String(page), size: String(size) })
  if (status) params.set("status", status)
  return api(`/api/trades/requests?${params}`)
}

export function getRequestsSummary() {
  return api("/api/trades/requests/summary")
}

/** `action` : accept, decline, cancel ou done. Renvoie la demande à jour. */
export function actOnRequest(id, action) {
  return api(`/api/trades/requests/${id}/${action}`, { method: "POST" })
}

/* ---------- Pastille de navigation ---------- */

/* Demandes reçues en attente : partagé par le rail et la page Échanges.
   Rafraîchi à la navigation ; vidé à la fermeture de session. */
export const tradeBadge = reactive({ incoming: 0 })

export async function refreshTradeBadge() {
  if (!session.token) return
  try {
    tradeBadge.incoming = (await getRequestsSummary()).incoming_pending || 0
  } catch {
    /* La pastille est un confort : un échec ne doit rien casser. */
  }
}

if (typeof window !== "undefined") {
  window.addEventListener("riftarium:session-closed", () => {
    tradeBadge.incoming = 0
  })
}
