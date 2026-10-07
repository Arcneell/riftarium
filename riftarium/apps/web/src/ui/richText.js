import { parseCardText } from "../cardText.js"

/* Abréviations du texte officiel des règles ([R], [1], [E]…) → shortcodes Riot,
   que parseCardText sait ensuite rendre en glyphes. */
const SHORT_TOKENS = {
  R: ":rb_rune_fury:",
  G: ":rb_rune_calm:",
  B: ":rb_rune_mind:",
  O: ":rb_rune_body:",
  P: ":rb_rune_chaos:",
  Y: ":rb_rune_order:",
  A: ":rb_rune_rainbow:",
  E: ":rb_exhaust:",
  M: ":rb_might:",
  /* Anciennes abréviations de l'épuisement et de la puissance (règles 135.2.e). */
  T: ":rb_exhaust:",
  S: ":rb_might:"
}

/* Abréviations sans glyphe : pastille texte. [C] est la puissance du domaine de la carte
   (135.2.e.6), pas l'arc-en-ciel ([A]) ; [X] et [N] sont des valeurs variables. */
const PILL_TOKENS = {
  C: "puissance du domaine de la carte",
  X: "valeur variable X",
  N: "niveau, quantité d'XP N",
  /* Y n'est une pastille que lorsque le texte contient aussi [X] (438.3, 439.5). */
  Y: "valeur variable Y"
}
/* Marqueurs privés (zone d'usage privé Unicode) posés par expandRuleShorthand. */
const PILL_OPEN = "\uE000"
const PILL_CLOSE = "\uE001"
const PILL_PATTERN = /\uE000([A-Z])\uE001/g

/* Glyphes d'énergie publiés par Riot : de 0 à 12. Au-delà, aucun fichier n'existe :
   mieux vaut laisser « [42] » en clair qu'une image cassée. */
const MAX_ENERGY_GLYPH = 12

export function expandRuleShorthand(text) {
  const source = String(text ?? "")
  /* [Y] est la rune d'Ordre, sauf comme paramètre générique : à côté de [X], ou en tête de
     règle (438.3.b : « [Y] est le nombre… »). */
  const yIsParameter = source.includes("[X]") || /^\[Y\]\s/.test(source)
  return source.replace(/\[([RGBOPYAEMSTCXN]|\d{1,2})\]/g, (raw, token) => {
    if (token === "Y" && yIsParameter) return `${PILL_OPEN}Y${PILL_CLOSE}`
    if (SHORT_TOKENS[token]) return SHORT_TOKENS[token]
    if (PILL_TOKENS[token]) return `${PILL_OPEN}${token}${PILL_CLOSE}`
    const amount = Number(token)
    return Number.isInteger(amount) && amount <= MAX_ENERGY_GLYPH ? `:rb_energy_${amount}:` : raw
  })
}

/* Renvois entre règles (« règle 123.4 », « sections 103 ») : même expression que
   l'ancien RulesView.formatText. */
const REF_PATTERN = /\b(règles?|sections?)\s+(\d{3}(?:\.\d+)*(?:\.[a-z])?(?:\.\d+)*)/gi

/* Remplace les marqueurs de pastille, dans les parties de texte, par des parties « pill ». */
function splitPills(parts) {
  return parts.flatMap((part) => {
    if (part.type !== "text" || !part.value.includes(PILL_OPEN)) return [part]
    const out = []
    let last = 0
    for (const match of part.value.matchAll(PILL_PATTERN)) {
      if (match.index > last) out.push({ type: "text", value: part.value.slice(last, match.index) })
      out.push({ type: "pill", value: match[1], label: PILL_TOKENS[match[1]] })
      last = match.index + match[0].length
    }
    if (last < part.value.length) out.push({ type: "text", value: part.value.slice(last) })
    return out
  })
}

/* Découpe un morceau en parties : renvois (si demandés) puis texte / mot-clé / glyphe. */
function chunkParts(chunk, refs, rules) {
  return splitPills(chunkPartsRaw(chunk, refs, rules))
}
function chunkPartsRaw(chunk, refs, rules) {
  if (!refs) return parseCardText(chunk, { rules })
  const parts = []
  let last = 0
  for (const match of chunk.matchAll(REF_PATTERN)) {
    if (match.index > last) parts.push(...parseCardText(chunk.slice(last, match.index), { rules }))
    parts.push({ type: "ref", value: match[0], ref: match[2].replace(/\.$/, "") })
    last = match.index + match[0].length
  }
  if (last < chunk.length) parts.push(...parseCardText(chunk.slice(last), { rules }))
  return parts
}

/* Segments gras / normal, chacun découpé en parties (texte, mot-clé, glyphe, renvoi).
   Clé composite : l'index seul faisait réutiliser un nœud de texte pour un glyphe
   quand le texte changeait à la même position. */
export function richSegments(text, { rules = false, refs = false } = {}) {
  if (!text) return []
  const source = rules ? expandRuleShorthand(text) : String(text)
  const segments = []
  for (const [i, chunk] of source.split("**").entries()) {
    if (!chunk) continue
    segments.push({
      bold: i % 2 === 1,
      parts: chunkParts(chunk, refs, rules).map((part, j) => ({
        ...part,
        key: `${i}-${j}-${part.type}-${part.kind || ""}-${part.value || part.label || ""}`
      }))
    })
  }
  return segments
}
