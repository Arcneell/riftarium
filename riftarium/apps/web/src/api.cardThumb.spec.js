import { describe, expect, it } from "vitest"
import { cardThumb } from "./api.js"

const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/abc-744x1039.png"

describe("cardThumb", () => {
  it("laisse les valeurs vides inchangées", () => {
    expect(cardThumb(null)).toBe(null)
    expect(cardThumb("")).toBe("")
    expect(cardThumb(undefined)).toBe(undefined)
  })

  it("remplace un paramètre w= déjà présent", () => {
    const url = `${CDN}?auto=format&fit=max&w=720&accountingTag=RB`
    expect(cardThumb(url, 180)).toBe(`${CDN}?auto=format&fit=max&w=180&accountingTag=RB`)
  })

  it("ajoute le redimensionnement sur une URL sans query", () => {
    expect(cardThumb(CDN, 180)).toBe(`${CDN}?auto=format&fit=max&w=180`)
  })

  it("ajoute le redimensionnement sans second point d'interrogation", () => {
    const url = `${CDN}?accountingTag=RB`
    expect(cardThumb(url, 180)).toBe(`${CDN}?accountingTag=RB&auto=format&fit=max&w=180`)
  })

  it("utilise 280 px par défaut", () => {
    expect(cardThumb(CDN)).toBe(`${CDN}?auto=format&fit=max&w=280`)
  })
})
