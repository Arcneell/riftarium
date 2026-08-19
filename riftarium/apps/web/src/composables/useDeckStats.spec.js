import { ref } from "vue"
import { describe, expect, it } from "vitest"
import { useDeckStats } from "./useDeckStats.js"

function entry(overrides, qty = 1) {
  return { card: { type: "Unit", domains: ["Fury"], energy: 2, ...overrides }, qty }
}

describe("useDeckStats", () => {
  it("courbe d'énergie : seules les cartes du deck principal comptent, 7+ regroupé", () => {
    const cards = ref([
      entry({ id: "a", energy: 0 }, 2),
      entry({ id: "b", energy: 4 }, 4),
      entry({ id: "c", energy: 9 }, 1),
      entry({ id: "d", energy: null }, 1), // coût inconnu → panier 0
      entry({ id: "l", type: "Legend", energy: null }, 1),
      entry({ id: "r", type: "Rune", energy: null }, 12),
      entry({ id: "bf", type: "Battlefield", energy: null }, 1)
    ])
    const { curve } = useDeckStats(cards)

    expect(curve.value).toHaveLength(8)
    expect(curve.value.map((bucket) => bucket.count)).toEqual([3, 0, 0, 0, 4, 0, 0, 1])
    expect(curve.value[4]).toEqual({ cost: 4, count: 4, height: 100 })
    expect(curve.value[0].height).toBe(75)
  })

  it("courbe d'énergie : hauteurs à zéro sans division par zéro sur un deck vide", () => {
    const { curve, energyTotal } = useDeckStats(ref([]))
    expect(curve.value.every((bucket) => bucket.count === 0 && bucket.height === 0)).toBe(true)
    expect(energyTotal.value).toBe(0)
  })

  it("coût total : somme énergie × quantité du deck principal uniquement", () => {
    const cards = ref([
      entry({ id: "a", energy: 3 }, 2),
      entry({ id: "b", energy: null }, 5),
      entry({ id: "r", type: "Rune", energy: 4 }, 2)
    ])
    const { energyTotal } = useDeckStats(cards)
    expect(energyTotal.value).toBe(6)
  })

  it("répartition des domaines : Colorless exclu, tri du plus présent au moins présent", () => {
    const cards = ref([
      entry({ id: "a", domains: ["Fury", "Mind"] }, 2),
      entry({ id: "b", domains: ["Mind"] }, 3),
      entry({ id: "c", domains: ["Colorless"] }, 4)
    ])
    const { domainSpread } = useDeckStats(cards)
    expect(domainSpread.value).toEqual([
      ["Mind", 5],
      ["Fury", 2]
    ])
  })

  it("accepte un getter et suit les modifications du deck", () => {
    const deck = ref({ cards: [entry({ id: "a", energy: 2 }, 1)] })
    const { energyTotal } = useDeckStats(() => deck.value?.cards || [])
    expect(energyTotal.value).toBe(2)
    deck.value.cards.push(entry({ id: "b", energy: 5 }, 2))
    expect(energyTotal.value).toBe(12)
    deck.value = null
    expect(energyTotal.value).toBe(0)
  })
})
