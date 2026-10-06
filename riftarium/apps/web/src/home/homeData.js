import { api } from "../api.js"
import { BANNERS } from "../banners.js"

/* Données de l'accueil : fonctions pures autour des endpoints existants, testables
   sans composant. Aucun endpoint dédié à l'accueil. */

/* Illustrations assez cinématiques pour ouvrir le site (paysages larges, personnages). */
export const SPLASH_KEYS = ["home", "cards", "decks", "community"]

export function pickSplash(random = Math.random) {
  const index = Math.min(SPLASH_KEYS.length - 1, Math.floor(random() * SPLASH_KEYS.length))
  return BANNERS[SPLASH_KEYS[index]]
}

/* Set le plus récent par date de publication ; sans aucune date, le dernier de la liste
   (l'API les renvoie déjà dans l'ordre de publication). */
export function latestSet(sets) {
  if (!sets?.length) return null
  const dated = sets.filter((set) => set.published_on)
  if (!dated.length) return sets[sets.length - 1]
  return dated.reduce((best, set) => (set.published_on >= best.published_on ? set : best))
}

/* Cartes du mur : jamais de carte couchée (champs de bataille), elle casserait la grille. */
export function wallCards(items, limit = 36) {
  return (items ?? []).filter((card) => card.image_url && card.orientation !== "landscape").slice(0, limit)
}

export function completion(overall) {
  if (!overall?.total) return null
  return { owned: overall.owned, total: overall.total, percent: Math.round((overall.owned / overall.total) * 100) }
}

const OUTCOMES = { win: "Victoire", loss: "Défaite", disputed: "Contesté" }

export function outcomeLabel(outcome) {
  return OUTCOMES[outcome] ?? "Partie"
}

/* Résumé d'un membre connecté. allSettled : un endpoint en panne n'efface pas les deux autres. */
export async function loadMemberSummary({ signal } = {}) {
  const [sets, decks, history] = await Promise.allSettled([
    api("/api/collection/sets", { signal }),
    api("/api/decks/mine", { signal }),
    api("/api/play/history?size=1", { signal })
  ])
  const value = (result) => (result.status === "fulfilled" ? result.value : null)
  return {
    collection: completion(value(sets)?.overall),
    deck: value(decks)?.[0] ?? null,
    match: value(history)?.items?.[0] ?? null
  }
}
