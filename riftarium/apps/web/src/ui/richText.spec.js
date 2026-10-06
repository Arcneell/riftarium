import { describe, expect, it } from "vitest"
import { expandRuleShorthand, richSegments } from "./richText.js"

describe("expandRuleShorthand", () => {
  it("convertit les symboles abrégés des règles officielles en shortcodes Riot", () => {
    expect(expandRuleShorthand("Payez [2] et [R], épuisez [E], gagnez [M].")).toBe(
      "Payez :rb_energy_2: et :rb_rune_fury:, épuisez :rb_exhaust:, gagnez :rb_might:."
    )
  })

  it("laisse en clair une énergie sans glyphe publié (au-delà de 12)", () => {
    expect(expandRuleShorthand("Coût [42]")).toBe("Coût [42]")
  })
})

describe("richSegments", () => {
  it("découpe le gras et analyse chaque segment", () => {
    const segments = richSegments("Avant **Assaut** après")
    expect(segments.map((s) => s.bold)).toEqual([false, true, false])
    expect(segments[1].parts[0]).toMatchObject({ type: "text", value: "Assaut" })
  })

  it("n'applique les abréviations qu'en mode règles", () => {
    const plain = richSegments("[R]")
    const rules = richSegments("[R]", { rules: true })
    expect(plain[0].parts[0].type).toBe("keyword")
    expect(rules[0].parts[0]).toMatchObject({ type: "glyph", kind: "rune" })
  })

  it("donne une clé distincte à chaque partie", () => {
    const keys = richSegments(":rb_might: [Assault 2] texte")[0].parts.map((p) => p.key)
    expect(new Set(keys).size).toBe(keys.length)
  })

  it("renvoie une liste vide pour un texte vide", () => {
    expect(richSegments("")).toEqual([])
    expect(richSegments(null)).toEqual([])
  })
})
