import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it } from "vitest"
import TraceursNotice from "./TraceursNotice.vue"
import { TRACEURS_ACK_KEY } from "../legal.js"

async function mountNotice(options = {}) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/cookies", component: { template: "<div />" } }
    ]
  })
  router.push("/")
  await router.isReady()
  return mount(TraceursNotice, { global: { plugins: [router] }, ...options })
}

describe("TraceursNotice", () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it("s'affiche tant que l'information n'a pas été lue", async () => {
    const wrapper = await mountNotice()
    const region = wrapper.get(".bandeau-traceurs")
    expect(region.attributes("role")).toBe("region")
    expect(region.attributes("aria-label")).toBe("Information sur les traceurs")
    /* Bandeau d'information : filet de bronze, pas d'action requise. */
    expect(region.classes()).toContain("bandeau-cadre--info")
    expect(wrapper.get(".bandeau-court").text()).toContain("Traceurs nécessaires")
    expect(wrapper.text()).toContain("strictement nécessaires")
    expect(wrapper.text()).toContain("statistiques de fréquentation anonymes et agrégées, sans cookie")
    expect(wrapper.get("a").attributes("href")).toBe("/cookies")
  })

  it("ne s'affiche plus quand le choix est déjà mémorisé", async () => {
    localStorage.setItem(TRACEURS_ACK_KEY, "1")
    const wrapper = await mountNotice()
    expect(wrapper.find(".bandeau-traceurs").exists()).toBe(false)
  })

  /* Sur téléphone le texte complet est masqué par le CSS : c'est ce bouton qui le
     rend, il doit donc annoncer l'état du dépliage et désigner le paragraphe. */
  it("déplie le texte complet et l'annonce", async () => {
    const wrapper = await mountNotice()
    const more = wrapper.get(".bandeau-plus")
    expect(more.attributes("aria-expanded")).toBe("false")
    expect(more.attributes("aria-controls")).toBe(wrapper.get(".bandeau-complet").attributes("id"))
    expect(wrapper.get(".bandeau-traceurs").classes()).not.toContain("bandeau-deplie")
    await more.trigger("click")
    expect(more.attributes("aria-expanded")).toBe("true")
    expect(more.text()).toBe("Réduire")
    expect(wrapper.get(".bandeau-traceurs").classes()).toContain("bandeau-deplie")
  })

  it("disparaît après J'ai compris et mémorise le choix", async () => {
    const wrapper = await mountNotice()
    await wrapper.get(".bandeau-ok").trigger("click")
    expect(wrapper.find(".bandeau-traceurs").exists()).toBe(false)
    expect(localStorage.getItem(TRACEURS_ACK_KEY)).toBe("1")
  })

  it("bandeau traceurs : focus dans le bandeau, choix mémorisé, bandeau fermé", async () => {
    const wrapper = await mountNotice({ attachTo: document.body })
    const ack = wrapper.get(".bandeau-ok")
    /* Vrai bouton, joignable au clavier, dans la région du bandeau. */
    expect(ack.element.tagName).toBe("BUTTON")
    ack.element.focus()
    expect(document.activeElement).toBe(ack.element)
    expect(wrapper.get(".bandeau-traceurs").element.contains(document.activeElement)).toBe(true)
    await ack.trigger("click")
    expect(localStorage.getItem(TRACEURS_ACK_KEY)).toBe("1")
    expect(wrapper.find(".bandeau-traceurs").exists()).toBe(false)
    expect(document.querySelector(".bandeau-traceurs")).toBeNull()
    wrapper.unmount()
  })

  it("stockage bloqué : le bandeau s'affiche et se ferme quand même", async () => {
    const saved = Object.getOwnPropertyDescriptor(globalThis, "localStorage")
    const blocked = () => {
      throw new Error("bloqué")
    }
    Object.defineProperty(globalThis, "localStorage", {
      configurable: true,
      value: { getItem: blocked, setItem: blocked, removeItem: blocked, clear() {} }
    })
    try {
      const wrapper = await mountNotice()
      expect(wrapper.find(".bandeau-traceurs").exists()).toBe(true)
      await wrapper.get(".bandeau-ok").trigger("click")
      expect(wrapper.find(".bandeau-traceurs").exists()).toBe(false)
    } finally {
      if (saved) Object.defineProperty(globalThis, "localStorage", saved)
      else delete globalThis.localStorage
    }
  })
})
