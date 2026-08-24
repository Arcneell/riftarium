import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import PageBanner from "./PageBanner.vue"
import { BANNERS } from "../banners.js"

describe("PageBanner", () => {
  it("applique l'illustration officielle et crédite Riot", () => {
    const wrapper = mount(PageBanner, {
      props: { art: BANNERS.cards, eyebrow: "Cartothèque", title: "Toutes les cartes du jeu" }
    })
    expect(wrapper.get(".page-banner").attributes("style")).toContain(BANNERS.cards)
    expect(wrapper.get(".splash-credit").text()).toContain("© Riot Games")
    expect(wrapper.get(".eyebrow").text()).toBe("Cartothèque")
  })

  it("garde le titre pour les lecteurs d'écran mais le sort de la mise en page", () => {
    const wrapper = mount(PageBanner, {
      props: { art: BANNERS.cards, title: "Toutes les cartes du jeu" }
    })
    const heading = wrapper.get("h2")
    expect(heading.text()).toBe("Toutes les cartes du jeu")
    expect(heading.classes()).toContain("sr-only")
  })

  it("affiche le titre quand la page le demande explicitement", () => {
    const wrapper = mount(PageBanner, {
      props: { art: BANNERS.rules, title: "Conquête", showTitle: true }
    })
    expect(wrapper.get("h2").classes()).not.toContain("sr-only")
    expect(wrapper.get(".page-banner").classes()).toContain("has-title")
  })
})
