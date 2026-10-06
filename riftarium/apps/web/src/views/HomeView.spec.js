import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", async (importOriginal) => ({ ...(await importOriginal()), api: vi.fn() }))
const { api } = await import("../api.js")
const { default: HomeView } = await import("./HomeView.vue")

const stubs = { HomeSplash: { props: ["art", "cardCount", "setCount"], template: "<div class='splash-stub' />" } }

describe("HomeView", () => {
  afterEach(() => vi.clearAllMocks())

  it("compose le splash, le mur et les blocs", async () => {
    api.mockImplementation(async (path) => {
      if (path === "/api/sets") return [{ set_id: "ogn" }, { set_id: "sfd" }]
      if (path === "/api/cards?size=1") return { total: 1024, items: [] }
      return { items: [] }
    })
    const wrapper = mount(HomeView, { global: { stubs: { ...stubs, CardWall: true, HomeBlocks: true } } })
    await flushPromises()
    const splash = wrapper.findComponent(stubs.HomeSplash)
    expect(splash.props("art")).toMatch(/^https:\/\//)
    expect(splash.props("cardCount")).toBe(1024)
    expect(splash.props("setCount")).toBe(2)
    expect(wrapper.findComponent({ name: "CardWall" }).exists()).toBe(true)
    expect(wrapper.findComponent({ name: "HomeBlocks" }).exists()).toBe(true)
  })

  it("chiffres inconnus si l'API ne répond pas", async () => {
    api.mockRejectedValue(new Error("hors ligne"))
    const wrapper = mount(HomeView, { global: { stubs: { ...stubs, CardWall: true, HomeBlocks: true } } })
    await flushPromises()
    const splash = wrapper.findComponent(stubs.HomeSplash)
    expect(splash.props("cardCount")).toBeNull()
    expect(splash.props("setCount")).toBeNull()
  })
})
