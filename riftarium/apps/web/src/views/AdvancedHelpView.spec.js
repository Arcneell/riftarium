import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import AdvancedHelpView from "./AdvancedHelpView.vue"
import Icon from "../components/Icon.vue"
import { TOPICS } from "../rules/topics.js"

const stub = { template: "<div />" }

async function mountHelp() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/regles", component: stub },
      { path: "/regles/avancee", component: AdvancedHelpView },
      { path: "/regles/avancee/:slug", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push("/regles/avancee")
  return mount(AdvancedHelpView, { global: { plugins: [router], components: { Icon } } })
}

describe("AdvancedHelpView", () => {
  it("liste tous les sujets, groupés par catégorie, avec lien vers leur page", async () => {
    const wrapper = await mountHelp()
    const rows = wrapper.findAll("a.aide-row")
    expect(rows).toHaveLength(TOPICS.length)
    const hrefs = rows.map((r) => r.attributes("href"))
    expect(hrefs).toContain("/regles/avancee/tank")
    expect(hrefs).toContain("/regles/avancee/conquete-et-occupation")
    expect(wrapper.text()).toContain("Mots-clés")
    expect(wrapper.find("h1").text()).toBe("Aide avancée")
  })

  it("filtre par recherche, accents ignorés", async () => {
    const wrapper = await mountHelp()
    await wrapper.find("input[type=search]").setValue("extenuation")
    const rows = wrapper.findAll("a.aide-row")
    expect(rows.length).toBeGreaterThan(0)
    expect(rows.length).toBeLessThan(TOPICS.length)
    expect(wrapper.text()).toContain("exténuation")
  })

  it("recherche sans résultat : état vide avec lien vers le texte officiel", async () => {
    const wrapper = await mountHelp()
    await wrapper.find("input[type=search]").setValue("zzzzqqqq")
    expect(wrapper.findAll("a.aide-row")).toHaveLength(0)
    const empty = wrapper.find(".rift-empty")
    expect(empty.text()).toContain("Aucune mécanique ne correspond")
    expect(empty.find("a").attributes("href")).toBe("/regles/officielles")
  })
})
