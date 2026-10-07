import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
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

function mountVisual() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  return mount(DeckVisual, {
    props: { deck },
    global: { plugins: [router], stubs: { CardHoverPreview: { template: "<div><slot /></div>" } } }
  })
}

describe("DeckVisual", () => {
  it("affiche les zones, les noms et le champion", () => {
    const wrapper = mountVisual()
    expect(wrapper.find(".lecture-zone-identity").exists()).toBe(true)
    expect(wrapper.text()).toContain("Légende")
    expect(wrapper.text()).toContain("Deck principal")
    expect(wrapper.text()).toContain("Daughter of the Void")
    expect(wrapper.text()).toContain("Charm")
    expect(wrapper.findAll(".lecture-card")).toHaveLength(3)
    expect(wrapper.get(".lecture-card-cell--champion").text()).toContain("Ahri, Inquisitive")
    expect(wrapper.findAll(".lecture-card-qty").some((node) => node.text() === "×3")).toBe(true)
  })

  it("chaque vignette est un lien vers la fiche de la carte", () => {
    /* L'aperçu au survol n'existe pas au doigt : sans lien, impossible de lire la carte. */
    const wrapper = mountVisual()
    const links = wrapper.findAll(".lecture-card-link")
    expect(links).toHaveLength(3)
    expect(links.map((link) => link.attributes("href"))).toEqual(["/cartes/l1", "/cartes/u1", "/cartes/s1"])
    expect(links[1].attributes("aria-label")).toBe("Voir la carte Ahri, Inquisitive")
    expect(links[0].find(".lecture-card").exists()).toBe(true)
  })
})
