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
  C: ":rb_rune_rainbow:",
  E: ":rb_exhaust:",
  M: ":rb_might:"
}

/* Glyphes d'énergie publiés par Riot : de 0 à 12. Au-delà, aucun fichier n'existe :
   mieux vaut laisser « [42] » en clair qu'une image cassée. */
const MAX_ENERGY_GLYPH = 12

export function expandRuleShorthand(text) {
  return String(text ?? "").replace(/\[([RGBOPYCEM]|\d{1,2})\]/g, (raw, token) => {
    if (SHORT_TOKENS[token]) return SHORT_TOKENS[token]
    const amount = Number(token)
    return Number.isInteger(amount) && amount <= MAX_ENERGY_GLYPH ? `:rb_energy_${amount}:` : raw
  })
}

/* Segments gras / normal, chacun découpé en parties (texte, mot-clé, glyphe).
   Clé composite : l'index seul faisait réutiliser un nœud de texte pour un glyphe
   quand le texte changeait à la même position. */
export function richSegments(text, { rules = false } = {}) {
  if (!text) return []
  const source = rules ? expandRuleShorthand(text) : String(text)
  const segments = []
  for (const [i, chunk] of source.split("**").entries()) {
    if (!chunk) continue
    segments.push({
      bold: i % 2 === 1,
      parts: parseCardText(chunk).map((part, j) => ({
        ...part,
        key: `${i}-${j}-${part.type}-${part.kind || ""}-${part.value || part.label || ""}`
      }))
    })
  }
  return segments
}
