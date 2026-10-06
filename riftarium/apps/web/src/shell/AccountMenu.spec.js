import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AccountMenu from "./AccountMenu.vue"

async function mountMenu() {
  const router = await makeRouter("/cartes")
  const wrapper = mount(AccountMenu, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
  return { wrapper, router }
}

describe("AccountMenu", () => {
  beforeEach(() => {
    Object.assign(session, { token: "1", handle: "Kaelis", avatarUrl: null, isAdmin: false })
    globalThis.fetch = vi.fn(async () => ({ ok: true, status: 204, json: async () => ({}) }))
  })
  afterEach(() => {
    Object.assign(session, { token: null, handle: null, isAdmin: null })
    document.body.innerHTML = ""
  })

  it("déroule Profil, Amis et Déconnexion ; Administration seulement pour un admin", async () => {
    const { wrapper } = await mountMenu()
    await wrapper.get(".account-btn").trigger("click")
    expect(wrapper.findAll("[role=menuitem]").map((item) => item.text())).toEqual(["Profil", "Amis", "Déconnexion"])
    session.isAdmin = true
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain("Administration")
    wrapper.unmount()
  })

  it("se ferme sur Échap et au clic à l'extérieur", async () => {
    const { wrapper } = await mountMenu()
    await wrapper.get(".account-btn").trigger("click")
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    await wrapper.vm.$nextTick()
    expect(wrapper.find("[role=menu]").exists()).toBe(false)
    await wrapper.get(".account-btn").trigger("click")
    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }))
    await wrapper.vm.$nextTick()
    expect(wrapper.find("[role=menu]").exists()).toBe(false)
    wrapper.unmount()
  })

  it("la déconnexion ferme la session et revient à l'accueil", async () => {
    const { wrapper, router } = await mountMenu()
    await wrapper.get(".account-btn").trigger("click")
    await wrapper.findAll("[role=menuitem]").at(-1).trigger("click")
    await flushPromises()
    expect(globalThis.fetch).toHaveBeenCalledWith("/api/auth/logout", expect.objectContaining({ method: "POST" }))
    expect(session.token).toBeNull()
    expect(router.currentRoute.value.path).toBe("/")
    wrapper.unmount()
  })
})
