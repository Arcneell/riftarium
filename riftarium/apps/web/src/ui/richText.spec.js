import { readFileSync } from "node:fs"
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

  it("[Y] reste la rune d'Ordre seule", () => {
    expect(parts("Payez [Y].")[1]).toMatchObject({ type: "glyph", kind: "rune", token: "rune_order" })
  })

  it("[Y] devient une pastille quand le texte contient aussi [X]", () => {
    const result = parts("Remplacez [X] par [Y].")
    expect(result.find((p) => p.type === "pill" && p.value === "Y")).toMatchObject({
      type: "pill",
      label: "valeur variable Y"
    })
    expect(result.find((p) => p.type === "pill" && p.value === "X")).toMatchObject({ type: "pill" })
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

describe("symbole [>] du texte officiel", () => {
  const parts = (text, options) => richSegments(text, options)[0].parts

  it("règles : [>] hors mot-clé devient une pastille avec libellé", () => {
    const result = parts("indiqué par le symbole [>].", { rules: true, refs: true })
    expect(result.find((p) => p.type === "pill")).toMatchObject({
      value: "›",
      label: "symbole de compétence dépendante"
    })
  })

  it("règles : « [Niveau] [N][>] [Texte] » garde N, la flèche et le mot-clé", () => {
    const result = parts("[Niveau] [N][>] [Texte]", { rules: true, refs: true })
    expect(result.filter((p) => p.type === "pill").map((p) => p.value)).toEqual(["N", "›"])
  })

  it("règles : la flèche après un mot-clé reste portée par le mot-clé", () => {
    const result = parts("[Niveau][>] 3", { rules: true, refs: true })
    expect(result[0]).toMatchObject({ type: "keyword", arrow: true })
    expect(result.some((p) => p.type === "pill")).toBe(false)
  })

  it("cartes (hors règles) : un [>] isolé reste ignoré, après un mot-clé il devient une flèche", () => {
    expect(parts("symbole [>].").map((p) => p.type)).toEqual(["text"])
    expect(parts("[Assault][>] 2")[0]).toMatchObject({ type: "keyword", arrow: true })
  })

  it("[Y] en tête de règle (438.3.b) est un paramètre, pas la rune d'Ordre", () => {
    const result = parts("[Y] est l'élément qui va remplacer la cible.", { rules: true })
    expect(result[0]).toMatchObject({ type: "pill", value: "Y", label: "valeur variable Y" })
  })

  it("[Y] garde la rune d'Ordre en 134.2.f, 429.5 et dans l'exemple de 206", () => {
    const order = (text) => parts(text, { rules: true, refs: true }).find((p) => p.token === "rune_order")
    expect(order("L'ordre est associé à la couleur jaune. Son abréviation est [Y]")).toBeTruthy()
    expect(order("Ajoutez [une ou plusieurs ressources]. Par exemple, « [Ajout] [Y]. » signifie")).toBeTruthy()
    expect(order("Atakhan indique « Payez [Y] pour me jouer. »")).toBeTruthy()
  })
})

describe("corpus de data/rules-fr.json", () => {
  const corpus = JSON.parse(readFileSync("../../data/rules-fr.json", "utf8"))
  const texts = []
  for (const doc of Object.values(corpus)) {
    for (const chapter of doc.chapters) {
      for (const section of chapter.sections) {
        for (const entry of section.entries) {
          texts.push(entry.text)
          for (const example of entry.examples ?? []) texts.push(typeof example === "string" ? example : example.text)
        }
      }
    }
  }
  const TOKEN = /\[[^\][]+\]/g

  it("couvre un corpus non vide", () => {
    expect(texts.length).toBeGreaterThan(500)
  })

  it("chaque jeton [...] du texte source est rendu, jamais perdu", () => {
    const lost = []
    for (const text of texts) {
      if (!text) continue
      /* [NO TEXT] est volontairement muet (marqueur des données de cartes). */
      const expected = (text.match(TOKEN) ?? []).filter((token) => token.toUpperCase() !== "[NO TEXT]").length
      let rendered = 0
      for (const segment of richSegments(text, { rules: true, refs: true })) {
        for (const part of segment.parts) {
          if (part.type === "glyph" || part.type === "pill" || part.type === "keyword") rendered += 1
          if (part.type === "keyword" && part.arrow) rendered += 1
          if (part.type === "text" || part.type === "ref") rendered += (part.value.match(TOKEN) ?? []).length
        }
      }
      if (rendered !== expected) lost.push(`${expected} → ${rendered} : ${text.slice(0, 100)}`)
    }
    expect(lost).toEqual([])
  })
})
