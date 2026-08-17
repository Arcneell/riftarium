import { describe, expect, it } from "vitest"
import {
  cardsQuery,
  csvSplit,
  decodeEntities,
  glyphUrl,
  isFoil,
  keywordFamily,
  parseCardText,
  powerRuneGlyphs,
  toggleValue,
  variantLabel
} from "./cardText.js"

describe("parseCardText", () => {
  it("remplace les shortcodes par les glyphes officiels Riot", () => {
    const parts = parseCardText("Pay :rb_energy_2::rb_rune_fury: then :rb_might: / :rb_exhaust:.")
    expect(parts).toEqual([
      { type: "text", value: "Pay " },
      { type: "glyph", kind: "energy", token: "energy_2", label: "Énergie 2", amount: "2", src: glyphUrl("energy_2") },
      {
        type: "glyph",
        kind: "rune",
        token: "rune_fury",
        domain: "fury",
        label: "Rune de Fureur",
        src: glyphUrl("rune_fury")
      },
      { type: "text", value: " then " },
      { type: "glyph", kind: "ink", token: "might", label: "Puissance", src: glyphUrl("might") },
      { type: "text", value: " / " },
      { type: "glyph", kind: "ink", token: "exhaust", label: "Épuisement", src: glyphUrl("exhaust") },
      { type: "text", value: "." }
    ])
    expect(glyphUrl("might")).toBe(
      "https://assetcdn.rgpub.io/public/live/riot-shared/player-experiences/riot-glyphs/rb/latest/might.svg"
    )
  })

  it("transforme les mots-clés en badges colorés selon leur famille", () => {
    const parts = parseCardText("[Action] (Play on your turn.)[Assault 2] and [Deathknell] and [Vision]")
    const keywords = parts.filter((part) => part.type === "keyword")
    expect(keywords.map((part) => [part.label, part.family])).toEqual([
      ["Action", "timing"],
      ["Assault 2", "combat"],
      ["Deathknell", "state"],
      ["Vision", "utility"]
    ])
  })

  it("décode les entités HTML et rattache la flèche au mot-clé précédent", () => {
    const parts = parseCardText("[Level 3][&gt;] I have +1 :rb_might: and &quot;ready&quot;.")
    expect(parts[0]).toMatchObject({ type: "keyword", label: "Level 3", family: "state", arrow: true })
    expect(parts[1].value).toBe(" I have +1 ")
    expect(parts.at(-1).value).toBe(' and "ready".')
    expect(decodeEntities("a &amp; b &gt; c")).toBe("a & b > c")
  })

  it("ignore les marqueurs vides et laisse le texte inconnu intact", () => {
    expect(parseCardText("")).toEqual([])
    expect(parseCardText("[NO TEXT]")).toEqual([])
    expect(parseCardText("garde :rb_wat: ici")).toEqual([{ type: "text", value: "garde :rb_wat: ici" }])
    expect(keywordFamily("Assault 4")).toBe("combat")
    expect(keywordFamily("Inconnu")).toBe("utility")
  })
})

describe("isFoil / variantLabel", () => {
  it("marque Showcase, alt, signature et overnumbered comme foil", () => {
    expect(isFoil({ rarity: "Showcase" })).toBe(true)
    expect(isFoil({ alternate_art: true })).toBe(true)
    expect(isFoil({ signature: true })).toBe(true)
    expect(isFoil({ overnumbered: true })).toBe(true)
    expect(isFoil({ rarity: "Epic" })).toBe(false)
  })

  it("étiquette les variantes", () => {
    expect(variantLabel({ signature: true })).toBe("Signature")
    expect(variantLabel({ overnumbered: true })).toBe("Overnumbered")
    expect(variantLabel({ alternate_art: true })).toBe("Alt")
    expect(variantLabel({})).toBe("Normale")
  })
})

describe("powerRuneGlyphs", () => {
  it("répète le glyphe de rune du domaine autant de fois que le coût de pouvoir", () => {
    const runes = powerRuneGlyphs({ power: 2, domains: ["Order"] })
    expect(runes).toHaveLength(2)
    expect(runes[0]).toMatchObject({
      token: "rune_order",
      domain: "order",
      label: "Rune d'Ordre",
      src: glyphUrl("rune_order")
    })
    expect(powerRuneGlyphs({ power: 0, domains: ["Fury"] })).toEqual([])
    expect(powerRuneGlyphs({ power: 1, domains: [] })[0].token).toBe("rune_rainbow")
  })
})

describe("cardsQuery", () => {
  it("construit une query multi-valeurs CSV", () => {
    const params = cardsQuery(
      {
        q: "phoenix",
        set_id: ["OGN", "SFD"],
        type: ["Unit", "Spell"],
        domain: ["Fury"],
        rarity: ["Epic", "Rare"],
        energy: ["2", "7+"],
        page: 2
      },
      48
    )
    expect(params.get("q")).toBe("phoenix")
    expect(params.get("set_id")).toBe("OGN,SFD")
    expect(params.get("type")).toBe("Unit,Spell")
    expect(params.get("domain")).toBe("Fury")
    expect(params.get("rarity")).toBe("Epic,Rare")
    expect(params.get("energy")).toBe("2,7+")
    expect(params.get("page")).toBe("2")
    expect(params.get("size")).toBe("48")
  })

  it("toggle et csvSplit gèrent les listes de filtres", () => {
    expect(csvSplit("Epic, Rare")).toEqual(["Epic", "Rare"])
    expect(toggleValue(["Epic"], "Rare")).toEqual(["Epic", "Rare"])
    expect(toggleValue(["Epic", "Rare"], "Epic")).toEqual(["Rare"])
  })
})
