import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, describe, expect, it } from "vitest"
import RulesHubView from "./RulesHubView.vue"

const stub = { template: "<div />" }

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/regles", component: RulesHubView },
      { path: "/regles/debutant", component: stub },
      { path: "/regles/debutant/plateau", component: stub },
      { path: "/regles/avancee", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
}

function mountHub(router) {
  return mount(RulesHubView, { global: { plugins: [router] } })
}

afterEach(() => {
  Object.defineProperty(navigator, "onLine", { value: true, configurable: true })
})

describe("RulesHubView", () => {
  it("propose les trois niveaux dans l'ordre : débutant, aide avancée, officiel", async () => {
    const router = makeRouter()
    await router.push("/regles")
    const wrapper = mountHub(router)
    const links = wrapper.findAll("a.portail").map((a) => a.attributes("href"))
    expect(links).toEqual(["/regles/debutant", "/regles/avancee", "/regles/officielles"])
    expect(wrapper.text()).toContain("Dernier recours")
    expect(wrapper.text()).toContain("Apprendre à jouer")
    expect(wrapper.text()).toContain("Règle d'or")
    expect(wrapper.get("h1").text()).toBe("Règles")
  })

  it("trois portails avec les bons liens, le premier en pleine largeur (classe)", async () => {
    const router = makeRouter()
    await router.push("/regles")
    const wrapper = mountHub(router)
    const portails = wrapper.findAll("a.portail")
    expect(portails).toHaveLength(3)
    expect(portails.map((a) => a.attributes("href"))).toEqual([
      "/regles/debutant",
      "/regles/avancee",
      "/regles/officielles"
    ])
    expect(portails[0].classes()).toContain("portail-big")
    expect(portails[1].classes()).not.toContain("portail-big")
    expect(portails[2].classes()).not.toContain("portail-big")
  })

  it("hors ligne : statut affiché", async () => {
    Object.defineProperty(navigator, "onLine", { value: false, configurable: true })
    const router = makeRouter()
    await router.push("/regles")
    const wrapper = mountHub(router)
    const note = wrapper.get(".regles-offline")
    expect(note.attributes("role")).toBe("status")
    expect(note.text()).toContain("Hors ligne — règles servies depuis le cache")
  })

  it("en ligne : pas de statut hors ligne", async () => {
    const router = makeRouter()
    await router.push("/regles")
    expect(mountHub(router).find(".regles-offline").exists()).toBe(false)
  })

  it("accès rapide : 8 liens vers /regles/avancee/…", async () => {
    const router = makeRouter()
    await router.push("/regles")
    const wrapper = mountHub(router)
    const links = wrapper.findAll("a.regles-quick")
    expect(links).toHaveLength(8)
    for (const a of links) expect(a.attributes("href")).toMatch(/^\/regles\/avancee\/[a-z-]+$/)
  })

  it("redirige les anciens liens ?doc=…&section=… vers le lecteur officiel", async () => {
    const router = makeRouter()
    await router.push("/regles?doc=core&section=465&rule=465")
    mountHub(router)
    await router.isReady()
    await new Promise((resolve) => setTimeout(resolve))
    expect(router.currentRoute.value.path).toBe("/regles/officielles")
    expect(router.currentRoute.value.query).toMatchObject({ doc: "core", section: "465", rule: "465" })
  })
})
