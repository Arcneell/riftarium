import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import HomeView from "./HomeView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const OVERNUMBERED = [
  "8a7dbbed04133926e58843f1d586f51178ef2ebd-1488x2078.png",
  "dc89c6a2415debd5bf504ed46843f5dcc1d9b815-1488x2078.png",
  "2c804ec513085702763a9145fac93a8adb6c4783-1488x2078.png"
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

    const sources = wrapper.findAll(".fan-card img").map((img) => img.attributes("src"))
    for (const hash of OVERNUMBERED) {
      expect(sources.some((src) => src.includes(hash) && src.includes("w=460"))).toBe(true)
    }
  })
})
