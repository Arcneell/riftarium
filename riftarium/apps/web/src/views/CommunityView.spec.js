import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
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

const originalMatchMedia = window.matchMedia
/* Simule la largeur d'écran : useBreakpoint lit les requêtes max-width. */
function stubWidth(px) {
  window.matchMedia = (query) => ({
    matches: px <= Number(query.match(/max-width:\s*(\d+)px/)?.[1] ?? 0),
    addEventListener() {},
    removeEventListener() {}
  })
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
    global: { plugins: [router], stubs: { Icon: true } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

const facet = (wrapper, legend) => wrapper.findAll("fieldset").find((node) => node.get("legend").text() === legend)
const buildableChip = (wrapper) =>
  wrapper.findAll("button.rift-chip").find((b) => b.text() === "Constructibles avec ma collection")

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

  afterEach(() => {
    window.matchMedia = originalMatchMedia
    document.body.innerHTML = ""
  })

  it("affiche les decks en fiches comme la page Mes decks", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.findAll(".deck-card")).toHaveLength(1)
    expect(wrapper.get(".deck-card-title").text()).toContain("Fureur d'Ahri")
    expect(wrapper.get("a.deck-card-link").attributes("href")).toBe("/decks/3")
    expect(wrapper.get(".deck-card-meta").text()).toContain("testeur")
    expect(wrapper.get(".deck-card-foot").text()).toContain("12") // compteur de vues
    expect(wrapper.get(".communaute-count").text()).toBe("1 deck(s)")
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
    await wrapper.get("button.deck-card-like").trigger("click")
    await flushPromises()
    expect(wrapper.get("button.deck-card-like.deck-card-like--on").text()).toContain("5")
    wrapper.unmount()
  })

  it("double clic sur j'aime : un seul POST", async () => {
    session.token = "jeton"
    let release
    api.mockImplementation((path, options = {}) => {
      if (path.startsWith("/api/community/decks")) {
        return Promise.resolve({ total: 1, page: 1, size: 20, items: [{ ...deck }] })
      }
      if (path === "/api/community/legends") return Promise.resolve([])
      if (path === "/api/decks/3/like" && options.method === "POST") {
        return new Promise((resolve) => {
          release = () => resolve({ likes: 5, liked_by_me: true })
        })
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    const like = wrapper.get("button.deck-card-like")
    await like.trigger("click")
    await like.trigger("click")
    release()
    await flushPromises()
    expect(api.mock.calls.filter(([, options]) => options?.method === "POST")).toHaveLength(1)
    wrapper.unmount()
  })

  it("le filtre « constructibles » n'apparaît qu'aux connectés et pilote le paramètre buildable", async () => {
    let { wrapper } = await mountView()
    expect(buildableChip(wrapper)).toBeUndefined()
    wrapper.unmount()

    session.token = "jeton"
    session.handle = "visiteur"
    ;({ wrapper } = await mountView())
    const toggle = buildableChip(wrapper)
    expect(toggle.text()).toContain("Constructibles avec ma collection")
    expect(toggle.attributes("aria-pressed")).toBe("false")

    api.mockClear()
    await toggle.trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("buildable=1"))).toBe(true)
    })
    expect(buildableChip(wrapper).attributes("aria-pressed")).toBe("true")
    wrapper.unmount()
  })

  it("le filtre buildable est repris depuis l'URL", async () => {
    session.token = "jeton"
    const { wrapper, router } = await mountView("/communaute?buildable=1")
    expect(buildableChip(wrapper).attributes("aria-pressed")).toBe("true")
    expect(api.mock.calls.some(([path]) => String(path).includes("buildable=1"))).toBe(true)
    expect(router.currentRoute.value.query.buildable).toBe("1")
    wrapper.unmount()
  })

  it("connecté : chaque fiche indique Complet ou le nombre de manquantes et leur coût", async () => {
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
    const cards = wrapper.findAll(".deck-card")
    expect(cards[0].get(".deck-card-complete").text()).toContain("Complet")
    expect(cards[0].find(".deck-card-missing").exists()).toBe(false)
    expect(cards[1].get(".deck-card-missing").text()).toContain("3 manquante(s) (~4,50")
    wrapper.unmount()
  })

  it("visiteur non connecté : aucune mention de manquantes sur les fiches", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.find(".deck-card-complete").exists()).toBe(false)
    expect(wrapper.find(".deck-card-missing").exists()).toBe(false)
    wrapper.unmount()
  })

  it("synchronise le tri dans l'URL", async () => {
    const { wrapper, router } = await mountView()
    const views = wrapper.findAll('[role="radiogroup"] [role="radio"]')[1]
    await views.trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.query.sort).toBe("views")
    await vi.waitFor(() => expect(api.mock.calls.some(([path]) => path.includes("sort=views"))).toBe(true))
    wrapper.unmount()
  })

  it("visiteur : la puce Aimés mène à la connexion", async () => {
    const { wrapper, router } = await mountView()
    await facet(wrapper, "Mes decks aimés").get("button.rift-chip").trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/connexion")
    wrapper.unmount()
  })

  it("sur téléphone, les filtres s'ouvrent dans une feuille", async () => {
    stubWidth(390)
    const { wrapper } = await mountView("/communaute?format=free")
    expect(wrapper.find(".communaute-filters").exists()).toBe(false)
    const open = wrapper.findAll("button").find((button) => button.text().startsWith("Filtres"))
    expect(open.text().replace(/\s+/g, " ")).toBe("Filtres (1)")
    await open.trigger("click")
    const sheet = document.body.querySelector(".rift-sheet")
    expect(sheet).not.toBeNull()
    expect(sheet.textContent).toContain("Légendes")
    const done = [...sheet.querySelectorAll("button")].find((b) => b.textContent.trim() === "Voir le deck")
    done.click()
    await flushPromises()
    expect(document.body.querySelector(".rift-sheet")).toBeNull()
    wrapper.unmount()
  })
})
