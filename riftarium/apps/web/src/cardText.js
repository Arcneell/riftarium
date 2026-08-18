/* Glyphes officiels Riot : les noms de fichiers reprennent exactement les shortcodes `:rb_…:`. */
const GLYPH_BASE = "https://assetcdn.rgpub.io/public/live/riot-shared/player-experiences/riot-glyphs/rb/latest"

const TOKEN_RE = /:rb_([a-z0-9_]+):|\[([^\][]+)\]/g

const ENTITIES = {
  "&gt;": ">",
  "&lt;": "<",
  "&amp;": "&",
  "&quot;": '"',
  "&#39;": "'",
  "&apos;": "'",
  "&nbsp;": " "
}

const RUNES = ["fury", "calm", "mind", "body", "chaos", "order", "rainbow"]

export const RUNE_LABELS = {
  fury: "Rune de Fureur",
  calm: "Rune de Calme",
  mind: "Rune d'Esprit",
  body: "Rune de Corps",
  chaos: "Rune de Chaos",
  order: "Rune d'Ordre",
  rainbow: "Rune libre"
}

export const DOMAIN_RUNE = {
  Fury: "fury",
  Calm: "calm",
  Mind: "mind",
  Body: "body",
  Chaos: "chaos",
  Order: "order",
  Colorless: "rainbow"
}

/* Familles de couleurs des mots-clés, relevées sur les cartes officielles. */
const KEYWORD_FAMILIES = {
  timing: ["action", "reaction", "accelerate", "hidden", "ambush", "flow", "quick-draw", "repeat"],
  combat: ["assault", "shield", "tank", "deflect", "backline"],
  state: ["deathknell", "hunt", "level", "empowered", "ganking", "temporary", "legion"],
  utility: ["vision", "empower", "weaponmaster", "equip", "buff", "stun", "mighty", "predict", "burn", "unique", "add"]
}

const FAMILY_BY_KEYWORD = Object.entries(KEYWORD_FAMILIES).reduce((map, [family, keywords]) => {
  for (const keyword of keywords) map[keyword] = family
  return map
}, {})

/* Alias français des mots-clés (texte des règles et pages d'aide). */
const KEYWORD_FR = {
  accélération: "accelerate",
  réaction: "reaction",
  assaut: "assault",
  bouclier: "shield",
  "arrière-ligne": "backline",
  protection: "deflect",
  caché: "hidden",
  embuscade: "ambush",
  agonie: "deathknell",
  temporaire: "temporary",
  légion: "legion",
  niveau: "level",
  chasse: "hunt",
  amplification: "empower",
  amplifié: "empowered",
  gank: "ganking",
  flux: "flow",
  répétition: "repeat",
  "expert en armes": "weaponmaster",
  équiper: "equip",
  dégainer: "quick-draw",
  étourdissement: "stun",
  prédiction: "predict",
  brûler: "burn",
  ajout: "add",
  ajoutez: "add",
  "unité puissante": "mighty"
}

export function glyphUrl(token) {
  return `${GLYPH_BASE}/${token}.svg`
}

export function powerRuneGlyphs(card) {
  const n = Number(card?.power) || 0
  if (n < 1) return []
  const domain = DOMAIN_RUNE[card?.domains?.[0]] || "rainbow"
  return Array.from({ length: n }, () => ({
    token: `rune_${domain}`,
    domain,
    label: RUNE_LABELS[domain],
    src: glyphUrl(`rune_${domain}`)
  }))
}

export function decodeEntities(text) {
  return String(text).replace(/&(?:gt|lt|amp|quot|apos|nbsp|#39);/g, (entity) => ENTITIES[entity] ?? entity)
}

export function keywordFamily(label) {
  const base = label.replace(/\s+\d+$/, "").toLowerCase()
  return FAMILY_BY_KEYWORD[KEYWORD_FR[base] ?? base] || "utility"
}

export function isFoil(card) {
  return Boolean(
    card?.foil || card?.alternate_art || card?.signature || card?.overnumbered || card?.rarity === "Showcase"
  )
}

export function variantLabel(card) {
  if (card?.signature) return "Signature"
  if (card?.overnumbered) return "Overnumbered"
  if (card?.alternate_art) return "Alt"
  return "Normale"
}

export function parseCardText(text) {
  if (!text) return []
  const source = decodeEntities(text)
  const parts = []
  let last = 0

  for (const match of source.matchAll(TOKEN_RE)) {
    if (match.index > last) pushText(parts, source.slice(last, match.index))
    last = match.index + match[0].length
    if (match[1] !== undefined) {
      pushGlyph(parts, match[1], match[0])
    } else {
      pushBracket(parts, match[2].trim(), match[0])
    }
  }
  if (last < source.length) pushText(parts, source.slice(last))
  return parts
}

function pushText(parts, value) {
  if (!value) return
  const previous = parts[parts.length - 1]
  if (previous?.type === "text") previous.value += value
  else parts.push({ type: "text", value })
}

function pushGlyph(parts, token, raw) {
  if (token === "might" || token === "exhaust") {
    const label = token === "might" ? "Puissance" : "Épuisement"
    parts.push({ type: "glyph", kind: "ink", token, label, src: glyphUrl(token) })
    return
  }
  if (token.startsWith("energy_")) {
    const amount = token.slice("energy_".length)
    parts.push({ type: "glyph", kind: "energy", token, label: `Énergie ${amount}`, amount, src: glyphUrl(token) })
    return
  }
  if (token.startsWith("rune_")) {
    const domain = token.slice("rune_".length)
    if (RUNES.includes(domain)) {
      parts.push({ type: "glyph", kind: "rune", token, domain, label: RUNE_LABELS[domain], src: glyphUrl(token) })
      return
    }
  }
  pushText(parts, raw)
}

function pushBracket(parts, label, raw) {
  if (/^>+$/.test(label)) {
    const previous = parts[parts.length - 1]
    if (previous?.type === "keyword") previous.arrow = true
    return
  }
  if (label.toUpperCase() === "NO TEXT") return
  parts.push({ type: "keyword", label, family: keywordFamily(label), arrow: false, raw })
}

export function csvJoin(values) {
  return values.filter(Boolean).join(",")
}

export function csvSplit(value) {
  if (!value) return []
  return String(value)
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean)
}

export function toggleValue(list, value) {
  return list.includes(value) ? list.filter((item) => item !== value) : [...list, value]
}

export function cardsQuery(state, size) {
  const params = new URLSearchParams({ page: String(state.page), size: String(size) })
  if (state.q) params.set("q", state.q)
  if (state.set_id.length) params.set("set_id", csvJoin(state.set_id))
  if (state.type.length) params.set("type", csvJoin(state.type))
  if (state.domain.length) params.set("domain", csvJoin(state.domain))
  if (state.rarity.length) params.set("rarity", csvJoin(state.rarity))
  if (state.energy.length) params.set("energy", csvJoin(state.energy))
  return params
}
