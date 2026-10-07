import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, describe, expect, it, vi } from "vitest"
import BeginnerGuideView from "./BeginnerGuideView.vue"
import Icon from "../components/Icon.vue"
import { STEPS } from "../rules/guide.js"

const stub = { template: "<div />" }

async function mountGuide(path = "/regles/debutant/plateau") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: stub },
      { path: "/regles", component: stub },
      { path: "/regles/debutant", component: stub },
      { path: "/regles/debutant/plateau", component: BeginnerGuideView },
      { path: "/regles/avancee", component: stub },
      { path: "/regles/officielles", component: stub }
    ]
  })
  await router.push(path)
  const wrapper = mount(BeginnerGuideView, {
    attachTo: document.body,
    global: { plugins: [router], components: { Icon } }
  })
  await flushPromises()
  return { wrapper, router }
}

/* La modale de zoom est téléportée dans le body : on la cherche dans le document. */
const zoomDialog = () => document.querySelector("[role='dialog']")

afterEach(() => {
  document.body.innerHTML = ""
  document.body.classList.remove("nav-locked")
})

describe("BeginnerGuideView", () => {
  it("démarre à la première étape et avance avec le bouton Suivant", async () => {
    const { wrapper } = await mountGuide()
    expect(wrapper.text()).toContain(`Étape 1 / ${STEPS.length}`)
    expect(wrapper.text()).toContain(STEPS[0].title)
    expect(wrapper.find("h1").text()).toBe("Sur le plateau")

    const next = wrapper.findAll("button").find((b) => b.text().includes("Suivant"))
    await next.trigger("click")
    expect(wrapper.text()).toContain(`Étape 2 / ${STEPS.length}`)
    expect(wrapper.text()).toContain(STEPS[1].title)
    wrapper.unmount()
  })

  it("affiche les deux champs de bataille du duel avec de vraies cartes", async () => {
    const { wrapper } = await mountGuide()
    const dots = wrapper.findAll(".plateau-dot")
    await dots[1].trigger("click")
    const battlefields = wrapper.findAll(".plateau-bf")
    expect(battlefields).toHaveLength(2)
    const alts = wrapper.findAll(".plateau-bf img").map((i) => i.attributes("alt"))
    expect(alts).toContain("Back-Alley Bar")
    expect(alts).toContain("Monastery of Hirana")
    await dots[3].trigger("click")
    expect(wrapper.findAll(".plateau-card--inhand").length).toBeGreaterThanOrEqual(4)
    const imgs = wrapper.findAll(".plateau-card img").map((i) => i.attributes("src"))
    expect(imgs.some((src) => src.includes("cmsassets.rgpub.io"))).toBe(true)
    wrapper.unmount()
  })

  it("emploie les termes officiels et mène vers l'aide avancée en dernière étape", async () => {
    const { wrapper } = await mountGuide()
    const dots = wrapper.findAll(".plateau-dot")
    expect(dots).toHaveLength(STEPS.length)
    await dots[4].trigger("click")
    expect(wrapper.text()).toContain("canaliser")
    expect(wrapper.findAll(".plateau-terms .rift-chip").length).toBe(STEPS[4].terms.length)
    await dots[STEPS.length - 1].trigger("click")
    expect(wrapper.text()).toContain(`Étape ${STEPS.length} / ${STEPS.length}`)
    const cta = wrapper.findAll("a").find((a) => a.attributes("href") === "/regles/avancee")
    expect(cta).toBeTruthy()
    expect(cta.text()).toContain("Passer à l'aide avancée")
    expect(wrapper.findAll(".plateau-gem")).toHaveLength(16)
    wrapper.unmount()
  })

  it("rend le gras du texte d'étape sans v-html", async () => {
    const { wrapper } = await mountGuide()
    const bold = wrapper.findAll(".plateau-text b").map((b) => b.text())
    expect(bold).toContain("deck principal")
    expect(wrapper.find(".plateau-text").text()).not.toContain("**")
    wrapper.unmount()
  })

  it("bascule le mode plein écran", async () => {
    const { wrapper } = await mountGuide()
    const button = wrapper.find(".plateau-fullscreen")
    expect(button.text()).toContain("Plein écran")
    expect(button.attributes("aria-pressed")).toBe("false")
    await button.trigger("click")
    expect(wrapper.find(".plateau-layout").classes()).toContain("plateau-layout--full")
    expect(button.attributes("aria-pressed")).toBe("true")
    await button.trigger("click")
    expect(wrapper.find(".plateau-layout").classes()).not.toContain("plateau-layout--full")
    wrapper.unmount()
  })

  it("le plein écran cible document.documentElement et se quitte au démontage", async () => {
    const requestFullscreen = vi.fn(() => Promise.resolve())
    const exitFullscreen = vi.fn(() => Promise.resolve())
    const original = Object.getOwnPropertyDescriptor(Document.prototype, "fullscreenElement")
    Object.defineProperty(document.documentElement, "requestFullscreen", {
      value: requestFullscreen,
      configurable: true
    })
    document.exitFullscreen = exitFullscreen
    const { wrapper } = await mountGuide()
    await wrapper.find(".plateau-fullscreen").trigger("click")
    expect(requestFullscreen).toHaveBeenCalledTimes(1)
    expect(requestFullscreen.mock.contexts[0]).toBe(document.documentElement)

    /* Démontage avec un élément en plein écran : on le quitte. */
    Object.defineProperty(document, "fullscreenElement", { value: document.documentElement, configurable: true })
    wrapper.unmount()
    expect(exitFullscreen).toHaveBeenCalledTimes(1)

    delete document.fullscreenElement
    if (original) Object.defineProperty(Document.prototype, "fullscreenElement", original)
    delete document.exitFullscreen
    delete document.documentElement.requestFullscreen
  })

  it("suit le retour arrière du navigateur sur ?etape=", async () => {
    const { wrapper, router } = await mountGuide()
    const dots = wrapper.findAll(".plateau-dot")
    await dots[3].trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.query.etape).toBe("4")

    /* Retour arrière : l'adresse redevient l'étape 1, le guide doit suivre. */
    await router.replace({ query: {} })
    await flushPromises()
    expect(wrapper.text()).toContain(`Étape 1 / ${STEPS.length}`)

    await router.replace({ query: { etape: "6" } })
    await flushPromises()
    expect(wrapper.text()).toContain(`Étape 6 / ${STEPS.length}`)
    wrapper.unmount()
  })

  it("les pastilles d'étape ne se déclarent pas onglets", async () => {
    const { wrapper } = await mountGuide()
    const dots = wrapper.findAll(".plateau-dot")
    expect(dots[0].attributes("role")).toBeUndefined()
    expect(dots[0].attributes("aria-current")).toBe("true")
    expect(dots[1].attributes("aria-current")).toBeUndefined()
    expect(dots[0].attributes("aria-label")).toBe(STEPS[0].title)
    expect(wrapper.find(".plateau-dots").attributes("role")).toBe("group")
    wrapper.unmount()
  })

  it("Échap ferme le zoom d'une carte", async () => {
    const { wrapper } = await mountGuide()
    await wrapper.findAll(".plateau-dot")[3].trigger("click")
    await wrapper.findAll("button.plateau-card")[0].trigger("click")
    await flushPromises()
    expect(zoomDialog()).not.toBeNull()
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    await flushPromises()
    expect(zoomDialog()).toBeNull()
    wrapper.unmount()
  })

  it("Échap ferme le zoom avant le plein écran", async () => {
    const { wrapper } = await mountGuide()
    await wrapper.find(".plateau-fullscreen").trigger("click")
    const layout = wrapper.find(".plateau-layout")
    expect(layout.classes()).toContain("plateau-layout--full")
    await wrapper.findAll(".plateau-dot")[3].trigger("click")
    await wrapper.findAll("button.plateau-card")[0].trigger("click")
    await flushPromises()
    expect(zoomDialog()).not.toBeNull()

    /* Pire cas : l'Échap part du conteneur (focus resté sur le plateau). Il remonte
       jusqu'à document, où useDialog ferme le zoom ; le plein écran doit rester. */
    layout.element.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await flushPromises()
    expect(zoomDialog()).toBeNull()
    expect(layout.classes()).toContain("plateau-layout--full")

    /* Depuis la modale (focus piégé dedans, hors du conteneur) : même résultat. */
    await wrapper.findAll("button.plateau-card")[0].trigger("click")
    await flushPromises()
    zoomDialog().dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await flushPromises()
    expect(zoomDialog()).toBeNull()
    expect(layout.classes()).toContain("plateau-layout--full")

    /* Échap suivant : plus de zoom, on quitte le plein écran. */
    await layout.trigger("keydown", { key: "Escape" })
    expect(layout.classes()).not.toContain("plateau-layout--full")
    wrapper.unmount()
  })

  it("les flèches du clavier naviguent, sauf depuis un champ de saisie", async () => {
    const { wrapper } = await mountGuide()
    const layout = wrapper.find(".plateau-layout")
    await layout.trigger("keydown", { key: "ArrowRight" })
    expect(wrapper.text()).toContain(`Étape 2 / ${STEPS.length}`)

    /* Depuis un bouton du panneau (focus après un clic sur Suivant) : on navigue. */
    const dot = wrapper.findAll(".plateau-dot")[0]
    await dot.trigger("keydown", { key: "ArrowRight" })
    expect(wrapper.text()).toContain(`Étape 3 / ${STEPS.length}`)
    await dot.trigger("keydown", { key: "ArrowLeft" })
    expect(wrapper.text()).toContain(`Étape 2 / ${STEPS.length}`)

    /* La page n'a pas de champ : on en glisse un pour vérifier la garde. */
    const input = document.createElement("input")
    layout.element.appendChild(input)
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true }))
    await flushPromises()
    expect(wrapper.text()).toContain(`Étape 2 / ${STEPS.length}`)
    input.remove()
    wrapper.unmount()
  })

  it("ouvre directement une étape via ?etape=", async () => {
    const { wrapper } = await mountGuide("/regles/debutant/plateau?etape=13")
    expect(wrapper.text()).toContain(`Étape 13 / ${STEPS.length}`)
    expect(wrapper.text()).toContain("attaquant")
    wrapper.unmount()
  })

  it("propose le guide en chapitres et l'aide avancée en bas de page", async () => {
    const { wrapper } = await mountGuide()
    const titles = wrapper.findAll(".plateau-links h2").map((h) => h.text())
    expect(titles).toEqual(["Guide en chapitres", "Aide avancée"])
    expect(wrapper.find(".plateau-links a[href='/regles/debutant']").exists()).toBe(true)
    wrapper.unmount()
  })
})
