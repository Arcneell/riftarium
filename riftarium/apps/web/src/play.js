import { api } from "./api.js"

/* Suivi des matchs : appels de l'API `/api/play` et mise en forme partagée par
   les pages Historique, Statistiques et Salon.
   Contrat : docs/suivi-des-matchs.md — source de vérité API / mobile / web. */

/* Le code d'un salon vaut secret et arrive par l'URL : encodé avant d'entrer dans le chemin. */
const roomPath = (code, suffix = "") => `/api/play/rooms/${encodeURIComponent(code)}${suffix}`
const matchPath = (id, suffix = "") => `/api/play/matches/${encodeURIComponent(id)}${suffix}`

/* ---------- Salons ---------- */

/** Crée un salon (`duel` ou `match`) et renvoie le RoomOut, code compris. */
export function createRoom(mode) {
  return api("/api/play/rooms", { method: "POST", body: { mode } })
}

export function getRoom(code) {
  return api(roomPath(code))
}

export function joinRoom(code) {
  return api(roomPath(code, "/join"), { method: "POST" })
}

/** Choix perso du joueur : `{legend_card_id?, deck_id?, ready}`. */
export function updateMe(code, payload) {
  return api(roomPath(code, "/me"), { method: "PUT", body: payload })
}

export function leaveRoom(code) {
  return api(roomPath(code, "/leave"), { method: "POST" })
}

export function cancelRoom(code) {
  return api(roomPath(code), { method: "DELETE" })
}

/** Lancement réservé à l'hôte (le compteur vit sur son téléphone). */
export function startRoom(code, firstPlayerId) {
  return api(roomPath(code, "/start"), { method: "POST", body: { first_player_id: firstPlayerId } })
}

/* ---------- Matchs ---------- */

export function getMatch(id) {
  return api(matchPath(id))
}

export function confirmMatch(id) {
  return api(matchPath(id, "/confirm"), { method: "POST" })
}

export function disputeMatch(id) {
  return api(matchPath(id, "/dispute"), { method: "POST" })
}

export function abandonMatch(id) {
  return api(matchPath(id, "/abandon"), { method: "POST" })
}

/* ---------- Historique, statistiques, reprise ---------- */

export function getHistory(page = 1, size = 20) {
  return api(`/api/play/history?page=${page}&size=${size}`)
}

export function getStats() {
  return api("/api/play/stats")
}

/** Mon salon actif et/ou mon match en cours — `{room: null, match: null}` si rien. */
export function getCurrent() {
  return api("/api/play/current")
}

/* ---------- Mise en forme ---------- */

/* v1 : deux formats à deux joueurs. `match` = 2 manches gagnantes, `duel` = 1. */
const MODES = { duel: "Duel", match: "Match" }

export function modeLabel(mode) {
  return MODES[mode] || "—"
}

const OUTCOMES = { win: "Victoire", loss: "Défaite", disputed: "Contesté" }

export function outcomeLabel(outcome) {
  return OUTCOMES[outcome] || "Terminé"
}

/* Couleur de la pastille d'issue : le calme pour une victoire, la fureur pour une
   défaite, rien du tout pour un match contesté (il ne compte pas dans les stats). */
export function outcomeTone(outcome) {
  if (outcome === "win") return "calm"
  if (outcome === "loss") return "fury"
  return "neutral"
}

const ROOM_STATUS = {
  open: "En attente d'un adversaire",
  playing: "Partie en cours",
  finished: "Partie terminée",
  cancelled: "Salon annulé"
}

export function roomStatusLabel(status) {
  return ROOM_STATUS[status] || "Statut inconnu"
}

const MATCH_STATUS = {
  live: "En cours",
  awaiting_confirmation: "En attente de confirmation",
  confirmed: "Résultat confirmé",
  disputed: "Résultat contesté",
  abandoned: "Abandon"
}

export function matchStatusLabel(status) {
  return MATCH_STATUS[status] || "Statut inconnu"
}

const PERCENT = new Intl.NumberFormat("fr-FR", { style: "percent", maximumFractionDigits: 0 })

/* `win_rate` : le contrat ne fixe pas l'unité. On accepte les deux écritures —
   un ratio (0,62) comme un pourcentage déjà multiplié (62) — pour ne dépendre
   d'aucune interprétation du côté API. */
function ratio(rate) {
  if (rate === null || rate === undefined || rate === "") return null
  const value = Number(rate)
  if (Number.isNaN(value)) return null
  return value > 1 ? value / 100 : value
}

/** « 62 % », ou « — » si le taux n'est pas exploitable. */
export function formatWinRate(rate) {
  const value = ratio(rate)
  return value === null ? "—" : PERCENT.format(value)
}

/** Largeur de barre en pourcentage (0 → 100), bornée. Sert aux jauges des tableaux. */
export function winRatePercent(rate) {
  const value = ratio(rate)
  return value === null ? 0 : Math.round(Math.min(1, Math.max(0, value)) * 100)
}

const DATE_FORMAT = new Intl.DateTimeFormat("fr-FR", {
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit"
})

/** « 12 août 2026, 21:30 » — chaîne vide si la date manque ou est illisible. */
export function formatPlayedAt(iso) {
  if (!iso) return ""
  const date = new Date(iso)
  return Number.isNaN(date.getTime()) ? "" : DATE_FORMAT.format(date)
}
