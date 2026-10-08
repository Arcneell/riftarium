import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import RulesView from "./RulesView.vue"
import Icon from "../components/Icon.vue"
import { resetRulesCache } from "../rules/rulesStore.js"

const stub = { template: "<div />" }

const RULES = {
  core: {
    title: "Règles du jeu",
    subtitle: "Document de référence",
    updated: "1 août 2026",
    ruleCount: 3,
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
            entries: [
              {
                id: "100-1",
                number: "100.1.",
                depth: 0,
                text: "Première règle, voir la règle 101.1.",
                examples: [{ text: "Un exemple." }],
                refs: [{ number: "101.1.", label: "La partie" }]
              }
            ]
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
  },
  tournament: {
    title: "Tournoi",
    updated: "2 août 2026",
    ruleCount: 1,
    source: "https://exemple.test/tournoi.pdf",
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
            entries: [{ id: "201-1", number: "201.1.", depth: 0, text: "Règle de tournoi.", examples: [], refs: [] }]
          }
        ]
      }
    ]
  }
}

/* matchMedia mocké : les paliers de la coquille (mobile < 768 px, tablette < 1 024 px). */
function stubMatchMedia(mobile) {
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query) => ({
      matches: mobile,
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

async function mountView(path = "/") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: RulesView },
      { path: "/regles", component: stub }
    ]
  })
  await router.push(path)
  const wrapper = mount(RulesView, {
    global: { plugins: [router], components: { Icon } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

/* Force navigator.onLine (getter configurable, retiré via restoreOnLine). */
function setOnLine(value) {
  Object.defineProperty(window.navigator, "onLine", { configurable: true, get: () => value })
}
function restoreOnLine() {
  delete window.navigator.onLine
}

beforeEach(() => {
  /* Le magasin de règles met le document en cache pour la session : on repart
     d'un cache vide à chaque cas, sinon le `fetch` mocké n'est jamais appelé. */
  resetRulesCache()
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(RULES) }))
  vi.stubGlobal("requestAnimationFrame", (callback) => {
    callback()
    return 0
  })
  Element.prototype.scrollIntoView = vi.fn()
  window.scrollTo = vi.fn()
  stubMatchMedia(false)
})

afterEach(() => {
  delete Element.prototype.scrollIntoView
  restoreOnLine()
  vi.useRealTimers()
  vi.unstubAllGlobals()
  document.body.innerHTML = ""
})

describe("RulesView : hors ligne", () => {
  it("en ligne : aucun statut", async () => {
    setOnLine(true)
    const { wrapper } = await mountView()
    expect(wrapper.find(".officiel-offline").exists()).toBe(false)
    wrapper.unmount()
  })

  it("hors ligne : statut affiché, retiré au retour du réseau", async () => {
    setOnLine(false)
    const { wrapper } = await mountView()
    expect(wrapper.get(".officiel-offline").text()).toBe(
      "Hors ligne : vous lisez les règles enregistrées sur cet appareil."
    )

    setOnLine(true)
    window.dispatchEvent(new Event("online"))
    await flushPromises()
    expect(wrapper.find(".officiel-offline").exists()).toBe(false)

    setOnLine(false)
    window.dispatchEvent(new Event("offline"))
    await flushPromises()
    expect(wrapper.find(".officiel-offline").exists()).toBe(true)
    wrapper.unmount()
  })

  it("démontage : les écouteurs online/offline sont retirés", async () => {
    setOnLine(true)
    const { wrapper } = await mountView()
    const removed = vi.spyOn(window, "removeEventListener")
    wrapper.unmount()
    const names = removed.mock.calls.map(([name]) => name)
    expect(names).toContain("online")
    expect(names).toContain("offline")
    removed.mockRestore()
  })
})

describe("RulesView : table des matières", () => {
  it("bureau : table des matières avec aria-current, changement de section = retour en haut", async () => {
    const { wrapper } = await mountView()

    expect(wrapper.find(".officiel-toc").exists()).toBe(true)
    expect(wrapper.find(".officiel-toc-bar").exists()).toBe(false)
    const sections = wrapper.findAll(".officiel-toc-section")
    expect(sections[0].attributes("aria-current")).toBe("true")
    expect(sections[1].attributes("aria-current")).toBeUndefined()

    await sections[1].trigger("click")
    expect(window.scrollTo).toHaveBeenCalled()
    const targets = Element.prototype.scrollIntoView.mock.contexts
    expect(targets.some((el) => el.classList?.contains("officiel-text"))).toBe(false)
    expect(wrapper.findAll(".officiel-toc-section")[1].attributes("aria-current")).toBe("true")
    expect(wrapper.get(".officiel-title").text()).toBe("La partie")
    wrapper.unmount()
  })

  it("téléphone : sommaire en feuille ; choisir une section ferme la feuille", async () => {
    stubMatchMedia(true)
    const { wrapper } = await mountView()

    expect(wrapper.find(".officiel-toc").exists()).toBe(false)
    expect(document.querySelector("[role='dialog']")).toBeNull()

    await wrapper.get(".officiel-toc-bar button").trigger("click")
    const dialog = document.querySelector("[role='dialog']")
    expect(dialog).not.toBeNull()

    dialog.querySelectorAll(".officiel-toc-section")[1].click()
    await flushPromises()
    expect(document.querySelector("[role='dialog']")).toBeNull()
    expect(Element.prototype.scrollIntoView).toHaveBeenCalled()
    const targets = Element.prototype.scrollIntoView.mock.contexts
    expect(targets.some((el) => el.classList?.contains("officiel-text"))).toBe(true)
    expect(window.scrollTo).not.toHaveBeenCalled()
    expect(wrapper.get(".officiel-title").text()).toBe("La partie")
    wrapper.unmount()
  })

  it("le raccourci flottant « Sommaire ↑ » n'existe plus", async () => {
    stubMatchMedia(true)
    const { wrapper } = await mountView()
    window.scrollY = 700
    window.dispatchEvent(new Event("scroll"))
    await flushPromises()
    expect(wrapper.text()).not.toContain("Sommaire ↑")
    window.scrollY = 0
    wrapper.unmount()
  })
})

describe("RulesView : feuille et paliers", () => {
  it("retour sur bureau : la feuille se ferme et ne rouvre pas au retour en compact", async () => {
    let listeners = []
    const state = { mobile: true }
    vi.stubGlobal(
      "matchMedia",
      vi.fn((query) => ({
        get matches() {
          return state.mobile
        },
        media: query,
        addEventListener(_, fn) {
          listeners.push(fn)
        },
        removeEventListener() {},
        addListener() {},
        removeListener() {},
        dispatchEvent() {
          return false
        }
      }))
    )
    const { wrapper } = await mountView()
    await wrapper.get(".officiel-toc-bar button").trigger("click")
    expect(document.querySelector("[role='dialog']")).not.toBeNull()

    state.mobile = false
    listeners.forEach((fn) => fn())
    await flushPromises()
    expect(wrapper.find(".officiel-toc").exists()).toBe(true)

    state.mobile = true
    listeners.forEach((fn) => fn())
    await flushPromises()
    expect(document.querySelector("[role='dialog']")).toBeNull()
    wrapper.unmount()
  })
})

describe("RulesView : lecture et renvois", () => {
  it("navigation sur la même page (résultat de recherche) : la section et la règle ciblées s'affichent", async () => {
    const { wrapper, router } = await mountView()
    expect(wrapper.get(".officiel-title").text()).toBe("Généralités")

    await router.push({ path: "/", query: { doc: "core", section: "101", rule: "101-1" } })
    await flushPromises()
    expect(wrapper.get(".officiel-title").text()).toBe("La partie")
    expect(wrapper.find(".officiel-rule--target").exists()).toBe(true)
    expect(router.currentRoute.value.query.section).toBe("101")

    /* section inconnue : repli sur la première, sans boucle de navigation */
    await router.push({ path: "/", query: { doc: "core", section: "zzz" } })
    await flushPromises()
    expect(wrapper.get(".officiel-title").text()).toBe("Généralités")
    wrapper.unmount()
  })

  it("clic sur un renvoi dans le texte navigue", async () => {
    const { wrapper, router } = await mountView()
    await wrapper.get(".officiel-text p button.rift-ref").trigger("click")
    await flushPromises()
    expect(wrapper.get(".officiel-title").text()).toBe("La partie")
    expect(router.currentRoute.value.query).toEqual({ doc: "core", section: "101", rule: "101-1" })
    expect(wrapper.find(".officiel-rule--target").exists()).toBe(true)
    wrapper.unmount()
  })

  it("clic sur un renvoi listé (entry.refs) navigue", async () => {
    const { wrapper } = await mountView()
    await wrapper.get(".officiel-xrefs button.rift-ref").trigger("click")
    await flushPromises()
    expect(wrapper.get(".officiel-title").text()).toBe("La partie")
    wrapper.unmount()
  })

  it("lien venu de l'aide avancée (?doc=&ref=) : place le lecteur sur la règle et remplace l'URL", async () => {
    /* rAF différé : la règle ciblée doit être rendue avant le défilement. */
    vi.stubGlobal("requestAnimationFrame", (callback) => setTimeout(callback, 0))
    const { wrapper, router } = await mountView("/?doc=tournament&ref=201.1")
    await new Promise((resolve) => setTimeout(resolve, 10))
    expect(wrapper.get(".officiel-title").text()).toBe("Arbitrage")
    expect(wrapper.find(".officiel-rule--target").exists()).toBe(true)
    /* chargement par lien profond : défilement instantané */
    expect(Element.prototype.scrollIntoView).toHaveBeenCalledWith({ block: "center" })
    expect(router.currentRoute.value.query).toEqual({ doc: "tournament", section: "201", rule: "201-1" })
    wrapper.unmount()
  })

  it("le sélecteur de document change de document", async () => {
    const { wrapper } = await mountView()
    const radios = wrapper.findAll("[role='radio']")
    expect(radios.map((r) => r.text())).toEqual(["Règles du jeu", "Tournoi"])
    await radios[1].trigger("click")
    expect(wrapper.get(".officiel-title").text()).toBe("Arbitrage")
    wrapper.unmount()
  })
})

describe("RulesView : recherche", () => {
  it("Échap vide la recherche", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] })
    const { wrapper } = await mountView()
    const input = wrapper.get("input[type='search']")
    await input.setValue("seconde")
    vi.advanceTimersByTime(200)
    await flushPromises()
    expect(wrapper.findAll(".officiel-hit")).toHaveLength(1)

    await input.trigger("keydown", { key: "Escape" })
    expect(input.element.value).toBe("")
    expect(wrapper.find(".officiel-hit").exists()).toBe(false)
    wrapper.unmount()
  })

  async function withHits() {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] })
    const { wrapper } = await mountView()
    const input = wrapper.get("input[type='search']")
    await input.setValue("seconde")
    vi.advanceTimersByTime(200)
    await flushPromises()
    expect(wrapper.findAll(".officiel-hit")).toHaveLength(1)
    return { wrapper, input }
  }

  it("un pointerdown hors de la recherche ferme les résultats et garde la saisie", async () => {
    const { wrapper, input } = await withHits()
    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }))
    await flushPromises()
    expect(wrapper.find(".officiel-hit").exists()).toBe(false)
    expect(input.element.value).toBe("seconde")
    wrapper.unmount()
  })

  it("un pointerdown dans la recherche laisse les résultats ouverts", async () => {
    const { wrapper } = await withHits()
    wrapper.get(".officiel-hit").element.dispatchEvent(new Event("pointerdown", { bubbles: true }))
    await flushPromises()
    expect(wrapper.find(".officiel-hit").exists()).toBe(true)
    wrapper.unmount()
  })

  it("un focusout vers l'extérieur ferme, le focus dans le champ rouvre", async () => {
    const { wrapper, input } = await withHits()
    const outside = document.createElement("button")
    document.body.appendChild(outside)
    await wrapper.get(".officiel-search").trigger("focusout", { relatedTarget: outside })
    expect(wrapper.find(".officiel-hit").exists()).toBe(false)
    expect(input.element.value).toBe("seconde")
    await input.trigger("focusin")
    expect(wrapper.find(".officiel-hit").exists()).toBe(true)
    outside.remove()
    wrapper.unmount()
  })

  it("un focusout vers un résultat reste ouvert, une nouvelle saisie rouvre", async () => {
    const { wrapper, input } = await withHits()
    const hit = wrapper.get(".officiel-hit").element
    await wrapper.get(".officiel-search").trigger("focusout", { relatedTarget: hit })
    expect(wrapper.find(".officiel-hit").exists()).toBe(true)
    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }))
    await flushPromises()
    expect(wrapper.find(".officiel-hit").exists()).toBe(false)
    await input.setValue("seconde ")
    vi.advanceTimersByTime(200)
    await flushPromises()
    expect(wrapper.find(".officiel-hit").exists()).toBe(true)
    wrapper.unmount()
  })

  it("aucun résultat : message vide dès 2 caractères", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] })
    const { wrapper } = await mountView()
    await wrapper.get("input[type='search']").setValue("zzzz")
    vi.advanceTimersByTime(200)
    await flushPromises()
    expect(wrapper.get(".officiel-nohit").text()).toContain("Aucune règle trouvée")
    wrapper.unmount()
  })
})

describe("RulesView : erreur", () => {
  it("échec de chargement : message et bouton Réessayer", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValueOnce(new Error("réseau")))
    const { wrapper } = await mountView()
    expect(wrapper.text()).toContain("Impossible de charger les règles")
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(RULES) }))
    const retry = wrapper.findAll("button").find((b) => b.text() === "Réessayer")
    await retry.trigger("click")
    await flushPromises()
    expect(wrapper.get(".officiel-title").text()).toBe("Généralités")
    wrapper.unmount()
  })
})
