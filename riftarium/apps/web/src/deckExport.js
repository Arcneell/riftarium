import { getCodeFromDeck } from "@piltoverarchive/riftbound-deck-codes"
import { championOf, groupDeck } from "./deckDisplay.js"

const STANDARD = /^([a-z][a-z0-9]*)-(\d+)([a-z*]?)-(\d+)$/i
const RUNIC = /^([a-z][a-z0-9]*)-r(\d+)([a-z]?)$/i
const SPECIAL = /^([a-z][a-z0-9]*)-sp(\d+)([a-z]?)(?:-(\d+))?$/i

/** Convertit un `riftbound_id` Riftarium (`ogn-247-298`) en code de carte (`OGN-247`). */
export function toCardCode(riftboundId) {
  const raw = String(riftboundId || "").trim()
  if (!raw) return ""
  const standard = STANDARD.exec(raw)
  if (standard) {
    const variant = standard[3] === "*" ? "s" : (standard[3] || "").toLowerCase()
    return `${standard[1].toUpperCase()}-${standard[2].padStart(3, "0")}${variant}`
  }
  const rune = RUNIC.exec(raw)
  if (rune) {
    return `${rune[1].toUpperCase()}-R${rune[2].padStart(2, "0")}${(rune[3] || "").toLowerCase()}`
  }
  const special = SPECIAL.exec(raw)
  if (special) {
    return `${special[1].toUpperCase()}-SP${Number(special[2])}${special[3] || ""}`
  }
  return raw.toUpperCase()
}

function qtyLines(entries, { skipId = null, skipQty = 0 } = {}) {
  return entries
    .map((entry) => {
      let qty = entry.qty
      if (skipId && entry.card.id === skipId) qty -= skipQty
      if (qty <= 0) return null
      return `${qty} ${entry.card.name}`
    })
    .filter(Boolean)
}

/** Liste sectionnée compatible Rift Atlas / UVS / Carde. */
export function atlasList(deck) {
  const groups = groupDeck(deck)
  const champion = championOf(deck)
  const blocks = []
  const push = (title, lines) => {
    if (!lines.length) return
    blocks.push(`~~${title}~~`, ...lines, "")
  }
  push("Legend", qtyLines(groups.Legend))
  if (champion) push("Champion", [`1 ${champion.card.name}`])
  push("Battlefields", qtyLines(groups.Battlefield))
  push("Runes", qtyLines(groups.Rune))
  push("Main Deck", qtyLines(groups.main, champion ? { skipId: champion.card.id, skipQty: 1 } : {}))
  return `${blocks.join("\n").trim()}\n`
}

/** Liste compacte `3x Nom`, tous exemplaires inclus. */
export function nameList(deck) {
  const groups = groupDeck(deck)
  return ["Legend", "Battlefield", "Rune", "main"]
    .flatMap((key) => groups[key].map((entry) => `${entry.qty}x ${entry.card.name}`))
    .join("\n")
}

export function encoderCards(deck) {
  const counts = new Map()
  for (const entry of deck?.cards || []) {
    const cardCode = toCardCode(entry.card.riftbound_id)
    if (!cardCode || !entry.qty) continue
    counts.set(cardCode, (counts.get(cardCode) || 0) + entry.qty)
  }
  return [...counts].map(([cardCode, count]) => ({ cardCode, count }))
}

/** Code de deck partageable (Rift Atlas, Piltover Archive, etc.). */
export function deckCode(deck) {
  const mainDeck = encoderCards(deck)
  if (!mainDeck.length) throw new Error("Ce deck est vide.")
  const champion = championOf(deck)
  const chosen = champion ? toCardCode(champion.card.riftbound_id) : undefined
  return getCodeFromDeck(mainDeck, [], chosen)
}

export async function copyText(text) {
  if (!navigator.clipboard?.writeText) throw new Error("Copie impossible")
  await navigator.clipboard.writeText(text)
}
