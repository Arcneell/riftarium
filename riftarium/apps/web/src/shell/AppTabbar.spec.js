import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AppTabbar from "./AppTabbar.vue"

describe("AppTabbar", () => {
  it("cinq onglets, Accueil compris, et l'onglet de la rubrique courante actif", async () => {
    const router = await makeRouter("/communaute")
    const wrapper = mount(AppTabbar, { global: { plugins: [router], components: { Icon } } })
    expect(wrapper.findAll(".tab").map((tab) => tab.text())).toEqual([
      "Accueil",
      "Cartes",
      "Decks",
      "Collection",
      "Règles"
    ])
    expect(wrapper.get(".tab[aria-current=page]").text()).toBe("Decks")
  })

  it("aucun onglet actif sur une page hors rubrique", async () => {
    const router = await makeRouter("/profil")
    const wrapper = mount(AppTabbar, { global: { plugins: [router], components: { Icon } } })
    expect(wrapper.find(".tab[aria-current=page]").exists()).toBe(false)
  })
})
