import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, describe, expect, it } from "vitest"
import LearnGuideView from "./LearnGuideView.vue"
import Icon from "../components/Icon.vue"
import { CHAPTERS, DEFAULT_CHAPTER } from "../rules/learn.js"

const stub = { template: "<div />" }

async function mountGuide(path = "/regles/debutant") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/regles", component: stub },
      { path: "/regles/debutant", component: LearnGuideView },
      { path: "/regles/debutant/plateau", component: stub },
      { path: "/regles/debutant/:slug", component: LearnGuideView },
      { path: "/regles/avancee", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push(path)
  const wrapper = mount(LearnGuideView, {
    attachTo: document.body,
    global: { plugins: [router], components: { Icon } }
  })
  await flushPromises()
  return { wrapper, router }
}

afterEach(() => {
  document.body.innerHTML = ""
  document.body.classList.remove("nav-locked")
})

describe("LearnGuideView", () => {
  it("ouvre le premier chapitre et liste tous les chapitres dans le sommaire", async () => {
    const { wrapper } = await mountGuide()
    expect(wrapper.text()).toContain(CHAPTERS[0].title)
    expect(wrapper.text()).toContain(`${CHAPTERS.length} chapitres`)
    expect(wrapper.findAll(".chapitre-toc-link")).toHaveLength(CHAPTERS.length)
    wrapper.unmount()
  })

  it("navigue vers le chapitre suivant", async () => {
    const { wrapper, router } = await mountGuide()
    const next = wrapper.findAll("a").find((a) => a.text().includes(`${CHAPTERS[1].title} →`))
    expect(next).toBeTruthy()
    await next.trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe(`/regles/debutant/${CHAPTERS[1].slug}`)
    wrapper.unmount()
  })

  it("redirige /regles/debutant/apercu vers l'URL courte", async () => {
    const { router, wrapper } = await mountGuide(`/regles/debutant/${DEFAULT_CHAPTER}`)
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/regles/debutant")
    wrapper.unmount()
  })

  it("envoie les anciens ?etape= vers le plateau animé", async () => {
    const { router, wrapper } = await mountGuide("/regles/debutant?etape=4")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/regles/debutant/plateau")
    expect(router.currentRoute.value.query.etape).toBe("4")
    wrapper.unmount()
  })

  it("affiche la démo de runes sur le chapitre ressources", async () => {
    const { wrapper } = await mountGuide("/regles/debutant/runes")
    expect(wrapper.find(".lecon-runes").exists()).toBe(true)
    expect(wrapper.text()).toContain("Énergie")
    expect(wrapper.text()).toContain("Essence Fureur")
    wrapper.unmount()
  })

  it("agrandit une carte au double-clic dans un dialogue qui verrouille le défilement", async () => {
    const { wrapper } = await mountGuide()
    expect(document.body.querySelector('[role="dialog"]')).toBeNull()
    await wrapper.findAll(".lecon-type")[0].trigger("dblclick")
    await flushPromises()
    expect(document.body.querySelector('[role="dialog"] img.carte-zoom-img')).toBeTruthy()
    expect(document.body.classList.contains("nav-locked")).toBe(true)
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await flushPromises()
    expect(document.body.querySelector('[role="dialog"]')).toBeNull()
    expect(document.body.classList.contains("nav-locked")).toBe(false)
    wrapper.unmount()
  })

  it("sommaire : aria-current sur le chapitre courant", async () => {
    const { wrapper } = await mountGuide(`/regles/debutant/${CHAPTERS[2].slug}`)
    const nav = wrapper.get('nav[aria-label="Chapitres du guide"]')
    const current = nav.findAll("[aria-current='page']")
    expect(current).toHaveLength(1)
    expect(current[0].text()).toContain(CHAPTERS[2].title)
    wrapper.unmount()
  })

  it("chapitre introuvable : RiftEmpty avec lien de retour", async () => {
    const { wrapper } = await mountGuide("/regles/debutant/inconnu")
    expect(wrapper.find(".rift-empty").exists()).toBe(true)
    expect(wrapper.text()).toContain("Chapitre introuvable")
    const back = wrapper.findAll("a").find((a) => a.text().includes("Retour au guide"))
    expect(back.attributes("href")).toBe("/regles/debutant")
    wrapper.unmount()
  })
})
