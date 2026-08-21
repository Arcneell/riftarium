import { ref } from "vue"
import { describe, expect, it, vi } from "vitest"
import { TOURNAMENT_CAPS, useDeckRules } from "./useDeckRules.js"

function card(overrides) {
  return {
    riftbound_id: "ogn-000-298",
    type: "Unit",
    rarity: "Common",
    domains: ["Fury"],
    energy: 2,
    ...overrides
  }
}

const legend = card({ id: "l1", name: "Légende Fury", type: "Legend", domains: ["Fury", "Mind"], energy: null })
const legendCalm = card({ id: "l2", name: "Légende Calm", type: "Legend", domains: ["Calm"], energy: null })
const unit = card({ id: "u1", riftbound_id: "ogn-037-298", name: "Phénix Immortel", energy: 4 })
const unitReprint = card({
  id: "u1-on",
  riftbound_id: "sfd-037-221",
  name: "Phénix Immortel (Overnumbered)",
  energy: 4
})
const calmUnit = card({ id: "c1", name: "Moine du Calme", domains: ["Calm"], energy: 3 })
const colorless = card({ id: "n1", name: "Golem Neutre", domains: ["Colorless"], energy: 1 })
const battlefield = (index) =>
  card({ id: `b${index}`, name: `Champ ${index}`, type: "Battlefield", domains: ["Calm"], energy: null })
const rune = card({ id: "r1", name: "Rune de Fureur", type: "Rune", domains: ["Fury"], energy: null })

function setup({ format = "tournament", cards = [], canEdit = true } = {}) {
  const deck = ref({ format, cards })
  const onLimit = vi.fn()
  const onNotice = vi.fn()
  const onAdded = vi.fn()
  const rules = useDeckRules(deck, { canEdit, onLimit, onNotice, onAdded })
  return { deck, rules, onLimit, onNotice, onAdded }
}

describe("useDeckRules", () => {
  it("expose les plafonds officiels du deck légal", () => {
    expect(TOURNAMENT_CAPS).toEqual({ Legend: 1, Battlefield: 1, Rune: 12, main: 3 })
  })

  it("légal : refuse toute carte tant que la légende n'est pas choisie", () => {
    const { rules, onLimit } = setup()
    expect(rules.addCard(unit)).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("Choisissez d'abord votre légende : elle fixe les domaines du deck.", "u1")
    expect(rules.zoneCounts.value.main).toBe(0)
  })

  it("légal : une seule légende, remplacée si on en choisit une autre", () => {
    const { rules, onLimit, onNotice } = setup()
    expect(rules.addCard(legend)).toBe(true)
    expect(rules.legendEntry.value.card.id).toBe("l1")

    expect(rules.addCard(legend)).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("Cette légende est déjà dans le deck.", "l1")

    expect(rules.addCard(legendCalm)).toBe(true)
    expect(onNotice).toHaveBeenCalledWith("Légende remplacée par Légende Calm.")
    expect(rules.legendEntry.value.card.id).toBe("l2")
    expect(rules.zoneCounts.value.Legend).toBe(1)
  })

  it("offDomain : hors identité de la légende, sauf Colorless, légendes et champs de bataille", () => {
    const { rules } = setup({ cards: [{ card: legend, qty: 1 }] })
    expect(rules.offDomain(calmUnit)).toBe(true)
    expect(rules.offDomain(unit)).toBe(false)
    expect(rules.offDomain(colorless)).toBe(false)
    expect(rules.offDomain(battlefield(1))).toBe(false)
    expect(rules.offDomain(legendCalm)).toBe(false)
  })

  it("offDomain : toujours faux sans légende", () => {
    const { rules } = setup()
    expect(rules.offDomain(calmUnit)).toBe(false)
  })

  it("légal : refuse une carte hors des domaines de la légende", () => {
    const { rules, onLimit } = setup({ cards: [{ card: legend, qty: 1 }] })
    expect(rules.addCard(calmUnit)).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("Moine du Calme est hors des domaines de votre légende.", "c1")
  })

  it("légal : plafond de 3 exemplaires, reprints et variantes comptent ensemble", () => {
    const { rules, onLimit } = setup({ cards: [{ card: legend, qty: 1 }] })
    expect(rules.addCard(unit)).toBe(true)
    expect(rules.addCard(unit)).toBe(true)
    expect(rules.addCard(unit)).toBe(true)
    expect(rules.inDeckQty(unit)).toBe(3)

    expect(rules.addCard(unit)).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("Maximum 3 exemplaires de Phénix Immortel.", "u1")

    /* La variante overnumbered appartient à la même famille de copies. */
    expect(rules.inDeckQty(unitReprint)).toBe(3)
    expect(rules.addCard(unitReprint)).toBe(false)
    expect(rules.zoneCounts.value.main).toBe(3)
  })

  it("légal : 3 champs de bataille maximum, un seul exemplaire de chaque", () => {
    const { rules, onLimit } = setup({ cards: [{ card: legend, qty: 1 }] })
    expect(rules.addCard(battlefield(1))).toBe(true)
    expect(rules.addCard(battlefield(2))).toBe(true)
    expect(rules.addCard(battlefield(3))).toBe(true)

    expect(rules.addCard(battlefield(4))).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("3 champs de bataille maximum.", "b4")

    expect(rules.addCard(battlefield(1))).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("Maximum 1 exemplaire(s) de Champ 1.", "b1")
    expect(rules.zoneCounts.value.Battlefield).toBe(3)
  })

  it("légal : 12 runes maximum de la même carte", () => {
    const { rules, onLimit } = setup({
      cards: [
        { card: legend, qty: 1 },
        { card: rune, qty: 12 }
      ]
    })
    expect(rules.addCard(rune)).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("Maximum 12 exemplaire(s) de Rune de Fureur.", "r1")
  })

  it("deck illégal : ni légende requise ni domaines, plafond global de 12 exemplaires", () => {
    const { rules, onLimit, onAdded } = setup({ format: "free", cards: [{ card: calmUnit, qty: 11 }] })
    expect(rules.addCard(calmUnit)).toBe(true)
    expect(onAdded).toHaveBeenCalledWith(calmUnit)
    expect(rules.inDeckQty(calmUnit)).toBe(12)

    expect(rules.addCard(calmUnit)).toBe(false)
    expect(onLimit).toHaveBeenCalledWith("12 exemplaires maximum.", "c1")
  })

  it("regroupe les cartes par zone et compte chaque zone", () => {
    const { rules } = setup({
      cards: [
        { card: legend, qty: 1 },
        { card: battlefield(1), qty: 1 },
        { card: rune, qty: 12 },
        { card: unit, qty: 3 }
      ]
    })
    expect(rules.grouped.value.Legend).toHaveLength(1)
    expect(rules.zoneCounts.value).toEqual({ Legend: 1, Battlefield: 1, Rune: 12, main: 3 })
    expect(rules.LIST_ZONES.some((zone) => zone.key === "Legend")).toBe(false)
    expect(rules.legendRunes.value.map((item) => item.domain)).toEqual(["Fury", "Mind"])
  })

  it("setQty retire un exemplaire et supprime la ligne à zéro, removeOne cible par id", () => {
    const { deck, rules } = setup({
      cards: [
        { card: legend, qty: 1 },
        { card: unit, qty: 2 }
      ]
    })
    rules.setQty(deck.value.cards[1], -1)
    expect(deck.value.cards[1].qty).toBe(1)

    rules.removeOne("u1")
    expect(deck.value.cards).toHaveLength(1)

    /* delta positif : repasse par addCard et ses plafonds */
    rules.setQty(deck.value.cards[0], 1)
    expect(rules.zoneCounts.value.Legend).toBe(1)
  })

  it("lecture seule : aucune mutation possible", () => {
    const { deck, rules, onLimit } = setup({ canEdit: ref(false), cards: [{ card: legend, qty: 1 }] })
    expect(rules.addCard(unit)).toBe(false)
    expect(onLimit).not.toHaveBeenCalled()
    rules.setQty(deck.value.cards[0], -1)
    expect(deck.value.cards).toHaveLength(1)
  })
})
