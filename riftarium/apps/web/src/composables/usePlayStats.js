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
    /* Seulement en cas de succès : marquer « chargé » sur un échec (réseau coupé,
       401) figerait un cache vide pour toute la session, sans jamais retenter. */
    state.loaded = true
  } catch {
    /* suivi des matchs indisponible : pas de badge, rien de cassé */
  } finally {
    pending = null
  }
}

/** État réactif partagé ; déclenche le chargement au premier usage puis sert le cache. */
export function usePlayStats() {
  if (!state.loaded && !pending) pending = fetchStats()
  return state
}

/** Repart d'un cache module vierge (déconnexion, tests). */
export function resetPlayStats() {
  pending = null
  Object.assign(state, EMPTY)
}

/* Le bilan est une donnée de compte : elle ne doit pas survivre à la fermeture de
   session (déconnexion volontaire ou 401), sinon le compte suivant hériterait des
   W/L du précédent. api.js émet l'événement depuis setSession(null) — un écouteur
   plutôt qu'un import, pour ne pas créer de cycle api.js ⇄ usePlayStats.js. */
if (typeof window !== "undefined") {
  window.addEventListener("riftarium:session-closed", resetPlayStats)
}
