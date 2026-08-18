import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import PageBanner from "./PageBanner.vue"
import { BANNERS } from "../banners.js"

describe("PageBanner", () => {
  it("applique l'illustration officielle et crédite Riot", () => {
    const wrapper = mount(PageBanner, {
      props: { art: BANNERS.cards, eyebrow: "Cartothèque", title: "Toutes les cartes du jeu" },
      slots: { default: "Cumulez les filtres." }
    })
    expect(wrapper.get(".page-banner").attributes("style")).toContain(BANNERS.cards)
    expect(wrapper.get(".splash-credit").text()).toContain("© Riot Games")
    expect(wrapper.text()).toContain("Toutes les cartes du jeu")
    expect(wrapper.text()).toContain("Cumulez les filtres.")
  })
})
