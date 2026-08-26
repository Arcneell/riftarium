import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { api, cardThumb } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function fakeCard(index, extras = {}) {
  return {
    id: `card-${index}`,
    name: `Carte ${index}`,
    image_url: `https://cdn.example/${index}.png?accountingTag=RB`,
    orientation: "portrait",
    ...extras
  }
}

function matchMedia({ reduced = false, fine = true } = {}) {
  window.matchMedia = (query) => ({
    matches: String(query).includes("prefers-reduced-motion")
      ? reduced
      : String(query).includes("hover: hover") || String(query).includes("pointer: fine")
        ? fine
        : false,
    media: query,
    addEventListener() {},
    removeEventListener() {},
    addListener() {},
    removeListener() {},
    dispatchEvent() {
      return false
    }
  })
}

async function loadRiver() {
  vi.resetModules()
  globalThis.__io.instances = []
  const mod = await import("./CardRiver.vue")
  return mod.default
}

function mountRiver(CardRiver) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  return mount(CardRiver, {
    global: { plugins: [router] }
  })
}

describe("CardRiver", () => {
  let raf
  let caf

  beforeEach(() => {
    matchMedia()
    api.mockReset()
    api.mockResolvedValue({
      items: [
        fakeCard(1),
        fakeCard(2, { image_url: null }),
        fakeCard(3, { orientation: "landscape" }),
        ...Array.from({ length: 20 }, (_, i) => fakeCard(i + 10))
      ]
    })
    raf = vi.fn().mockReturnValue(1)
    caf = vi.fn()
    vi.stubGlobal("requestAnimationFrame", raf)
    vi.stubGlobal("cancelAnimationFrame", caf)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it("tire deux lots aléatoires et n'affiche que les cartes illustrées", async () => {
    const CardRiver = await loadRiver()
    const wrapper = mountRiver(CardRiver)
    await flushPromises()

    expect(api).toHaveBeenCalledTimes(2)
    expect(api.mock.calls.every(([path]) => path === "/api/cards?sort=random&size=40")).toBe(true)
    expect(wrapper.findAll(".river-card").every((card) => !card.html().includes("card-2"))).toBe(true)
    expect(wrapper.find(`[aria-label="Voir la carte Carte 1"]`).exists()).toBe(true)
    expect(wrapper.get(`[aria-label="Voir la carte Carte 1"]`).attributes("href")).toBe("/cartes/card-1")
    expect(wrapper.get(`[aria-label="Voir la carte Carte 1"] img`).attributes("src")).toBe(
      cardThumb("https://cdn.example/1.png?accountingTag=RB", 180)
    )
    expect(wrapper.get(`[aria-label="Voir la carte Carte 3"]`).classes()).toContain("landscape")
    expect(wrapper.findAll(".river-row")).toHaveLength(2)
    wrapper.unmount()
  })

  it("ne lance pas l'animation si le mouvement réduit est demandé", async () => {
    matchMedia({ reduced: true })
    const CardRiver = await loadRiver()
    const wrapper = mountRiver(CardRiver)
    await flushPromises()
    await Promise.resolve()

    expect(raf).not.toHaveBeenCalled()
    expect(globalThis.__io.instances).toHaveLength(0)
    wrapper.unmount()
  })

  it("démarre le défilement à l'entrée dans le viewport et se nettoie au démontage", async () => {
    const CardRiver = await loadRiver()
    const wrapper = mountRiver(CardRiver)
    await flushPromises()
    await Promise.resolve()
    await Promise.resolve()

    expect(globalThis.__io.instances).toHaveLength(1)
    const observer = globalThis.__io.instances[0]
    expect(observer.observe).toHaveBeenCalled()

    observer.callback([{ isIntersecting: true }])
    expect(raf).toHaveBeenCalled()

    wrapper.unmount()
    expect(caf).toHaveBeenCalled()
    expect(observer.disconnect).toHaveBeenCalled()
  })

  it("met le défilement en pause au survol", async () => {
    const CardRiver = await loadRiver()
    const wrapper = mountRiver(CardRiver)
    await flushPromises()
    await Promise.resolve()
    await Promise.resolve()

    const observer = globalThis.__io.instances[0]
    observer.callback([{ isIntersecting: true }])

    const first = wrapper.get(".river-track").attributes("style")
    await wrapper.get(".river-row").trigger("mouseenter")
    const tick = raf.mock.calls.at(-1)?.[0]
    tick?.(1000)
    await flushPromises()
    expect(wrapper.get(".river-track").attributes("style")).toBe(first)
    wrapper.unmount()
  })

  it("au doigt, l'appui fige la rangée et la reprise est différée après le relâchement", async () => {
    /* Sans survol, la carte visée glissait sous le pouce entre l'appui et le tap. */
    vi.useFakeTimers()
    matchMedia({ fine: false })
    const CardRiver = await loadRiver()
    const wrapper = mountRiver(CardRiver)
    await flushPromises()
    await Promise.resolve()
    await Promise.resolve()

    const observer = globalThis.__io.instances[0]
    observer.callback([{ isIntersecting: true }])

    const row = wrapper.get(".river-row")
    /* Le survol seul ne fige rien : au doigt il est émis par erreur juste avant le tap. */
    await row.trigger("mouseenter")
    expect(wrapper.vm.rows[0].held).toBe(false)

    await row.trigger("pointerdown")
    expect(wrapper.vm.rows[0].held).toBe(true)

    await row.trigger("pointerup")
    expect(wrapper.vm.rows[0].held).toBe(true)
    vi.advanceTimersByTime(1300)
    await flushPromises()
    expect(wrapper.vm.rows[0].held).toBe(false)

    wrapper.unmount()
    vi.useRealTimers()
  })
})
