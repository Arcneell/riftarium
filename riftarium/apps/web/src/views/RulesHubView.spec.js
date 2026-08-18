import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import RulesHubView from "./RulesHubView.vue"

const stub = { template: "<div />" }

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/regles", component: RulesHubView },
      { path: "/regles/debutant", component: stub },
      { path: "/regles/avancee", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
}

function mountHub(router) {
  return mount(RulesHubView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } }
  })
}

describe("RulesHubView", () => {
  it("propose les trois niveaux dans l'ordre : débutant, aide avancée, officiel", async () => {
    const router = makeRouter()
    await router.push("/regles")
    const wrapper = mountHub(router)
    const links = wrapper.findAll("a.tier").map((a) => a.attributes("href"))
    expect(links).toEqual(["/regles/debutant", "/regles/avancee", "/regles/officielles"])
    expect(wrapper.text()).toContain("Dernier recours")
    expect(wrapper.text()).toContain("Règle d'or")
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
