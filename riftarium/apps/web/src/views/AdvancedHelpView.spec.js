import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import AdvancedHelpView from "./AdvancedHelpView.vue"
import { ENTRIES } from "../rules/help.js"

const stub = { template: "<div />" }

async function mountHelp() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/regles/avancee", component: AdvancedHelpView },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push("/regles/avancee")
  return mount(AdvancedHelpView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } }
  })
}

describe("AdvancedHelpView", () => {
  it("affiche toutes les fiches puis filtre par recherche, accents ignorés", async () => {
    const wrapper = await mountHelp()
    expect(wrapper.findAll(".help-card")).toHaveLength(ENTRIES.length)

    await wrapper.find("input[type=search]").setValue("conquete")
    const cards = wrapper.findAll(".help-card")
    expect(cards.length).toBeGreaterThan(0)
    expect(cards.length).toBeLessThan(ENTRIES.length)
    expect(wrapper.text()).toContain("Conquête vs occupation")
  })

  it("filtre par catégorie et ouvre une fiche avec son renvoi officiel", async () => {
    const wrapper = await mountHelp()
    const combat = wrapper.findAll(".filter").find((b) => b.text() === "Combat")
    await combat.trigger("click")
    const expected = ENTRIES.filter((e) => e.category === "combat").length
    expect(wrapper.findAll(".help-card")).toHaveLength(expected)

    await wrapper.find(".help-head").trigger("click")
    const body = wrapper.find(".help-body")
    expect(body.exists()).toBe(true)
    expect(body.find("a").attributes("href")).toContain("/regles/officielles?doc=core&section=")
  })
})
