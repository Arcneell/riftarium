import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import HomeView from "./HomeView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

/* Les trois cartes Signature de l'éventail du héros. */
const SIGNATURES = [
  "e5fe571a8f09c0a9e76345ec32b446480f54617c-1488x2078.png",
  "b4dfd543b1cfcdefba4568fe78146e0d6e46add7-1488x2078.png",
  "ae8e68af43400f61f7391c0a6ee339fd718a7540-1488x2078.png"
]

function mountHome() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: HomeView },
      { path: "/cartes", component: { template: "<div />" } },
      { path: "/regles", component: { template: "<div />" } },
      { path: "/decks", component: { template: "<div />" } },
      { path: "/collection", component: { template: "<div />" } },
      { path: "/communaute", component: { template: "<div />" } }
    ]
  })
  return mount(HomeView, {
    global: {
      plugins: [router],
      stubs: {
        CardRiver: { template: '<div class="river-stub" />' },
        Icon: true
      },
      directives: { tilt: {}, reveal: {} }
    }
  })
}

describe("HomeView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve([{ set_id: "OGN" }, { set_id: "SFD" }])
      if (path === "/api/cards?size=1") return Promise.resolve({ total: 1315, items: [] })
      return Promise.resolve({})
    })
  })

  it("affiche trois cartes Overnumbered avec le reflet foil, sans signature ajoutée", async () => {
    const wrapper = mountHome()
    await flushPromises()

    const fan = wrapper.get(".hero-fan")
    expect(fan.attributes("aria-hidden")).toBe("true")
    expect(wrapper.findAll(".fan-card")).toHaveLength(3)
    expect(wrapper.findAll(".fan-foil")).toHaveLength(3)
    expect(wrapper.find(".signed-card").exists()).toBe(false)
    expect(wrapper.find(".sc-serial").exists()).toBe(false)
    expect(wrapper.find(".sc-sign").exists()).toBe(false)
    expect(wrapper.text()).not.toMatch(/Nº\s*\d+\s*\/\s*\d+/)
    /* La bêta fermée n'est pas annoncée sur l'accueil (badge d'en-tête + mentions légales seulement). */
    expect(wrapper.text()).not.toContain("Bêta fermée")

    const sources = wrapper.findAll(".fan-card img").map((img) => img.attributes("src"))
    for (const hash of SIGNATURES) {
      expect(sources.some((src) => src.includes(hash) && src.includes("w=460"))).toBe(true)
    }
  })
})
