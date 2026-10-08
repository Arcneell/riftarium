import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import AccessLayout from "./AccessLayout.vue"

describe("AccessLayout", () => {
  it("porte le titre dans le h1 et le contenu dans le panneau", () => {
    const wrapper = mount(AccessLayout, {
      props: { title: "Connexion" },
      slots: { default: "<p class='contenu'>Bonjour</p>" }
    })
    expect(wrapper.get("h1").text()).toBe("Connexion")
    expect(wrapper.get(".acces-panel .contenu").text()).toBe("Bonjour")
  })

  it("affiche le surtitre quand il est fourni", () => {
    const wrapper = mount(AccessLayout, { props: { title: "Connexion", kicker: "Compte" } })
    expect(wrapper.get(".acces-kicker").text()).toBe("Compte")
    expect(
      mount(AccessLayout, { props: { title: "x" } })
        .find(".acces-kicker")
        .exists()
    ).toBe(false)
  })

  it("pose l'illustration du splash en fond décoratif", () => {
    const wrapper = mount(AccessLayout, { props: { title: "Connexion" } })
    const art = wrapper.get("img.acces-art")
    expect(art.attributes("alt")).toBe("")
    expect(art.attributes("src")).toBeTruthy()
  })

  it("crédite l'illustration officielle et la charge en priorité", () => {
    const wrapper = mount(AccessLayout, { props: { title: "Connexion" } })
    expect(wrapper.get(".acces-credit").text()).toBe("Visuel officiel Riftbound — © Riot Games")
    expect(wrapper.get("img.acces-art").attributes("fetchpriority")).toBe("high")
  })
})
