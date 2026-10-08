import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import NotFoundView from "./NotFoundView.vue"
import { router as appRouter } from "../router.js"

describe("NotFoundView", () => {
  it("affiche un message en français et un lien de retour à l'accueil", async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: "/", component: { template: "<div />" } },
        { path: "/:pathMatch(.*)*", component: NotFoundView }
      ]
    })
    router.push("/page-inconnue")
    await router.isReady()
    const wrapper = mount(NotFoundView, { global: { plugins: [router] } })
    expect(wrapper.text()).toContain("Page introuvable")
    expect(wrapper.get("a").attributes("href")).toBe("/")
  })

  it("404 : lien accueil et lien cartes", async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: "/", component: { template: "<div />" } },
        { path: "/cartes", component: { template: "<div />" } }
      ]
    })
    router.push("/")
    await router.isReady()
    const wrapper = mount(NotFoundView, { global: { plugins: [router] } })
    expect(wrapper.get(".perdu-code").text()).toBe("404")
    expect(wrapper.get("h1").text()).toBe("Page introuvable")
    expect(wrapper.text()).toContain("Cette page n'existe pas ou a été déplacée.")
    const home = wrapper.findAll("a").find((a) => a.text() === "Retour à l'accueil")
    expect(home.attributes("href")).toBe("/")
    expect(home.classes()).toContain("rift-btn--primary")
    const cards = wrapper.findAll("a").find((a) => a.text() === "Chercher une carte")
    expect(cards.attributes("href")).toBe("/cartes")
  })

  it("le routeur envoie toute adresse inconnue vers la 404, non indexée", () => {
    const resolved = appRouter.resolve("/nimporte/quoi")
    expect(resolved.meta.noindex).toBe(true)
    expect(resolved.meta.title).toBe("Page introuvable")
  })
})
