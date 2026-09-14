import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import LearnGuideView from "./LearnGuideView.vue"
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
    global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } }
  })
  await flushPromises()
  return { wrapper, router }
}

describe("LearnGuideView", () => {
  it("ouvre le premier chapitre et liste tous les chapitres dans le sommaire", async () => {
    const { wrapper } = await mountGuide()
    expect(wrapper.text()).toContain(CHAPTERS[0].title)
    expect(wrapper.text()).toContain(`${CHAPTERS.length} chapitres`)
    expect(wrapper.findAll(".learn-toc-link")).toHaveLength(CHAPTERS.length)
  })

  it("navigue vers le chapitre suivant", async () => {
    const { wrapper, router } = await mountGuide()
    const next = wrapper.findAll("a").find((a) => a.text().includes(CHAPTERS[1].title))
    expect(next).toBeTruthy()
    await next.trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe(`/regles/debutant/${CHAPTERS[1].slug}`)
  })

  it("redirige /regles/debutant/apercu vers l'URL courte", async () => {
    const { router } = await mountGuide(`/regles/debutant/${DEFAULT_CHAPTER}`)
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/regles/debutant")
  })

  it("envoie les anciens ?etape= vers le plateau animé", async () => {
    const { router } = await mountGuide("/regles/debutant?etape=4")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/regles/debutant/plateau")
    expect(router.currentRoute.value.query.etape).toBe("4")
  })

  it("affiche la démo de runes sur le chapitre ressources", async () => {
    const { wrapper } = await mountGuide("/regles/debutant/runes")
    expect(wrapper.find(".learn-runes").exists()).toBe(true)
    expect(wrapper.text()).toContain("Énergie")
    expect(wrapper.text()).toContain("Essence Fureur")
  })

  it("agrandit une carte au double-clic et verrouille le défilement", async () => {
    const { wrapper } = await mountGuide()
    expect(wrapper.text()).not.toContain("Agrandir ")
    const type = wrapper.findAll(".learn-type")[0]
    await type.trigger("dblclick")
    await flushPromises()
    const zoom = document.body.querySelector(".tb-zoom.topic-zoom")
    expect(zoom).toBeTruthy()
    expect(document.body.classList.contains("nav-locked")).toBe(true)
    zoom.dispatchEvent(new MouseEvent("click", { bubbles: true }))
    await flushPromises()
    expect(document.body.querySelector(".tb-zoom.topic-zoom")).toBeNull()
    expect(document.body.classList.contains("nav-locked")).toBe(false)
  })
})
