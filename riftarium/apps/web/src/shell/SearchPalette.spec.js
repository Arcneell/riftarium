import { flushPromises, mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("../search/search.js", async (importOriginal) => ({
  ...(await importOriginal()),
  runSearch: vi.fn()
}))

const { runSearch } = await import("../search/search.js")
const { default: Icon } = await import("../components/Icon.vue")
const { makeRouter } = await import("../test/makeRouter.js")
const { default: SearchPalette } = await import("./SearchPalette.vue")

const GROUPS = [
  {
    key: "cards",
    label: "Cartes",
    error: false,
    items: [{ id: "c1", label: "Ahri", hint: "OGN-001", to: "/cartes/c1" }]
  },
  { key: "decks", label: "Decks de la communauté", error: true, items: [] },
  {
    key: "pages",
    label: "Pages",
    error: false,
    items: [{ id: "p1", label: "Collection", hint: "Page", to: "/collection" }]
  }
]

async function mountPalette() {
  const router = await makeRouter("/")
  const wrapper = mount(SearchPalette, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
  await nextTick()
  return { wrapper, router, input: () => document.querySelector(".palette input") }
}

async function type(input, value) {
  input.value = value
  input.dispatchEvent(new Event("input"))
  await nextTick()
}

const key = (input, name) => input.dispatchEvent(new KeyboardEvent("keydown", { key: name, bubbles: true }))

describe("SearchPalette", () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.clearAllMocks()
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("prend le focus dans le champ et n'interroge qu'après 200 ms de pause", async () => {
    runSearch.mockResolvedValue(GROUPS)
    const { wrapper, input } = await mountPalette()
    expect(document.activeElement).toBe(input())
    await type(input(), "ah")
    await type(input(), "ahr")
    vi.advanceTimersByTime(199)
    expect(runSearch).not.toHaveBeenCalled()
    vi.advanceTimersByTime(1)
    await flushPromises()
    expect(runSearch).toHaveBeenCalledTimes(1)
    expect(runSearch).toHaveBeenCalledWith("ahr", expect.objectContaining({ signal: expect.any(AbortSignal) }))
    wrapper.unmount()
  })

  it("affiche les groupes, signale le groupe indisponible", async () => {
    runSearch.mockResolvedValue(GROUPS)
    const { wrapper, input } = await mountPalette()
    await type(input(), "ahri")
    vi.advanceTimersByTime(200)
    await flushPromises()
    const text = document.querySelector(".palette").textContent
    expect(text).toContain("Ahri")
    expect(text).toContain("Collection")
    expect(text).toContain("Recherche indisponible")
    wrapper.unmount()
  })

  it("ignore une réponse périmée arrivée après la plus récente", async () => {
    let resolveOld
    runSearch
      .mockImplementationOnce(() => new Promise((resolve) => (resolveOld = resolve)))
      .mockResolvedValueOnce([GROUPS[2]])
    const { wrapper, input } = await mountPalette()
    await type(input(), "ah")
    vi.advanceTimersByTime(200)
    await type(input(), "coll")
    vi.advanceTimersByTime(200)
    await flushPromises()
    resolveOld([GROUPS[0]])
    await flushPromises()
    const text = document.querySelector(".palette").textContent
    expect(text).toContain("Collection")
    expect(text).not.toContain("Ahri")
    wrapper.unmount()
  })

  it("↓ puis Entrée ouvre le résultat choisi et ferme la palette", async () => {
    runSearch.mockResolvedValue(GROUPS)
    const { wrapper, router, input } = await mountPalette()
    await type(input(), "ahri")
    vi.advanceTimersByTime(200)
    await flushPromises()
    key(input(), "ArrowDown")
    await nextTick()
    expect(input().getAttribute("aria-activedescendant")).toBe("palette-opt-1")
    key(input(), "Enter")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/collection")
    expect(wrapper.emitted("close")).toBeTruthy()
    wrapper.unmount()
  })

  it("affiche un état vide explicite", async () => {
    runSearch.mockResolvedValue([])
    const { wrapper, input } = await mountPalette()
    await type(input(), "zzzz")
    vi.advanceTimersByTime(200)
    await flushPromises()
    expect(document.querySelector(".palette").textContent).toContain("Aucun résultat")
    wrapper.unmount()
  })
})
