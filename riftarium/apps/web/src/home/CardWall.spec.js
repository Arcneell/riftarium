import { flushPromises, mount, RouterLinkStub } from "@vue/test-utils"
import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", () => ({ api: vi.fn(), cardThumb: (url, w) => `${url}?w=${w}` }))
const { api } = await import("../api.js")
const { default: CardWall } = await import("./CardWall.vue")

const cards = (n) => Array.from({ length: n }, (_, i) => ({ id: `c${i}`, name: `C${i}`, image_url: `img${i}` }))
const SETS = [
  { set_id: "ogn", name: "Origins", published_on: "2025-10-31" },
  { set_id: "sfd", name: "Spiritforged", published_on: "2026-02-13" }
]

function mockApi(items) {
  api.mockImplementation(async (path) => {
    if (path === "/api/sets") return SETS
    if (path.startsWith("/api/cards")) return { items }
    throw new Error(path)
  })
}

const original = window.matchMedia
function reducedMotion(on) {
  window.matchMedia = (query) => ({
    matches: on && query.includes("prefers-reduced-motion"),
    addEventListener() {},
    removeEventListener() {}
  })
}

async function mountWall() {
  const wrapper = mount(CardWall, { global: { stubs: { RouterLink: RouterLinkStub } } })
  await flushPromises()
  return wrapper
}

describe("CardWall", () => {
  afterEach(() => {
    vi.clearAllMocks()
    window.matchMedia = original
  })

  it("montre le dernier set, en boucle, avec un lien vers ses cartes", async () => {
    reducedMotion(false)
    mockApi(cards(30))
    const wrapper = await mountWall()
    expect(api).toHaveBeenCalledWith("/api/cards?set_id=sfd&sort=random&size=48")
    expect(wrapper.text()).toContain("Spiritforged")
    expect(wrapper.getComponent(RouterLinkStub).props("to")).toBe("/cartes?set=sfd")
    expect(wrapper.findAll(".wall-track img")).toHaveLength(48)
    expect(wrapper.get(".wall-mosaic").attributes("aria-hidden")).toBe("true")
    expect(wrapper.get(".wall").classes()).not.toContain("static")
    expect(wrapper.text()).toContain("© Riot Games")
  })

  it("devient statique si l'utilisateur réduit les animations", async () => {
    reducedMotion(true)
    mockApi(cards(30))
    const wrapper = await mountWall()
    expect(wrapper.get(".wall").classes()).toContain("static")
  })

  it("ne s'affiche pas avec trop peu de cartes ou une API en panne", async () => {
    reducedMotion(false)
    mockApi(cards(5))
    expect((await mountWall()).find(".wall").exists()).toBe(false)
    mockApi(cards(20))
    expect((await mountWall()).find(".wall").exists()).toBe(false)
    mockApi(cards(50))
    expect((await mountWall()).findAll(".wall-track img")).toHaveLength(96)
    api.mockRejectedValue(new Error("hors ligne"))
    expect((await mountWall()).find(".wall").exists()).toBe(false)
  })
})
