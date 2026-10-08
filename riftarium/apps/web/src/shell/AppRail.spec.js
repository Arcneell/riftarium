import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AppRail from "./AppRail.vue"

async function mountRail(path, props = {}) {
  const router = await makeRouter(path)
  return mount(AppRail, { props, global: { plugins: [router], components: { Icon } } })
}

describe("AppRail", () => {
  afterEach(() => {
    Object.assign(session, { token: null, handle: null })
  })

  it("liste les six rubriques et marque la rubrique et la sous-page actives", async () => {
    const wrapper = await mountRail("/wishlist")
    const items = wrapper.findAll(".rail-item")
    expect(items.map((item) => item.text())).toEqual(["Accueil", "Cartes", "Decks", "Collection", "Règles", "Jouer"])
    expect(wrapper.get(".rail-item.active").text()).toBe("Collection")
    expect(wrapper.get(".rail-item.active").attributes("aria-current")).toBe("true")
    expect(wrapper.get(".rail-sub a[aria-current=page]").text()).toBe("Wishlist")
  })

  it("ne déplie que les sous-pages de la rubrique active", async () => {
    const wrapper = await mountRail("/cartes")
    expect(wrapper.find(".rail-sub").exists()).toBe(false)
    expect(wrapper.get(".rail-item.active").attributes("aria-current")).toBe("page")
  })

  it("replié : masque les libellés, garde les infobulles, émet toggle", async () => {
    const wrapper = await mountRail("/decks", { collapsed: true })
    expect(wrapper.find(".rail-label").exists()).toBe(false)
    expect(wrapper.find(".rail-sub").exists()).toBe(false)
    expect(wrapper.get(".rail-item.active").attributes("title")).toBe("Decks")
    await wrapper.get(".rail-collapse").trigger("click")
    expect(wrapper.emitted("toggle")).toHaveLength(1)
    expect(wrapper.get(".rail-collapse").attributes("aria-label")).toBe("Déplier le menu")
  })

  it("propose la connexion à un visiteur, le menu du compte à un membre", async () => {
    let wrapper = await mountRail("/")
    expect(wrapper.text()).toContain("Connexion")
    Object.assign(session, { token: "1", handle: "Kaelis" })
    wrapper = await mountRail("/")
    expect(wrapper.find(".account-btn").exists()).toBe(true)
  })
})
