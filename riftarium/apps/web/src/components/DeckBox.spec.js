import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import DeckBox from "./DeckBox.vue"

function fakeDeck(extras = {}) {
  return {
    id: 1,
    name: "Deck de la Faille",
    format: "tournament",
    card_count: 56,
    likes: 3,
    is_public: true,
    cards: [],
    checks: null,
    ...extras
  }
}

function mountBox(deck) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: "/decks/:id", component: { template: "<div />" } }]
  })
  return mount(DeckBox, {
    props: { deck, to: "/decks/1" },
    global: { plugins: [router], stubs: { Icon: true } }
  })
}

describe("DeckBox", () => {
  it("mentionne la valeur € du deck quand total_eur est présent", () => {
    const wrapper = mountBox(fakeDeck({ prices: { total_eur: 87.4, missing_eur: null } }))
    const price = wrapper.get(".deck-box-plate .price-tag")
    expect(price.text()).toContain("87,40")
    expect(price.attributes("title")).toContain("TCGplayer")
    wrapper.unmount()
  })

  it("reste muet sans prix agrégé (prices absent ou total null)", () => {
    for (const deck of [fakeDeck(), fakeDeck({ prices: null }), fakeDeck({ prices: { total_eur: null } })]) {
      const wrapper = mountBox(deck)
      expect(wrapper.find(".price-tag").exists()).toBe(false)
      expect(wrapper.text()).toContain("56 cartes")
      wrapper.unmount()
    }
  })
})
