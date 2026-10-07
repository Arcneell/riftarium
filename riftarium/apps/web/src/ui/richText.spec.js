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

describe("abréviations de puissance (règles 135.2.e)", () => {
  const parts = (text) => richSegments(text, { rules: true })[0].parts

  it("[A] → glyphe arc-en-ciel", () => {
    expect(parts("[A]")[0]).toMatchObject({ type: "glyph", kind: "rune", domain: "rainbow" })
  })

  it("[1][C] → énergie 1 puis pastille C", () => {
    const [energy, pill] = parts("[1][C]")
    expect(energy).toMatchObject({ type: "glyph", kind: "energy", amount: "1" })
    expect(pill).toMatchObject({ type: "pill", value: "C", label: "puissance du domaine de la carte" })
  })

  it("[S] → puissance et [T] → épuisement (anciennes abréviations)", () => {
    expect(parts("[S]")[0]).toMatchObject({ type: "glyph", kind: "ink", token: "might" })
    expect(parts("[T]")[0]).toMatchObject({ type: "glyph", kind: "ink", token: "exhaust" })
  })

  it("[X] et [N] → pastilles texte avec libellé", () => {
    expect(parts("Assaut [X]")[1]).toMatchObject({ type: "pill", value: "X", label: "valeur variable X" })
    expect(parts("[N] XP")[0]).toMatchObject({ type: "pill", value: "N", label: "niveau, quantité d'XP N" })
  })

  it("les pastilles ne s'appliquent pas hors mode règles", () => {
    expect(richSegments("[C]")[0].parts[0].type).not.toBe("pill")
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

  it("refs : règle 123.4 devient une partie ref", () => {
    const parts = richSegments("Voir règle 123.4 puis.", { refs: true })[0].parts
    expect(parts.map((p) => p.type)).toEqual(["text", "ref", "text"])
    expect(parts[1]).toMatchObject({ value: "règle 123.4", ref: "123.4" })
  })

  it("refs : sections 103 et 104", () => {
    const parts = richSegments("sections 103 et section 104", { refs: true })[0].parts
    expect(parts.filter((p) => p.type === "ref").map((p) => p.ref)).toEqual(["103", "104"])
  })

  it("refs : sans l'option, rien ne change", () => {
    const parts = richSegments("Voir règle 123.4")[0].parts
    expect(parts.every((p) => p.type === "text")).toBe(true)
  })

  it("refs : une ref dans du gras reste en gras", () => {
    const segments = richSegments("a **règle 123.4** b", { refs: true })
    expect(segments[1].bold).toBe(true)
    expect(segments[1].parts[0]).toMatchObject({ type: "ref", ref: "123.4" })
  })

  it("renvoie une liste vide pour un texte vide", () => {
    expect(richSegments("")).toEqual([])
    expect(richSegments(null)).toEqual([])
  })
})
