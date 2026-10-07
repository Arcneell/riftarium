import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import DeckStatsPanel from "./DeckStatsPanel.vue"

const CARDS = [
  { qty: 3, card: { id: "u1", name: "Garen", type: "Unit", energy: 2, domains: ["Fury"] } },
  { qty: 2, card: { id: "s1", name: "Charm", type: "Spell", energy: 9, domains: ["Fury", "Mind"] } }
]

function mountPanel(props = {}, slots = {}) {
  return mount(DeckStatsPanel, { props: { cards: CARDS, checks: [], ...props }, slots })
}

describe("DeckStatsPanel", () => {
  it("courbe : barres et sr-only, hauteur 0 % quand le deck est vide", () => {
    const wrapper = mountPanel()
    const bars = wrapper.findAll(".analyse-bar")
    expect(bars).toHaveLength(8)
    expect(bars[2].find(".sr-only").text()).toBe("3 carte(s) à 2 d'énergie")
    expect(bars[7].find(".sr-only").text()).toBe("2 carte(s) à 7 d'énergie")
    expect(bars[7].get(".analyse-bar-cost").text()).toBe("7+")
    expect(bars[2].get(".analyse-bar-fill").attributes("style")).toContain("height: 100%")
    expect(wrapper.get(".analyse-curve").attributes("aria-label")).toBe(
      "Répartition des coûts en énergie du deck principal"
    )

    const empty = mountPanel({ cards: [] })
    for (const fill of empty.findAll(".analyse-bar-fill")) {
      expect(fill.attributes("style")).toContain("height: 0%")
      expect(fill.attributes("style")).not.toContain("NaN")
    }
  })

  it("règles ✓/✕ avec texte", () => {
    const wrapper = mountPanel({
      checks: [
        { rule: "a", ok: true, message: "40 cartes minimum" },
        { rule: "b", ok: false, message: "Il manque une légende" }
      ]
    })
    const items = wrapper.findAll(".analyse-checks li")
    expect(items).toHaveLength(2)
    expect(items[0].classes()).toContain("ok")
    expect(items[0].get("[aria-hidden]").text()).toBe("✓")
    expect(items[0].text()).toContain("40 cartes minimum")
    expect(items[1].classes()).toContain("ko")
    expect(items[1].get("[aria-hidden]").text()).toBe("✕")
    expect(items[1].text()).toContain("Il manque une légende")
  })

  it("valeur absente sans prix", () => {
    expect(mountPanel().text()).not.toContain("Valeur")
    expect(mountPanel({ prices: { total_eur: null } }).text()).not.toContain("Valeur")
    expect(mountPanel({ prices: { total_eur: 12.5 } }).text()).toContain("Valeur")
  })

  it("slot actions rendu", () => {
    const wrapper = mountPanel({}, { actions: '<button class="test-action">Trouver</button>' })
    expect(wrapper.get(".test-action").text()).toBe("Trouver")
  })
})
