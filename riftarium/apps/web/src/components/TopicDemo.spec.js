import { mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import TopicDemo from "./TopicDemo.vue"

const demo = {
  title: "La chaîne",
  frames: [
    { caption: "Le sort entre dans la chaîne.", items: [{ k: "a", type: "card", x: 50, y: 60, label: "Sort" }] },
    { caption: "L'adversaire répond.", items: [{ k: "b", type: "card", x: 50, y: 40, label: "Réponse" }] },
    { caption: "La chaîne se résout.", items: [{ k: "c", type: "chip", x: 50, y: 50, n: 1 }] }
  ]
}

/* matchMedia mocké : `reduced` pilote prefers-reduced-motion, lu au montage. */
function stubMatchMedia(reduced = false) {
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query) => ({
      matches: reduced && String(query).includes("prefers-reduced-motion"),
      media: query,
      addEventListener() {},
      removeEventListener() {},
      addListener() {},
      removeListener() {},
      dispatchEvent() {
        return false
      }
    }))
  )
}

describe("TopicDemo", () => {
  beforeEach(() => {
    stubMatchMedia()
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it("ne pose role=img que sur la scène, pour ne pas masquer les boutons de la barre", () => {
    const wrapper = mount(TopicDemo, { props: { demo } })
    expect(wrapper.get(".demo").attributes("role")).toBeUndefined()
    const stage = wrapper.get(".demo-stage")
    expect(stage.attributes("role")).toBe("img")
    expect(stage.attributes("aria-label")).toBe("La chaîne")
    wrapper.unmount()
  })

  it("le bouton lecture/pause arrête et relance le défilement automatique", async () => {
    const wrapper = mount(TopicDemo, { props: { demo } })
    const play = wrapper.get(".demo-play")
    expect(play.attributes("aria-pressed")).toBe("true")
    expect(play.attributes("aria-label")).toContain("pause")

    vi.advanceTimersByTime(2600)
    await wrapper.vm.$nextTick()
    expect(wrapper.get(".demo-caption").text()).toBe("L'adversaire répond.")

    /* En pause, la scène ne bouge plus : au doigt on a le temps de lire la légende. */
    await play.trigger("click")
    expect(play.attributes("aria-pressed")).toBe("false")
    expect(play.attributes("aria-label")).toContain("Lire")
    vi.advanceTimersByTime(10000)
    await wrapper.vm.$nextTick()
    expect(wrapper.get(".demo-caption").text()).toBe("L'adversaire répond.")

    await play.trigger("click")
    vi.advanceTimersByTime(2600)
    await wrapper.vm.$nextTick()
    expect(wrapper.get(".demo-caption").text()).toBe("La chaîne se résout.")
    wrapper.unmount()
  })

  it("les points restent utilisables et ne relancent pas la lecture quand elle est en pause", async () => {
    const wrapper = mount(TopicDemo, { props: { demo } })
    await wrapper.get(".demo-play").trigger("click")

    await wrapper.findAll(".demo-dot")[2].trigger("click")
    expect(wrapper.get(".demo-caption").text()).toBe("La chaîne se résout.")

    vi.advanceTimersByTime(10000)
    await wrapper.vm.$nextTick()
    expect(wrapper.get(".demo-caption").text()).toBe("La chaîne se résout.")
    wrapper.unmount()
  })

  it("mouvement réduit : la scène démarre en pause, le bouton permet de la lancer", async () => {
    stubMatchMedia(true)
    const wrapper = mount(TopicDemo, { props: { demo } })
    const play = wrapper.get(".demo-play")
    expect(play.attributes("aria-pressed")).toBe("false")

    vi.advanceTimersByTime(10000)
    await wrapper.vm.$nextTick()
    expect(wrapper.get(".demo-caption").text()).toBe("Le sort entre dans la chaîne.")

    await play.trigger("click")
    vi.advanceTimersByTime(2600)
    await wrapper.vm.$nextTick()
    expect(wrapper.get(".demo-caption").text()).toBe("L'adversaire répond.")
    wrapper.unmount()
  })
})
