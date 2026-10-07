import { flushPromises, mount } from "@vue/test-utils"
import { defineComponent } from "vue"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { resetRulesCache } from "./rulesStore.js"
import { useRulesReader } from "./useRulesReader.js"

const stub = { template: "<div />" }

const RULES = {
  core: {
    title: "Règles du jeu",
    chapters: [
      {
        id: "c1",
        title: "Concepts",
        number: "1.",
        sections: [
          {
            id: "100",
            number: "100.",
            title: "Généralités",
            entries: [
              { id: "100-1", number: "100.1.", depth: 0, text: "Première règle, voir la règle 201.1.", refs: [] },
              { id: "100-2", number: "100.2.", depth: 0, text: "Une créature éphémère disparaît.", refs: [] }
            ]
          },
          {
            id: "101",
            number: "101.",
            title: "La partie",
            entries: [{ id: "101-1", number: "101.1.", depth: 1, text: "Seconde règle.", refs: [] }]
          }
        ]
      }
    ]
  },
  tournament: {
    title: "Tournoi",
    chapters: [
      {
        id: "t1",
        title: "Organisation",
        number: "2.",
        sections: [
          {
            id: "201",
            number: "201.",
            title: "Arbitrage",
            entries: [{ id: "201-1", number: "201.1.", depth: 0, text: "Règle de tournoi.", refs: [] }]
          }
        ]
      }
    ]
  }
}

let reader
const Harness = defineComponent({
  setup() {
    reader = useRulesReader()
    return () => null
  }
})

async function mountReader(path = "/") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push(path)
  const replace = vi.spyOn(router, "replace")
  const wrapper = mount(Harness, { global: { plugins: [router] } })
  await flushPromises()
  return { wrapper, router, replace }
}

describe("useRulesReader", () => {
  beforeEach(() => {
    resetRulesCache()
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(RULES) }))
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      callback()
      return 0
    })
    window.scrollTo = vi.fn()
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] })
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it("charge les documents et se place sur la première section", async () => {
    const { wrapper } = await mountReader()
    expect(reader.currentSection.value.id).toBe("100")
    expect(reader.openChapters.value.has("c1")).toBe(true)
    expect(reader.nextSection.value.id).toBe("101")
    expect(reader.previousSection.value).toBeUndefined()
    wrapper.unmount()
  })

  it("followRef vers un autre document", async () => {
    const { wrapper, replace } = await mountReader()
    reader.followRef("201.1")
    expect(reader.doc.value).toBe("tournament")
    expect(reader.sectionId.value).toBe("201")
    expect(reader.ruleId.value).toBe("201-1")
    expect(replace).toHaveBeenCalledWith({ query: { doc: "tournament", section: "201", rule: "201-1" } })
    wrapper.unmount()
  })

  it("numéro introuvable : rien ne se passe", async () => {
    const { wrapper, replace } = await mountReader()
    reader.followRef("999.9")
    expect(reader.doc.value).toBe("core")
    expect(reader.sectionId.value).toBe("100")
    expect(replace).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("recherche accent-insensible, 2 caractères minimum", async () => {
    const { wrapper } = await mountReader()
    reader.searchQuery.value = "e"
    reader.onSearchInput()
    vi.advanceTimersByTime(200)
    expect(reader.searchHits.value).toEqual([])

    reader.searchQuery.value = "ephemere"
    reader.onSearchInput()
    vi.advanceTimersByTime(200)
    expect(reader.searchHits.value.map((hit) => hit.id)).toEqual(["100-2"])
    expect(reader.searchHits.value[0].snippet).toContain("éphémère")

    reader.clearSearch()
    expect(reader.searchQuery.value).toBe("")
    expect(reader.searchHits.value).toEqual([])
    wrapper.unmount()
  })

  it("applyQuery n'appelle pas router.replace", async () => {
    const { wrapper, router, replace } = await mountReader("/?doc=core&section=101&rule=101-1")
    expect(reader.sectionId.value).toBe("101")
    expect(reader.ruleId.value).toBe("101-1")
    await router.push({ path: "/", query: { doc: "core", section: "100" } })
    await flushPromises()
    expect(reader.sectionId.value).toBe("100")
    expect(reader.ruleId.value).toBeNull()
    expect(replace).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("?doc=&ref= : résout le renvoi dans le document et remplace l'URL", async () => {
    const { wrapper, router } = await mountReader("/?doc=tournament&ref=201.1")
    expect(reader.doc.value).toBe("tournament")
    expect(reader.sectionId.value).toBe("201")
    expect(reader.ruleId.value).toBe("201-1")
    await flushPromises()
    expect(router.currentRoute.value.query).toEqual({ doc: "tournament", section: "201", rule: "201-1" })
    wrapper.unmount()
  })

  it("?doc=&ref= introuvable : ouvre le document au début", async () => {
    const { wrapper, router } = await mountReader("/?doc=tournament&ref=999.9")
    expect(reader.doc.value).toBe("tournament")
    expect(reader.sectionId.value).toBe("201")
    expect(reader.ruleId.value).toBeNull()
    await flushPromises()
    expect(router.currentRoute.value.query).toEqual({ doc: "tournament", section: "201" })
    wrapper.unmount()
  })

  it("?ref= sur la même page (navigation sans remontage) est résolu", async () => {
    const { wrapper, router } = await mountReader()
    await router.push({ path: "/", query: { doc: "core", ref: "101.1" } })
    await flushPromises()
    expect(reader.sectionId.value).toBe("101")
    expect(reader.ruleId.value).toBe("101-1")
    expect(router.currentRoute.value.query.ref).toBeUndefined()
    wrapper.unmount()
  })
})
