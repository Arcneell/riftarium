import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import BeginnerGuideView from "./BeginnerGuideView.vue"
import { STEPS } from "../rules/guide.js"

const stub = { template: "<div />" }

async function mountGuide() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: stub },
      { path: "/regles", component: stub },
      { path: "/regles/debutant", component: BeginnerGuideView },
      { path: "/regles/avancee", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push("/regles/debutant")
  const wrapper = mount(BeginnerGuideView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } }
  })
  return { wrapper, router }
}

describe("BeginnerGuideView", () => {
  it("démarre à la première étape et avance avec le bouton Suivant", async () => {
    const { wrapper } = await mountGuide()
    expect(wrapper.text()).toContain(`Étape 1 / ${STEPS.length}`)
    expect(wrapper.text()).toContain(STEPS[0].title)

    const next = wrapper.findAll("button").find((b) => b.text().includes("Suivant"))
    await next.trigger("click")
    expect(wrapper.text()).toContain(`Étape 2 / ${STEPS.length}`)
    expect(wrapper.text()).toContain(STEPS[1].title)
  })

  it("affiche les deux champs de bataille du duel avec de vraies cartes", async () => {
    const { wrapper } = await mountGuide()
    const dots = wrapper.findAll(".guide-dot")
    await dots[1].trigger("click")
    const battlefields = wrapper.findAll(".tb-bf")
    expect(battlefields).toHaveLength(2)
    expect(wrapper.text()).toContain("Fortified Position")
    expect(wrapper.text()).toContain("Monastery of Hirana")
    const imgs = wrapper.findAll(".tb-card img").map((i) => i.attributes("src"))
    expect(imgs.some((src) => src.includes("cmsassets.rgpub.io"))).toBe(true)
  })

  it("emploie les termes officiels et mène vers l'aide avancée en dernière étape", async () => {
    const { wrapper } = await mountGuide()
    const dots = wrapper.findAll(".guide-dot")
    expect(dots).toHaveLength(STEPS.length)
    await dots[3].trigger("click")
    expect(wrapper.text()).toContain("canaliser")
    await dots[STEPS.length - 1].trigger("click")
    expect(wrapper.text()).toContain(`Étape ${STEPS.length} / ${STEPS.length}`)
    const cta = wrapper.findAll("a").find((a) => a.attributes("href") === "/regles/avancee")
    expect(cta).toBeTruthy()
    expect(wrapper.findAll(".tb-gem")).toHaveLength(16)
  })

  it("bascule le mode plein écran", async () => {
    const { wrapper } = await mountGuide()
    const button = wrapper.find(".guide-fullscreen")
    expect(button.text()).toContain("Plein écran")
    await button.trigger("click")
    expect(wrapper.find(".guide-layout").classes()).toContain("full")
    await button.trigger("click")
    expect(wrapper.find(".guide-layout").classes()).not.toContain("full")
  })

  it("ouvre directement une étape via ?etape=", async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: "/regles", component: stub },
        { path: "/regles/debutant", component: BeginnerGuideView },
        { path: "/regles/avancee", component: stub },
        { path: "/regles/officielles", component: stub }
      ]
    })
    await router.push("/regles/debutant?etape=8")
    const wrapper = mount(BeginnerGuideView, {
      global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } }
    })
    expect(wrapper.text()).toContain(`Étape 8 / ${STEPS.length}`)
    expect(wrapper.text()).toContain("attaquant")
  })
})
