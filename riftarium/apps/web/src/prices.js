import { reactive } from "vue"
import { api } from "./api.js"

/* Prix indicatifs des cartes : formatage €, note légale partagée et méta
   (/api/prices/meta) mise en cache au niveau du module — un seul appel
   par session, partagé entre toutes les vues qui affichent un prix. */

const EUR_FORMAT = new Intl.NumberFormat("fr-FR", { style: "currency", currency: "EUR" })

/* Note légale affichée (texte gris ou tooltip) partout où un prix apparaît en bloc. */
export const PRICE_NOTE =
  "Prix indicatifs : marché américain (TCGplayer), convertis en euros (taux BCE). Ni cote officielle ni offre d'achat."

/* Phrase de repli quand la méta n'est pas (encore) chargée sur la fiche carte. */
export const PRICE_SOURCE_NOTE = "Prix du marché américain (TCGplayer), convertis en euros (taux BCE)."

/** « 13,30 € », ou null si la valeur n'est pas un prix exploitable. */
export function formatEur(value) {
  if (value === null || value === undefined || value === "") return null
  const amount = Number(value)
  if (Number.isNaN(amount)) return null
  return EUR_FORMAT.format(amount)
}

/** Complétion d'un set ou de la collection : « set complet » ou « 3 cartes manquantes (~4,20 €) ». */
export function missingCardsText(row) {
  if (!row.missing) return "set complet"
  const cost = formatEur(row.missing_cost_eur)
  const count = row.missing === 1 ? "1 carte manquante" : `${row.missing} cartes manquantes`
  return `${count}${cost ? ` (~${cost})` : ""}`
}

const PRINT_SUFFIX = /\s*\((?:alternate art|overnumbered|signature)\)\s*$/i

/** Recherche Cardmarket (lien sortant non affilié : Cardmarket n'est pas la source des prix).
    Accepte un nom ou une carte. Cardmarket range alt-arts, overnumbered et signatures sous
    « showcase » : on cherche donc le nom sans suffixe suivi de « showcase ». */
export function cardmarketUrl(cardOrName) {
  const card = typeof cardOrName === "object" && cardOrName ? cardOrName : { name: cardOrName }
  const name = String(card.name || "")
  const showcase = card.alternate_art || card.overnumbered || card.signature || PRINT_SUFFIX.test(name)
  const search = showcase ? `${name.replace(PRINT_SUFFIX, "")} showcase` : name
  return `https://www.cardmarket.com/fr/Riftbound/Products/Search?searchString=${encodeURIComponent(search)}`
}

const META_DEFAULTS = {
  loaded: false,
  updated_day: null,
  rate: null,
  rate_date: null,
  priced_cards: 0,
  source: "",
  currency_note: ""
}

const meta = reactive({ ...META_DEFAULTS })
let pending = null
/* Échec mémorisé : sans lui, chaque composant affichant un prix relançait
   /api/prices/meta (une page de cartes = des dizaines d'appels perdus, et autant
   de coups dans la limite de débit quand l'API est justement en difficulté).
   La méta n'est qu'un complément d'affichage : un seul essai par session suffit. */
let failed = false

async function fetchMeta() {
  try {
    const data = await api("/api/prices/meta")
    if (data && typeof data === "object") Object.assign(meta, data, { loaded: true })
  } catch {
    /* méta indisponible : les blocs de prix retombent sur PRICE_SOURCE_NOTE */
    failed = true
  } finally {
    pending = null
  }
}

/** Méta réactive des prix ; déclenche le chargement au premier usage puis sert le cache. */
export function usePricesMeta() {
  if (!meta.loaded && !pending && !failed) pending = fetchMeta()
  return meta
}

/** Repart d'un cache module vierge (nouvel essai après échec, tests). */
export function resetPricesMeta() {
  pending = null
  failed = false
  Object.assign(meta, META_DEFAULTS)
}
