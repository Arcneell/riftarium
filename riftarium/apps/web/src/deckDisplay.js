import { DOMAINS, cardThumb } from "./api.js"
import { DOMAIN_RUNE, RUNE_LABELS, glyphUrl } from "./cardText.js"

export const DECK_ZONES = [
  { key: "Legend", label: "Légende", target: 1 },
  { key: "Battlefield", label: "Champs de bataille", target: 3 },
  { key: "Rune", label: "Runes", target: 12 },
  { key: "main", label: "Deck principal", target: 40 }
]

const NAMED_ZONES = { Legend: true, Battlefield: true, Rune: true }

export function zoneOf(card) {
  return card?.type in NAMED_ZONES ? card.type : "main"
}

export function groupDeck(deck) {
  const groups = { Legend: [], Battlefield: [], Rune: [], main: [] }
  for (const entry of deck?.cards || []) groups[zoneOf(entry.card)].push(entry)
  for (const zone of Object.values(groups)) {
    zone.sort((a, b) => (a.card.energy ?? -1) - (b.card.energy ?? -1) || a.card.name.localeCompare(b.card.name, "fr"))
  }
  return groups
}

export function championOf(deck) {
  const tags = new Set(legendOf(deck)?.tags || [])
  const units = (deck?.cards || []).filter((entry) => entry.card.type === "Unit")
  const tagged = (entry) => (entry.card.tags || []).some((tag) => tags.has(tag))
  return (
    units.find((entry) => entry.card.supertype === "Champion" && tagged(entry)) ||
    units.find((entry) => entry.card.supertype === "Champion") ||
    units.find(tagged) ||
    null
  )
}

export function legendOf(deck) {
  if (deck?.legend) return deck.legend
  return deck?.cards?.find((entry) => entry.card.type === "Legend")?.card || null
}

export function runesOf(deck) {
  return (legendOf(deck)?.domains || [])
    .filter((domain) => domain !== "Colorless")
    .map((domain) => ({
      domain,
      label: RUNE_LABELS[DOMAIN_RUNE[domain]] || domain,
      src: glyphUrl(`rune_${DOMAIN_RUNE[domain]}`)
    }))
}

export function coverStyle(deck) {
  const art = legendOf(deck)?.image_url || deck?.cards?.[0]?.card.image_url
  return art ? { "--cover": `url(${cardThumb(art, 480)})` } : {}
}

/* Identité visuelle d'une boîte de deck : l'illustration de la légende plus les
   deux couleurs de ses domaines, servies en variables CSS (halo, liseré). */
export function deckIdentity(deck) {
  const domains = (legendOf(deck)?.domains || []).filter((domain) => domain !== "Colorless")
  const first = DOMAINS[domains[0]]?.color || "var(--gold)"
  const second = DOMAINS[domains[1]]?.color || first
  return { ...coverStyle(deck), "--d1": first, "--d2": second }
}

export function okCount(deck) {
  return deck?.checks?.filter((check) => check.ok).length ?? 0
}

/* « Légal » = conforme aux règles officielles de construction, « Illégal » = tout le reste
   (format libre, non reconnu par Riot). Les valeurs en base restent tournament / free. */
export const FORMAT_OPTIONS = [
  { value: "tournament", label: "Légal" },
  { value: "free", label: "Illégal" }
]

export function formatLabel(format) {
  return format === "free" ? "illégal" : "légal"
}

/* Pastille « Légal / Illégal » des boîtes de deck. Un deck est légal s'il est
   déclaré au format officiel ET qu'il passe toutes les règles de construction.
   Le listing communauté envoie `legal` (booléen), les autres vues `checks`. */
export function legalState(deck) {
  if (!deck) return null
  if (deck.format === "free") {
    return { ok: false, label: "Illégal", title: "Format libre : ce deck ne suit pas les règles officielles." }
  }
  const valid =
    typeof deck.legal === "boolean"
      ? deck.legal
      : Array.isArray(deck.checks)
        ? deck.checks.every((check) => check.ok)
        : null
  if (valid === null) return { ok: true, label: "Légal", title: "Deck au format officiel." }
  return valid
    ? { ok: true, label: "Légal", title: "Toutes les règles officielles de construction sont respectées." }
    : { ok: false, label: "Illégal", title: "Ce deck ne respecte pas encore toutes les règles de construction." }
}
