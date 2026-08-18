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
      { path: "/regles/debutant", component: BeginnerGuideView },
      { path: "/regles/avancee", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push("/regles/debutant")
  return mount(BeginnerGuideView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { reveal: {} } }
  })
}

describe("BeginnerGuideView", () => {
  it("démarre à la première étape et avance avec le bouton Suivant", async () => {
    const wrapper = await mountGuide()
    expect(wrapper.text()).toContain(`Étape 1 / ${STEPS.length}`)
    expect(wrapper.text()).toContain(STEPS[0].title)

    const next = wrapper.findAll("button").find((b) => b.text().includes("Suivant"))
    await next.trigger("click")
    expect(wrapper.text()).toContain(`Étape 2 / ${STEPS.length}`)
    expect(wrapper.text()).toContain(STEPS[1].title)
  })

  it("anime la scène : la dernière étape mène vers l'aide avancée", async () => {
    const wrapper = await mountGuide()
    const dots = wrapper.findAll(".guide-dot")
    expect(dots).toHaveLength(STEPS.length)
    await dots[STEPS.length - 1].trigger("click")
    expect(wrapper.text()).toContain(`Étape ${STEPS.length} / ${STEPS.length}`)
    const cta = wrapper.findAll("a").find((a) => a.attributes("href") === "/regles/avancee")
    expect(cta).toBeTruthy()
  })

  it("rend le plateau : zones, jetons et score", async () => {
    const wrapper = await mountGuide()
    expect(wrapper.findAll(".bd-zone").length).toBe(5)
    const dots = wrapper.findAll(".guide-dot")
    await dots[7].trigger("click")
    expect(wrapper.findAll(".bd-token").length).toBeGreaterThan(0)
    expect(wrapper.findAll(".bd-gem").length).toBe(16)
  })
})
