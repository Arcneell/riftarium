import { describe, expect, it } from "vitest"
import { championOf, deckIdentity, groupDeck, legalState, legendOf, runesOf, zoneOf } from "./deckDisplay.js"

const card = (over = {}) => ({ id: "c", name: "Carte", type: "Unit", energy: 1, domains: [], tags: [], ...over })

describe("zoneOf", () => {
  it("range chaque type dans sa zone, le reste dans le deck principal", () => {
    expect(zoneOf(card({ type: "Legend" }))).toBe("Legend")
    expect(zoneOf(card({ type: "Battlefield" }))).toBe("Battlefield")
    expect(zoneOf(card({ type: "Rune" }))).toBe("Rune")
    expect(zoneOf(card({ type: "Unit" }))).toBe("main")
    expect(zoneOf(card({ type: "Spell" }))).toBe("main")
  })

  it("ne se laisse pas prendre par un type héritant du prototype d'Object", () => {
    expect(zoneOf(card({ type: "constructor" }))).toBe("main")
    expect(zoneOf(card({ type: "toString" }))).toBe("main")
    expect(zoneOf(card({ type: "__proto__" }))).toBe("main")
  })

  it("tolère une carte absente ou sans type", () => {
    expect(zoneOf(null)).toBe("main")
    expect(zoneOf(undefined)).toBe("main")
    expect(zoneOf({})).toBe("main")
  })
})

describe("groupDeck", () => {
  it("répartit les entrées par zone et trie par énergie puis par nom", () => {
    const deck = {
      cards: [
        { card: card({ id: "u3", name: "Zed", energy: 2 }), qty: 1 },
        { card: card({ id: "u1", name: "Ashe", energy: 2 }), qty: 2 },
        { card: card({ id: "u2", name: "Braum", energy: 1 }), qty: 1 },
        { card: card({ id: "l", name: "Viktor", type: "Legend", energy: null }), qty: 1 },
        { card: card({ id: "r", name: "Rune de fureur", type: "Rune", energy: null }), qty: 12 },
        { card: card({ id: "b", name: "Le Placard", type: "Battlefield", energy: null }), qty: 1 }
      ]
    }
    const groups = groupDeck(deck)
    expect(groups.main.map((entry) => entry.card.id)).toEqual(["u2", "u1", "u3"])
    expect(groups.Legend.map((entry) => entry.card.id)).toEqual(["l"])
    expect(groups.Rune.map((entry) => entry.card.id)).toEqual(["r"])
    expect(groups.Battlefield.map((entry) => entry.card.id)).toEqual(["b"])
  })

  it("les cartes sans énergie passent avant celles à 0", () => {
    const deck = {
      cards: [
        { card: card({ id: "zero", name: "Zéro", energy: 0 }), qty: 1 },
        { card: card({ id: "nul", name: "Sans coût", energy: null }), qty: 1 }
      ]
    }
    expect(groupDeck(deck).main.map((entry) => entry.card.id)).toEqual(["nul", "zero"])
  })

  it("rend les quatre zones vides pour un deck absent", () => {
    expect(groupDeck(null)).toEqual({ Legend: [], Battlefield: [], Rune: [], main: [] })
    expect(groupDeck({})).toEqual({ Legend: [], Battlefield: [], Rune: [], main: [] })
  })
})

describe("legendOf et runesOf", () => {
  it("préfère la légende servie par l'API, sinon la cherche dans les cartes", () => {
    const legend = card({ id: "l", type: "Legend", domains: ["Fury", "Colorless"] })
    expect(legendOf({ legend })).toBe(legend)
    expect(legendOf({ cards: [{ card: legend, qty: 1 }] })).toBe(legend)
    expect(legendOf({ cards: [{ card: card(), qty: 1 }] })).toBeNull()
    expect(legendOf(null)).toBeNull()
  })

  it("les runes suivent les domaines de la légende, Colorless exclu", () => {
    const legend = card({ id: "l", type: "Legend", domains: ["Fury", "Colorless", "Calm"] })
    expect(runesOf({ legend }).map((rune) => rune.domain)).toEqual(["Fury", "Calm"])
    expect(runesOf(null)).toEqual([])
  })
})

describe("championOf", () => {
  const legend = card({ id: "l", type: "Legend", tags: ["Noxus"] })

  it("préfère un champion partageant un tag de la légende", () => {
    const deck = {
      legend,
      cards: [
        { card: card({ id: "a", supertype: "Champion", tags: ["Ionia"] }), qty: 1 },
        { card: card({ id: "b", supertype: "Champion", tags: ["Noxus"] }), qty: 1 }
      ]
    }
    expect(championOf(deck).card.id).toBe("b")
  })

  it("à défaut, n'importe quel champion, puis n'importe quelle unité taguée", () => {
    const onlyChampion = { legend, cards: [{ card: card({ id: "a", supertype: "Champion" }), qty: 1 }] }
    expect(championOf(onlyChampion).card.id).toBe("a")

    const onlyTagged = { legend, cards: [{ card: card({ id: "t", tags: ["Noxus"] }), qty: 1 }] }
    expect(championOf(onlyTagged).card.id).toBe("t")
  })

  it("ne retient que des unités, et renvoie null quand il n'y a rien à mettre en avant", () => {
    const spellOnly = { legend, cards: [{ card: card({ id: "s", type: "Spell", tags: ["Noxus"] }), qty: 1 }] }
    expect(championOf(spellOnly)).toBeNull()
    expect(championOf(null)).toBeNull()
  })
})

describe("legalState", () => {
  it("un deck au format libre est toujours annoncé illégal", () => {
    expect(legalState({ format: "free", legal: true })).toMatchObject({ ok: false, label: "Illégal" })
  })

  it("le booléen `legal` du listing communauté fait foi", () => {
    expect(legalState({ format: "tournament", legal: true })).toMatchObject({ ok: true, label: "Légal" })
    expect(legalState({ format: "tournament", legal: false })).toMatchObject({ ok: false, label: "Illégal" })
  })

  it("sinon les `checks` doivent tous passer", () => {
    const checks = [{ ok: true }, { ok: false }]
    expect(legalState({ format: "tournament", checks })).toMatchObject({ ok: false })
    expect(legalState({ format: "tournament", checks: [{ ok: true }] })).toMatchObject({ ok: true })
  })

  it("sans `legal` ni `checks`, on ne crie pas à l'illégalité", () => {
    expect(legalState({ format: "tournament" })).toMatchObject({ ok: true, label: "Légal" })
    expect(legalState({ format: "tournament", checks: "bogus" })).toMatchObject({ ok: true, label: "Légal" })
  })

  it("pas de deck, pas de pastille", () => {
    expect(legalState(null)).toBeNull()
  })
})

describe("deckIdentity", () => {
  it("expose l'illustration en url() cité et les deux couleurs de domaine", () => {
    const legend = card({
      id: "l",
      type: "Legend",
      domains: ["Fury", "Calm"],
      image_url: "https://cmsassets.rgpub.io/legend.png?w=1024"
    })
    const style = deckIdentity({ legend })
    expect(style["--cover"]).toBe('url("https://cmsassets.rgpub.io/legend.png?w=480")')
    expect(style["--d1"]).toBe("var(--fury)")
    expect(style["--d2"]).toBe("var(--calm)")
  })

  it("neutralise une URL forgée qui tenterait de sortir du url()", () => {
    const legend = card({
      id: "l",
      type: "Legend",
      image_url: 'https://cmsassets.rgpub.io/a");background:red;--x:url("b.png'
    })
    const cover = deckIdentity({ legend })["--cover"]
    expect(cover.startsWith('url("')).toBe(true)
    expect(cover.endsWith('")')).toBe(true)
    expect(cover.slice(5, -2)).not.toMatch(/["'()\s]/)
  })

  it("sans illustration : aucune variable --cover, mais l'or par défaut", () => {
    const style = deckIdentity({ legend: card({ id: "l", type: "Legend" }) })
    expect(style["--cover"]).toBeUndefined()
    expect(style["--d1"]).toBe("var(--gold)")
    expect(style["--d2"]).toBe("var(--gold)")
  })
})
