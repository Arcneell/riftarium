import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import CardsView from "./CardsView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function fakeCard(index) {
  return {
    id: `card-${index}`,
    riftbound_id: `ogn-00${index}-298`,
    name: `Carte ${index}`,
    image_url: `https://cdn.example/${index}.png`,
    domains: ["Fury"],
    type: "Unit",
    rarity: "Epic"
  }
}

function viewport(width, height) {
  window.innerWidth = width
  window.innerHeight = height
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/cartes", component: CardsView },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  router.push("/cartes")
  await router.isReady()
  const wrapper = mount(CardsView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("CardsView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve([{ set_id: "OGN", name: "Origins" }])
      return Promise.resolve({ total: 300, page: 1, size: 30, items: [fakeCard(1), fakeCard(2)] })
    })
  })

  afterEach(() => {
    viewport(1024, 768)
  })

  it("propose les raretés officielles dans l'ordre du jeu", async () => {
    const { wrapper } = await mountView()
    await wrapper.findAll(".fsel-btn")[2].trigger("click")
    expect(wrapper.findAll(".fsel-opt").map((button) => button.text().trim())).toEqual([
      "Commun",
      "Peu commun",
      "Rare",
      "Épique",
      "Showcase",
      "Promo"
    ])
    wrapper.unmount()
  })

  it("propose des filtres repliés plutôt qu'une longue liste de chips", async () => {
    const { wrapper } = await mountView()
    const labels = wrapper.findAll(".fsel-btn").map((button) => button.text().trim())
    expect(labels).toEqual(["Domaines", "Types", "Raretés", "Coût", "Sets"])
    expect(wrapper.findAll(".fsel-pop")).toHaveLength(0)
    wrapper.unmount()
  })

  it("affiche les runes officielles dans le filtre des domaines", async () => {
    const { wrapper } = await mountView()
    await wrapper.findAll(".fsel-btn")[0].trigger("click")
    const runes = wrapper.findAll(".fsel-opt img.rb-glyph.rune")
    expect(runes).toHaveLength(6)
    expect(runes[0].attributes("src")).toContain("rune_fury.svg")
    expect(wrapper.find(".fsel-opt .fsel-tick").exists()).toBe(false)
    wrapper.unmount()
  })

  it("charge plus de cartes sur un grand écran que sur mobile", async () => {
    const requestedSize = () => {
      const call = api.mock.calls.map(([path]) => path).findLast((path) => path.startsWith("/api/cards"))
      return Number(new URL(call, "http://x").searchParams.get("size"))
    }

    viewport(1920, 1200)
    const { wrapper: large } = await mountView()
    const largeSize = requestedSize()
    large.unmount()

    api.mockClear()
    viewport(390, 780)
    const { wrapper: small } = await mountView()
    const smallSize = requestedSize()
    small.unmount()

    expect(largeSize).toBeGreaterThan(smallSize)
    expect(smallSize).toBeGreaterThanOrEqual(8)
  })

  it("répercute les filtres choisis dans l'URL et dans la requête", async () => {
    const { wrapper, router } = await mountView()
    await wrapper.findAll(".fsel-btn")[0].trigger("click")
    await wrapper.get(".fsel-opt").trigger("click")
    await flushPromises()
    await vi.waitFor(() => expect(router.currentRoute.value.query.domain).toBe("Fury"))
    await vi.waitFor(() => expect(api.mock.calls.at(-1)[0]).toContain("domain=Fury"))
    wrapper.unmount()
  })
})
