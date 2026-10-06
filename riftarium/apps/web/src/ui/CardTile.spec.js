import { mount, RouterLinkStub } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import CardTile from "./CardTile.vue"

const base = {
  id: "ogn-001",
  name: "Ahri",
  riftbound_id: "ogn-001-298",
  image_url: "https://cdn/x.png",
  domains: ["Mind"]
}
const mountTile = (card, props = {}) =>
  mount(CardTile, { props: { card, ...props }, global: { stubs: { RouterLink: RouterLinkStub } } })

describe("CardTile", () => {
  it("mène à la fiche, avec nom, code et accent du domaine", () => {
    const wrapper = mountTile(base)
    expect(wrapper.getComponent(RouterLinkStub).props("to")).toBe("/cartes/ogn-001")
    expect(wrapper.get(".tile-name").text()).toBe("Ahri")
    expect(wrapper.get(".tile-meta").text()).toContain("OGN-001-298")
    expect(wrapper.get(".rift-tile").attributes("style")).toContain("--tile-accent: var(--mind)")
    expect(wrapper.get("img").attributes("loading")).toBe("lazy")
  })

  it("l'image est décorative : le nom est déjà dans le lien", () => {
    expect(mountTile(base).get("img").attributes("alt")).toBe("")
  })

  it("foil, badge de variante, quantité et prix quand ils existent", () => {
    const wrapper = mountTile({ ...base, alternate_art: true, owned_qty: 2, price_eur: 12.4 })
    expect(wrapper.find(".tile-foil").exists()).toBe(true)
    expect(wrapper.get(".tile-badge").text()).toBe("Alt")
    expect(wrapper.get(".tile-owned").text()).toBe("×2")
    expect(wrapper.get(".tile-price").text()).toMatch(/12,40/)
  })

  it("rien de superflu pour une carte normale sans exemplaire ni prix", () => {
    const wrapper = mountTile(base)
    expect(wrapper.find(".tile-foil").exists()).toBe(false)
    expect(wrapper.find(".tile-badge").exists()).toBe(false)
    expect(wrapper.find(".tile-owned").exists()).toBe(false)
    expect(wrapper.find(".tile-price").exists()).toBe(false)
  })

  it("une carte paysage garde ses proportions", () => {
    expect(
      mountTile({ ...base, orientation: "landscape" })
        .get(".rift-tile")
        .classes()
    ).toContain("landscape")
  })
})

describe("CardTile slot overlay", () => {
  it("rend le slot overlay dans l'illustration", () => {
    const wrapper = mount(CardTile, {
      props: { card: base },
      slots: { overlay: '<b class="over">+</b>' },
      global: { stubs: { RouterLink: RouterLinkStub } }
    })
    expect(wrapper.get(".tile-art .over").exists()).toBe(true)
  })
})
