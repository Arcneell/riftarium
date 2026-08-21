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

function mountBox(deck, props = {}) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: "/decks/:id", component: { template: "<div />" } }]
  })
  return mount(DeckBox, {
    props: { deck, to: "/decks/1", ...props },
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

  it("affiche la pastille Légal quand toutes les règles passent", () => {
    const wrapper = mountBox(fakeDeck({ checks: [{ rule: "legend", ok: true, message: "" }] }))
    const badge = wrapper.get(".deck-legal")
    expect(badge.text()).toContain("Légal")
    expect(badge.classes()).toContain("ok")
    wrapper.unmount()
  })

  it("passe la pastille en Illégal si une règle échoue ou si le format est libre", () => {
    const failing = mountBox(fakeDeck({ checks: [{ rule: "legend", ok: false, message: "" }] }))
    expect(failing.get(".deck-legal").classes()).toContain("ko")
    expect(failing.get(".deck-legal").text()).toContain("Illégal")
    failing.unmount()

    const free = mountBox(fakeDeck({ format: "free", checks: [{ rule: "legend", ok: true, message: "" }] }))
    expect(free.get(".deck-legal").classes()).toContain("ko")
    free.unmount()
  })

  it("communauté : la pastille suit le booléen legal du listing", () => {
    const wrapper = mountBox(fakeDeck({ legal: false, checks: undefined }), { community: true })
    expect(wrapper.get(".deck-legal").classes()).toContain("ko")
    wrapper.unmount()
  })

  it("n'affiche plus le décompte de règles ni le format en texte", () => {
    const wrapper = mountBox(fakeDeck({ checks: [{ rule: "legend", ok: true, message: "" }] }))
    expect(wrapper.text()).not.toContain("règles")
    expect(wrapper.get(".deck-box-plate .mono").text()).not.toContain("légal")
    expect(wrapper.text()).toContain("public")
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
