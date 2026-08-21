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
    expect(wrapper.get(".deck-box-title").text()).toContain("Fureur d'Ahri")
    expect(wrapper.get(".deck-box-cover").attributes("href")).toBe("/decks/3")
    expect(wrapper.get(".deck-box-plate").text()).toContain("testeur")
    expect(wrapper.get(".deck-box-head").text()).toContain("12") // compteur de vues
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

  it("le filtre « constructibles » n'apparaît qu'aux connectés et pilote le paramètre buildable", async () => {
    let { wrapper } = await mountView()
    expect(wrapper.find(".buildable-filter").exists()).toBe(false)
    wrapper.unmount()

    session.token = "jeton"
    session.handle = "visiteur"
    ;({ wrapper } = await mountView())
    const toggle = wrapper.get(".buildable-filter")
    expect(toggle.text()).toContain("Constructibles avec ma collection")
    expect(toggle.attributes("aria-pressed")).toBe("false")

    api.mockClear()
    await toggle.trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("buildable=1"))).toBe(true)
    })
    expect(toggle.attributes("aria-pressed")).toBe("true")
    wrapper.unmount()
  })

  it("le filtre buildable est repris depuis l'URL", async () => {
    session.token = "jeton"
    const { wrapper, router } = await mountView("/communaute?buildable=1")
    expect(wrapper.get(".buildable-filter").attributes("aria-pressed")).toBe("true")
    expect(api.mock.calls.some(([path]) => String(path).includes("buildable=1"))).toBe(true)
    expect(router.currentRoute.value.query.buildable).toBe("1")
    wrapper.unmount()
  })

  it("connecté : chaque boîte indique Complet ✓ ou le nombre de manquantes et leur coût", async () => {
    session.token = "jeton"
    api.mockImplementation((path) => {
      if (path.startsWith("/api/community/decks")) {
        return Promise.resolve({
          total: 2,
          page: 1,
          size: 20,
          items: [
            { ...deck, missing_cards: 0, missing_cost_eur: null },
            { ...deck, id: 4, name: "Presque prêt", missing_cards: 3, missing_cost_eur: 4.5 }
          ]
        })
      }
      if (path === "/api/community/legends") return Promise.resolve([])
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    const boxes = wrapper.findAll(".deck-box")
    expect(boxes[0].get(".deck-buildable").text()).toContain("Complet ✓")
    expect(boxes[0].find(".deck-missing").exists()).toBe(false)
    expect(boxes[1].get(".deck-missing").text()).toContain("3 manquante(s) (~4,50")
    wrapper.unmount()
  })

  it("visiteur non connecté : aucune mention de manquantes sur les boîtes", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.find(".deck-buildable").exists()).toBe(false)
    expect(wrapper.find(".deck-missing").exists()).toBe(false)
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
