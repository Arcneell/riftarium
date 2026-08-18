import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import DeckVisual from "./DeckVisual.vue"

const deck = {
  cards: [
    {
      qty: 1,
      card: {
        id: "l1",
        name: "Daughter of the Void",
        type: "Legend",
        tags: ["Ahri"],
        image_url: "https://cdn.example/l.png"
      }
    },
    {
      qty: 1,
      card: {
        id: "u1",
        name: "Ahri, Inquisitive",
        type: "Unit",
        supertype: "Champion",
        tags: ["Ahri"],
        image_url: "https://cdn.example/u.png"
      }
    },
    {
      qty: 3,
      card: { id: "s1", name: "Charm", type: "Spell", image_url: "https://cdn.example/s.png" }
    }
  ]
}

describe("DeckVisual", () => {
  it("affiche les zones, les noms et le champion", () => {
    const wrapper = mount(DeckVisual, {
      props: { deck },
      global: { stubs: { CardHoverPreview: { template: "<div><slot /></div>" } } }
    })
    expect(wrapper.find(".dvis-identity").exists()).toBe(true)
    expect(wrapper.text()).toContain("Légende")
    expect(wrapper.text()).toContain("Deck principal")
    expect(wrapper.text()).toContain("Daughter of the Void")
    expect(wrapper.text()).toContain("Charm")
    expect(wrapper.findAll(".dvis-card")).toHaveLength(3)
    expect(wrapper.get(".dvis-cell.champion").text()).toContain("Ahri, Inquisitive")
    expect(wrapper.findAll(".dvis-qty").some((node) => node.text() === "×3")).toBe(true)
  })
})
