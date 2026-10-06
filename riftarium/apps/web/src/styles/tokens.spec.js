import fs from "node:fs"
import { describe, expect, it } from "vitest"

/* Chemin relatif à l'application (racine vitest) : import.meta.url est une URL http sous jsdom.
   Les tokens de texte doivent rester lisibles (WCAG AA, 4,5:1) sur les trois fonds :
   une retouche de couleur qui casse le contraste doit faire échouer la CI. */
const css = fs.readFileSync("src/styles/tokens.css", "utf8")

function token(name) {
  const match = css.match(new RegExp(`--${name}:\\s*(#[0-9a-fA-F]{6})\\b`))
  if (!match) throw new Error(`token --${name} absent de tokens.css`)
  return match[1]
}

function luminance(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const value = parseInt(hex.slice(i, i + 2), 16) / 255
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

function contrast(a, b) {
  const [light, dark] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (light + 0.05) / (dark + 0.05)
}

const BACKGROUNDS = ["bg", "bg-raised", "bg-sunken"]

describe("tokens de couleur", () => {
  it.each(["ink", "ink-muted", "bronze-light", "blood-text"])("--%s reste lisible sur les trois fonds", (name) => {
    for (const background of BACKGROUNDS) {
      expect(contrast(token(name), token(background))).toBeGreaterThanOrEqual(4.5)
    }
  })

  it("le texte blanc d'un bouton principal reste lisible sur --blood", () => {
    expect(contrast("#ffffff", token("blood"))).toBeGreaterThanOrEqual(4.5)
  })
})
