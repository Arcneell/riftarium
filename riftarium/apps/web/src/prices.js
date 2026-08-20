import { reactive } from "vue"
import { api } from "./api.js"

/* Prix indicatifs des cartes : formatage €, note légale partagée et méta
   (/api/prices/meta) mise en cache au niveau du module — un seul appel
   par session, partagé entre toutes les vues qui affichent un prix. */

const EUR_FORMAT = new Intl.NumberFormat("fr-FR", { style: "currency", currency: "EUR" })

/* Note légale affichée (texte gris ou tooltip) partout où un prix apparaît en bloc. */
export const PRICE_NOTE =
  "Prix indicatifs : marché US (TCGplayer), convertis en € (taux BCE). Ni cote officielle ni offre d'achat."

/* Phrase de repli quand la méta n'est pas (encore) chargée sur la fiche carte. */
export const PRICE_SOURCE_NOTE = "Prix du marché US (TCGplayer), convertis en € (taux BCE)."

/** « 13,30 € », ou null si la valeur n'est pas un prix exploitable. */
export function formatEur(value) {
  if (value === null || value === undefined || value === "") return null
  const amount = Number(value)
  if (Number.isNaN(amount)) return null
  return EUR_FORMAT.format(amount)
}

/** Recherche Cardmarket (lien sortant non affilié — Cardmarket n'est pas la source des prix). */
export function cardmarketUrl(name) {
  return `https://www.cardmarket.com/fr/Riftbound/Products/Search?searchString=${encodeURIComponent(name || "")}`
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

async function fetchMeta() {
  try {
    const data = await api("/api/prices/meta")
    if (data && typeof data === "object") Object.assign(meta, data, { loaded: true })
  } catch {
    /* méta indisponible : les blocs de prix retombent sur PRICE_SOURCE_NOTE */
  } finally {
    pending = null
  }
}

/** Méta réactive des prix ; déclenche le chargement au premier usage puis sert le cache. */
export function usePricesMeta() {
  if (!meta.loaded && !pending) pending = fetchMeta()
  return meta
}

/** Tests uniquement : repart d'un cache module vierge. */
export function resetPricesMeta() {
  pending = null
  Object.assign(meta, META_DEFAULTS)
}
