import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import AdvancedTopicView from "./AdvancedTopicView.vue"
import { resetRulesCache } from "../rules/rulesStore.js"

const stub = { template: "<div />" }

const RULES = {
  core: {
    title: "Règles du jeu",
    chapters: [
      {
        id: "kw",
        title: "Mots-clés",
        number: "8.",
        sections: [
          {
            id: "815",
            number: "815.",
            title: "Tank",
            entries: [{ id: "815-1", number: "815.1.", depth: 0, text: "Tank est un mot-clé de compétence passive." }]
          }
        ]
      }
    ]
  }
}

async function mountTopic(slug) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/regles", component: stub },
      { path: "/regles/avancee", component: stub },
      { path: "/regles/avancee/:slug", component: AdvancedTopicView },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push(`/regles/avancee/${slug}`)
  const wrapper = mount(AdvancedTopicView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } }
  })
  await flushPromises()
  return wrapper
}

describe("AdvancedTopicView", () => {
  beforeEach(() => {
    /* Le magasin de règles garde le document en cache : on repart d'un cache vide. */
    resetRulesCache()
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(RULES) }))
  })

  it("affiche l'essentiel, les cas concrets et le texte officiel du sujet", async () => {
    const wrapper = await mountTopic("tank")
    expect(wrapper.text()).toContain("Tank")
    expect(wrapper.text()).toContain("L'essentiel")
    expect(wrapper.text()).toContain("Cas concrets")
    expect(wrapper.text()).toContain("Le texte officiel, en intégralité")
    expect(wrapper.text()).toContain("815.1.")
    const example = wrapper.find(".topic-example img")
    expect(example.attributes("src")).toContain("cmsassets.rgpub.io")
  })

  it("un seul téléchargement des règles pour plusieurs sujets (cache de module)", async () => {
    await mountTopic("tank")
    await mountTopic("bouclier")
    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it("règles indisponibles : le sujet s'affiche avec un renvoi vers le lecteur", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 404, json: () => Promise.resolve({}) }))
    const wrapper = await mountTopic("tank")
    expect(wrapper.text()).toContain("L'essentiel")
    expect(wrapper.text()).toContain("Texte officiel indisponible")
    expect(wrapper.text()).not.toContain("Le texte officiel, en intégralité")
  })

  it("Échap ferme le zoom d'une carte d'exemple", async () => {
    const wrapper = await mountTopic("tank")
    await wrapper.get(".topic-example").trigger("click")
    await flushPromises()
    expect(wrapper.find(".topic-zoom").exists()).toBe(true)
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    await flushPromises()
    expect(wrapper.find(".topic-zoom").exists()).toBe(false)
  })

  it("affiche un message pour un slug inconnu", async () => {
    const wrapper = await mountTopic("nexiste-pas")
    expect(wrapper.text()).toContain("Sujet introuvable")
  })
})
