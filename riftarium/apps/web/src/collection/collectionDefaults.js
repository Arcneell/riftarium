import { CONDITIONS, LANGS } from "../api.js"

/* Préférences d'ajout à la collection (état et langue d'un nouvel exemplaire),
   gardées dans ce navigateur. Un stockage bloqué n'empêche rien : on retombe
   sur les valeurs par défaut. */
const KEY = "riftarium_collection_defaults"
const FALLBACK = { condition: "NM", lang: "FR" }

export function readDefaults() {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY))
    return {
      condition: raw && Object.hasOwn(CONDITIONS, raw.condition) ? raw.condition : FALLBACK.condition,
      lang: raw && Object.hasOwn(LANGS, raw.lang) ? raw.lang : FALLBACK.lang
    }
  } catch {
    return { ...FALLBACK }
  }
}

export function writeDefaults({ condition, lang }) {
  try {
    localStorage.setItem(KEY, JSON.stringify({ condition, lang }))
  } catch {
    /* stockage bloqué : la préférence ne survit simplement pas au rechargement */
  }
}
