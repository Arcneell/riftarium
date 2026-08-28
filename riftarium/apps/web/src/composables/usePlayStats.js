import { reactive } from "vue"
import { getStats } from "../play.js"

/* Bilan de matchs (`GET /api/play/stats`) mis en cache au niveau du module : les
   boîtes de deck en affichent le W/L, un seul appel suffit pour toute la session.
   L'échec est silencieux — sans bilan, les decks s'affichent simplement sans badge. */

const EMPTY = { loaded: false, byDeck: {} }
const state = reactive({ ...EMPTY })
let pending = null

async function fetchStats() {
  try {
    const data = await getStats()
    const byDeck = {}
    for (const row of data?.by_deck || []) {
      if (row?.deck_id !== null && row?.deck_id !== undefined) byDeck[row.deck_id] = row
    }
    state.byDeck = byDeck
  } catch {
    /* suivi des matchs indisponible : pas de badge, rien de cassé */
  } finally {
    state.loaded = true
    pending = null
  }
}

/** État réactif partagé ; déclenche le chargement au premier usage puis sert le cache. */
export function usePlayStats() {
  if (!state.loaded && !pending) pending = fetchStats()
  return state
}

/** Tests uniquement : repart d'un cache module vierge. */
export function resetPlayStats() {
  pending = null
  Object.assign(state, { loaded: false, byDeck: {} })
}
