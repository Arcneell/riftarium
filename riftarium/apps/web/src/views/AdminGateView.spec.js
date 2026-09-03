import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import AdminGateView from "./AdminGateView.vue"
import { api, session } from "../api.js"
import { router as appRouter } from "../router.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

async function mountGate() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/admin", component: AdminGateView },
      { path: "/decks/:id", component: { template: "<div />" } }
    ]
  })
  router.push("/admin")
  await router.isReady()
  const wrapper = mount(AdminGateView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } }
  })
  /* Laisse l'import dynamique de la console se résoudre le cas échéant. */
  await vi.dynamicImportSettled()
  await flushPromises()
  return wrapper
}

describe("AdminGateView (/admin masqué)", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockResolvedValue(null)
    session.token = null
    session.handle = null
    session.isAdmin = null
  })

  it("un visiteur anonyme voit exactement la page 404, sans appel à l'API admin", async () => {
    const wrapper = await mountGate()
    expect(wrapper.text()).toContain("404")
    expect(wrapper.text()).toContain("Page introuvable")
    expect(wrapper.find(".admin-tabs").exists()).toBe(false)
    expect(api).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("un utilisateur connecté mais non admin voit la même 404, zéro indice", async () => {
    session.token = "1"
    session.handle = "nyra"
    session.isAdmin = false
    const wrapper = await mountGate()
    expect(wrapper.text()).toContain("404")
    expect(wrapper.text()).not.toContain("administration")
    expect(api).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("statut admin encore inconnu : ni console, ni 404 (pas de clignotement)", async () => {
    session.token = "1"
    session.handle = "nyra"
    session.isAdmin = null
    const wrapper = await mountGate()
    expect(wrapper.text()).not.toContain("404")
    expect(wrapper.find(".admin-tabs").exists()).toBe(false)
    expect(api).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("un admin voit la console, chargée en différé", async () => {
    session.token = "1"
    session.handle = "admin"
    session.isAdmin = true
    api.mockImplementation((path) => {
      if (path === "/api/admin/stats") {
        return Promise.resolve({
          users: { total: 1, new_7d: 0, new_30d: 0, suspended: 0, verified: 1 },
          decks: { total: 0, public: 0, pending: 0, likes_total: 0, views_total: 0 },
          collection: { entries_total: 0, cards_total: 0 },
          cards: { total: 0, sets: 0 },
          visits: {
            today_hits: 0,
            hits_7d: 0,
            hits_30d: 0,
            uniques_today: 0,
            uniques_7d: 0,
            daily: [],
            sections_7d: []
          },
          recent: { signups: [], decks: [] }
        })
      }
      return Promise.resolve(null)
    })
    const wrapper = await mountGate()
    await flushPromises()
    expect(wrapper.text()).toContain("Console d'administration")
    expect(wrapper.find(".admin-tabs").exists()).toBe(true)
    wrapper.unmount()
  })

  it("le routeur ne trahit pas /admin : pas de redirection vers la connexion ni l'accueil", async () => {
    session.token = null
    session.isAdmin = null
    await appRouter.push("/admin")
    expect(appRouter.currentRoute.value.path).toBe("/admin")
    /* Contrôle : une route protégée classique redirige toujours vers la connexion. */
    await appRouter.push("/collection")
    expect(appRouter.currentRoute.value.path).toBe("/connexion")
    expect(appRouter.currentRoute.value.query.suite).toBe("/collection")
  })
})
