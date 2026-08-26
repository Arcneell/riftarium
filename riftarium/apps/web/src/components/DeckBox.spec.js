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
  it("habille la boîte des couleurs des domaines de la légende", () => {
    const legend = { id: "l1", name: "Ahri", type: "Legend", domains: ["Fury", "Mind", "Colorless"], image_url: "u" }
    const wrapper = mountBox(fakeDeck({ cards: [{ card: legend, qty: 1 }] }))
    const style = wrapper.get(".deck-box").attributes("style")
    expect(style).toContain("--d1: var(--fury)")
    expect(style).toContain("--d2: var(--mind)") // Colorless ignoré
    wrapper.unmount()

    // Sans légende : repli sur l'or du site, jamais de variable vide.
    const plain = mountBox(fakeDeck())
    expect(plain.get(".deck-box").attributes("style")).toContain("--d1: var(--gold)")
    plain.unmount()
  })

  it("mentionne la valeur € du deck quand total_eur est présent", () => {
    const wrapper = mountBox(fakeDeck({ prices: { total_eur: 87.4, missing_eur: null } }))
    const price = wrapper.get(".deck-box-meta .price-tag")
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

  it("deck illégal : la raison est écrite sous la pastille, pas seulement dans l'infobulle", () => {
    /* Au doigt le :title ne s'ouvre jamais : « Illégal » sans raison n'apprend rien. */
    const failing = mountBox(fakeDeck({ checks: [{ rule: "legend", ok: false, message: "" }] }))
    expect(failing.get(".deck-legal-why").text()).toContain("ne respecte pas")
    failing.unmount()

    const ok = mountBox(fakeDeck({ checks: [{ rule: "legend", ok: true, message: "" }] }))
    expect(ok.find(".deck-legal-why").exists()).toBe(false)
    ok.unmount()
  })

  it("communauté : la pastille suit le booléen legal du listing", () => {
    const wrapper = mountBox(fakeDeck({ legal: false, checks: undefined }), { community: true })
    expect(wrapper.get(".deck-legal").classes()).toContain("ko")
    wrapper.unmount()
  })

  it("n'affiche plus le décompte de règles ni le format en texte", () => {
    const wrapper = mountBox(fakeDeck({ checks: [{ rule: "legend", ok: true, message: "" }] }))
    expect(wrapper.text()).not.toContain("règles")
    expect(wrapper.get(".deck-box-meta").text()).not.toContain("légal")
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
