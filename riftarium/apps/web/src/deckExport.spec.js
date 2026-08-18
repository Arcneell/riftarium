import { describe, expect, it } from "vitest"
import { atlasList, deckCode, encoderCards, nameList, toCardCode } from "./deckExport.js"

function entry(overrides, qty = 1) {
  return {
    qty,
    card: {
      id: overrides.riftbound_id,
      riftbound_id: "ogn-000-298",
      name: "Carte",
      type: "Unit",
      tags: [],
      ...overrides
    }
  }
}

const sample = {
  name: "Fureur d'Ahri",
  cards: [
    entry({ riftbound_id: "ogn-247-298", name: "Daughter of the Void", type: "Legend", tags: ["Ahri"] }),
    entry({
      riftbound_id: "ogn-119-298",
      name: "Ahri, Inquisitive",
      type: "Unit",
      supertype: "Champion",
      tags: ["Ahri"]
    }),
    entry({ riftbound_id: "ogn-275-298", name: "Altar to Unity", type: "Battlefield" }),
    entry({ riftbound_id: "ogn-007-298", name: "Fury Rune", type: "Rune" }, 6),
    entry({ riftbound_id: "ogn-009-298", name: "Mind Rune", type: "Rune" }, 6),
    entry({ riftbound_id: "ogn-004-298", name: "Charm" }, 3)
  ]
}

describe("toCardCode", () => {
  it("passe les identifiants Riftarium en codes de cartes", () => {
    expect(toCardCode("ogn-247-298")).toBe("OGN-247")
    expect(toCardCode("ogn-007a-298")).toBe("OGN-007a")
    expect(toCardCode("ogn-037*-298")).toBe("OGN-037s")
    expect(toCardCode("ven-r04")).toBe("VEN-R04")
    expect(toCardCode("ven-r4")).toBe("VEN-R04")
    expect(toCardCode("ven-sp4-006")).toBe("VEN-SP4")
  })
})

describe("listes d'export", () => {
  it("produit une liste sectionnée pour Rift Atlas, champion à part", () => {
    const text = atlasList(sample)
    expect(text).toContain("~~Legend~~")
    expect(text).toContain("1 Daughter of the Void")
    expect(text).toContain("~~Champion~~")
    expect(text).toContain("1 Ahri, Inquisitive")
    expect(text).toContain("~~Battlefields~~")
    expect(text).toContain("~~Runes~~")
    expect(text).toContain("6 Fury Rune")
    expect(text).toContain("~~Main Deck~~")
    expect(text).toContain("3 Charm")
    expect(text).not.toMatch(/Main Deck[\s\S]*Ahri, Inquisitive/)
  })

  it("produit une liste simple avec tous les exemplaires", () => {
    expect(nameList(sample)).toContain("1x Ahri, Inquisitive")
    expect(nameList(sample)).toContain("3x Charm")
    expect(nameList(sample)).toContain("6x Fury Rune")
  })
})

describe("deckCode", () => {
  it("encode un code partageable à partir des cartes", () => {
    const code = deckCode(sample)
    expect(code).toMatch(/^[A-Z2-7]+$/)
    expect(encoderCards(sample)).toEqual(
      expect.arrayContaining([
        { cardCode: "OGN-247", count: 1 },
        { cardCode: "OGN-007", count: 6 },
        { cardCode: "OGN-119", count: 1 }
      ])
    )
  })

  it("refuse un deck vide", () => {
    expect(() => deckCode({ cards: [] })).toThrow("Ce deck est vide.")
  })
})
