import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import AdvancedTopicView from "./AdvancedTopicView.vue"
import Icon from "../components/Icon.vue"
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
            entries: [
              { id: "815-1", number: "815.1.", depth: 0, text: "Tank est un mot-clé de compétence passive." },
              { id: "815-2", number: "815.2.", depth: 0, text: "Voir la règle 346.1 pour le détail." }
            ]
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
    attachTo: document.body,
    global: { plugins: [router], components: { Icon } }
  })
  await flushPromises()
  return { wrapper, router }
}

/* La modale de zoom est téléportée dans le body : on la cherche dans le document. */
const zoomDialog = () => document.querySelector("[role='dialog']")

describe("AdvancedTopicView", () => {
  beforeEach(() => {
    /* Le magasin de règles garde le document en cache : on repart d'un cache vide. */
    resetRulesCache()
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(RULES) }))
  })

  afterEach(() => {
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("affiche l'essentiel, les cas concrets et le texte officiel du sujet", async () => {
    const { wrapper } = await mountTopic("tank")
    expect(wrapper.find("h1").text()).toBe("Tank")
    expect(wrapper.text()).toContain("L'essentiel")
    expect(wrapper.text()).toContain("Cas concrets")
    expect(wrapper.text()).toContain("Le texte officiel, en intégralité")
    expect(wrapper.text()).toContain("815.1.")
    const example = wrapper.find(".sujet-example img")
    expect(example.attributes("src")).toContain("cmsassets.rgpub.io")
  })

  it("un seul téléchargement des règles pour plusieurs sujets (cache de module)", async () => {
    await mountTopic("tank")
    await mountTopic("bouclier")
    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it("règles indisponibles : le sujet s'affiche avec un renvoi vers le lecteur", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 404, json: () => Promise.resolve({}) }))
    const { wrapper } = await mountTopic("tank")
    expect(wrapper.text()).toContain("L'essentiel")
    expect(wrapper.text()).toContain("Texte officiel indisponible")
    expect(wrapper.text()).not.toContain("Le texte officiel, en intégralité")
  })

  it("Échap ferme le zoom d'une carte d'exemple", async () => {
    const { wrapper } = await mountTopic("tank")
    await wrapper.get(".sujet-example").trigger("click")
    await flushPromises()
    expect(zoomDialog()).not.toBeNull()
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    await flushPromises()
    expect(zoomDialog()).toBeNull()
  })

  it("affiche un état vide pour un slug inconnu", async () => {
    const { wrapper } = await mountTopic("nexiste-pas")
    expect(wrapper.find(".rift-empty").exists()).toBe(true)
    expect(wrapper.text()).toContain("Sujet introuvable")
    expect(wrapper.find(".rift-empty a").attributes("href")).toBe("/regles/avancee")
  })

  it("exemple : un clic sur la carte ouvre le zoom", async () => {
    const { wrapper } = await mountTopic("tank")
    expect(zoomDialog()).toBeNull()
    await wrapper.get(".sujet-example").trigger("click")
    await flushPromises()
    const dialog = zoomDialog()
    expect(dialog).not.toBeNull()
    expect(dialog.querySelector("img").getAttribute("alt")).toBeTruthy()
  })

  it("un renvoi du texte officiel mène au lecteur avec doc et ref", async () => {
    const { wrapper, router } = await mountTopic("tank")
    await wrapper.get("button[data-ref='346.1']").trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/regles/officielles")
    expect(router.currentRoute.value.query).toEqual({ doc: "core", ref: "346.1" })
  })
})
