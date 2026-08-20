import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import CardTile from "./CardTile.vue"

function sampleCard(extras = {}) {
  return {
    id: "ogn-037a-298",
    riftbound_id: "ogn-037a-298",
    name: "Immortal Phoenix (Alternate Art)",
    image_url: "https://cdn.example/phoenix.png",
    domains: ["Fury"],
    type: "Unit",
    rarity: "Showcase",
    alternate_art: true,
    owned_qty: 3,
    ...extras
  }
}

function mountTile(card) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: "/cartes/:id", component: { template: "<div />" } }]
  })
  return mount(CardTile, {
    props: { card },
    global: {
      plugins: [router],
      directives: { tilt: {} }
    }
  })
}

describe("CardTile", () => {
  it("affiche le foil, le badge Alt et la quantité en collection", () => {
    const wrapper = mountTile(sampleCard())
    expect(wrapper.find(".card-foil").exists()).toBe(true)
    expect(wrapper.get(".card-badge").text()).toBe("Alt")
    expect(wrapper.get(".card-qty").text()).toBe("×3")
    expect(wrapper.get("a.card-tile").attributes("href")).toBe("/cartes/ogn-037a-298")
    wrapper.unmount()
  })

  it("n'ajoute ni foil ni badge sur une carte normale sans exemplaire", () => {
    const wrapper = mountTile(
      sampleCard({
        id: "ogn-037-298",
        riftbound_id: "ogn-037-298",
        name: "Immortal Phoenix",
        rarity: "Epic",
        alternate_art: false,
        owned_qty: 0
      })
    )
    expect(wrapper.find(".card-foil").exists()).toBe(false)
    expect(wrapper.find(".card-badge").exists()).toBe(false)
    expect(wrapper.find(".card-qty").exists()).toBe(false)
    wrapper.unmount()
  })

  it("badge prix discret dans la zone méta quand la carte est pricée, rien sinon", () => {
    const priced = mountTile(sampleCard({ price_eur: 13.3 }))
    const badge = priced.get(".t-meta .price-tag")
    expect(badge.text()).toContain("13,30")
    expect(badge.attributes("title")).toContain("TCGplayer")
    // jamais sur l'illustration : le badge vit sous la carte, pas dans .card-art
    expect(priced.find(".card-art .price-tag").exists()).toBe(false)
    priced.unmount()

    const unpriced = mountTile(sampleCard({ price_eur: null }))
    expect(unpriced.find(".price-tag").exists()).toBe(false)
    unpriced.unmount()
  })

  it("montre un terrain en entier, sans le forcer en portrait", () => {
    const wrapper = mountTile(
      sampleCard({
        id: "ogn-275-298",
        riftbound_id: "ogn-275-298",
        name: "Altar to Unity",
        type: "Battlefield",
        rarity: "Uncommon",
        orientation: "landscape",
        alternate_art: false,
        owned_qty: 0
      })
    )
    expect(wrapper.get("a.card-tile").classes()).toContain("landscape")
    expect(wrapper.get(".card-hover").classes()).toContain("landscape")
    expect(wrapper.get("img").attributes("width")).toBeUndefined()
    expect(wrapper.get("img").attributes("height")).toBeUndefined()
    wrapper.unmount()
  })
})
