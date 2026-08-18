import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CommunityView from "./CommunityView.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const deck = {
  id: 3,
  name: "Fureur d'Ahri",
  owner: "testeur",
  format: "tournament",
  likes: 4,
  liked_by_me: false,
  views: 12,
  card_count: 56,
  legend: {
    id: "ogn-247-298",
    name: "Daughter of the Void",
    type: "Legend",
    domains: ["Fury", "Mind"],
    image_url: "https://cdn.example/legend.png"
  }
}

async function mountView(path = "/communaute") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/communaute", component: CommunityView },
      { path: "/decks", component: { template: "<div />" } },
      { path: "/decks/:id", component: { template: "<div />" } },
      { path: "/connexion", component: { template: "<div />" } }
    ]
  })
  router.push(path)
  await router.isReady()
  const wrapper = mount(CommunityView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("CommunityView", () => {
  beforeEach(() => {
    session.token = null
    session.handle = null
    api.mockReset()
    api.mockImplementation((path) => {
      if (path.startsWith("/api/community/decks")) {
        return Promise.resolve({ total: 1, page: 1, size: 20, items: [{ ...deck }] })
      }
      if (path === "/api/community/legends") {
        return Promise.resolve([{ id: "ogn-247-298", name: "Daughter of the Void", deck_count: 1 }])
      }
      return Promise.resolve(null)
    })
  })

  it("affiche les decks en boîtes comme la page Mes decks", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.findAll(".deck-box")).toHaveLength(1)
    expect(wrapper.get(".deck-box-plate h3").text()).toContain("Fureur d'Ahri")
    expect(wrapper.get(".deck-box-cover").attributes("href")).toBe("/decks/3")
    expect(wrapper.text()).toContain("par testeur")
    expect(wrapper.text()).toContain("12")
    wrapper.unmount()
  })

  it("envoie le visiteur non connecté vers la connexion pour aimer", async () => {
    const { wrapper, router } = await mountView()
    await wrapper.get('[aria-label="Aimer ce deck"]').trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/connexion")
    expect(api.mock.calls.some(([, options]) => options?.method === "POST")).toBe(false)
    wrapper.unmount()
  })

  it("aime un deck quand on est connecté", async () => {
    session.token = "jeton"
    session.handle = "visiteur"
    api.mockImplementation((path, options = {}) => {
      if (path.startsWith("/api/community/decks")) {
        return Promise.resolve({ total: 1, page: 1, size: 20, items: [{ ...deck }] })
      }
      if (path === "/api/community/legends") return Promise.resolve([])
      if (path === "/api/decks/3/like" && options.method === "POST") {
        return Promise.resolve({ likes: 5, liked_by_me: true })
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    await wrapper.get("button.deck-box-stat").trigger("click")
    await flushPromises()
    expect(wrapper.get("button.deck-box-stat.liked").text()).toContain("5")
    wrapper.unmount()
  })

  it("synchronise le tri dans l'URL", async () => {
    const { wrapper, router } = await mountView()
    const views = wrapper.findAll(".owned-seg button")[1]
    await views.trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.query.sort).toBe("views")
    await vi.waitFor(() => expect(api.mock.calls.some(([path]) => path.includes("sort=views"))).toBe(true))
    wrapper.unmount()
  })
})
