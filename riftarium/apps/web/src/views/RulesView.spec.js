import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import RulesView from "./RulesView.vue"

const stub = { template: "<div />" }

const RULES = {
  core: {
    title: "Règles du jeu",
    subtitle: "Document de référence",
    updated: "1 août 2026",
    ruleCount: 2,
    source: "https://exemple.test/regles.pdf",
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
            entries: [{ id: "100-1", number: "100.1.", depth: 0, text: "Première règle.", examples: [], refs: [] }]
          },
          {
            id: "101",
            number: "101.",
            title: "La partie",
            entries: [{ id: "101-1", number: "101.1.", depth: 1, text: "Seconde règle.", examples: [], refs: [] }]
          }
        ]
      }
    ]
  }
}

/* matchMedia mocké : `mobile` pilote la media query du sommaire (max-width: 760px). */
function stubMatchMedia(mobile) {
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query) => ({
      matches: mobile && String(query).includes("max-width: 760px"),
      media: query,
      addEventListener() {},
      removeEventListener() {},
      addListener() {},
      removeListener() {},
      dispatchEvent() {
        return false
      }
    }))
  )
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: RulesView },
      { path: "/regles", component: stub },
      { path: "/regles/debutant", component: stub },
      { path: "/regles/avancee", component: stub }
    ]
  })
  await router.push("/")
  const wrapper = mount(RulesView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return wrapper
}

describe("RulesView — sommaire repliable sur mobile", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(RULES) }))
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      callback()
      return 0
    })
    Element.prototype.scrollIntoView = vi.fn()
    window.scrollTo = vi.fn()
  })

  afterEach(() => {
    delete Element.prototype.scrollIntoView
    vi.unstubAllGlobals()
  })

  it("desktop : sommaire toujours déplié, changement de section = retour en haut de page", async () => {
    stubMatchMedia(false)
    const wrapper = await mountView()

    expect(wrapper.find(".rules-toc").exists()).toBe(true)
    expect(wrapper.find(".rules-toc").classes()).not.toContain("folded")
    // le bouton existe dans le DOM mais reste masqué par le CSS (hors mobile)
    expect(wrapper.find(".rules-toc-toggle").attributes("aria-expanded")).toBe("true")

    await wrapper.findAll(".toc-section")[1].trigger("click")
    expect(window.scrollTo).toHaveBeenCalled()
    expect(Element.prototype.scrollIntoView).not.toHaveBeenCalled()
    expect(wrapper.find(".rules-toc").classes()).not.toContain("folded")
    wrapper.unmount()
  })

  it("mobile : sommaire replié au chargement, le bouton le déplie", async () => {
    stubMatchMedia(true)
    const wrapper = await mountView()

    const toggle = wrapper.get(".rules-toc-toggle")
    expect(toggle.attributes("aria-expanded")).toBe("false")
    expect(wrapper.get(".rules-toc").classes()).toContain("folded")

    await toggle.trigger("click")
    expect(toggle.attributes("aria-expanded")).toBe("true")
    expect(wrapper.get(".rules-toc").classes()).not.toContain("folded")
    wrapper.unmount()
  })

  it("mobile : choisir une section replie le sommaire et scrolle vers le texte, pas en haut", async () => {
    stubMatchMedia(true)
    const wrapper = await mountView()

    await wrapper.get(".rules-toc-toggle").trigger("click")
    await wrapper.findAll(".toc-section")[1].trigger("click")

    expect(wrapper.get(".rules-toc").classes()).toContain("folded")
    expect(Element.prototype.scrollIntoView).toHaveBeenCalled()
    expect(window.scrollTo).not.toHaveBeenCalled()
    expect(wrapper.text()).toContain("La partie")
    wrapper.unmount()
  })
})
