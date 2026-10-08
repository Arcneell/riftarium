import { mount } from "@vue/test-utils"
import fs from "node:fs"
import path from "node:path"
import { nextTick } from "vue"
import { afterEach, describe, expect, it, vi } from "vitest"
import App from "./App.vue"
import Icon from "./components/Icon.vue"
import { makeRouter } from "./test/makeRouter.js"

vi.mock("./search/search.js", async (importOriginal) => ({
  ...(await importOriginal()),
  runSearch: vi.fn(async () => [])
}))

function stubWidth(px) {
  window.matchMedia = (query) => ({
    matches: px <= Number(query.match(/max-width:\s*(\d+)px/)?.[1] ?? 0),
    addEventListener() {},
    removeEventListener() {}
  })
}

/* Chemins relatifs à la racine vitest (import.meta.url est une URL http sous jsdom). */
const walk = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name)
    return entry.isDirectory() ? walk(full) : [full]
  })

const original = window.matchMedia
async function mountApp(path = "/", px = 1440) {
  stubWidth(px)
  const router = await makeRouter(path)
  return mount(App, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
}

const keydown = (init, target = document.body) =>
  target.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, cancelable: true, ...init }))

describe("App (coquille)", () => {
  afterEach(() => {
    window.matchMedia = original
    localStorage.clear()
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked", "has-tabbar")
  })

  it("bureau : rail, pas d'onglets du bas", async () => {
    const wrapper = await mountApp("/cartes", 1440)
    expect(wrapper.find(".rail").exists()).toBe(true)
    expect(wrapper.find(".tabbar").exists()).toBe(false)
    wrapper.unmount()
  })

  it("téléphone : onglets du bas et sous-onglets de la rubrique, pas de rail", async () => {
    const wrapper = await mountApp("/regles/officielles", 390)
    expect(wrapper.find(".rail").exists()).toBe(false)
    expect(wrapper.find(".tabbar").exists()).toBe(true)
    expect(wrapper.find(".rift-tabs").text()).toContain("Texte officiel")
    wrapper.unmount()
  })

  it("rail replié (tablette) : les sous-pages restent accessibles par les onglets ; absentes rail déplié", async () => {
    const collapsed = await mountApp("/communaute", 900)
    expect(collapsed.find(".rift-tabs").exists()).toBe(true)
    expect(collapsed.get(".rift-tabs").text()).toContain("Communauté")
    collapsed.unmount()
    const expanded = await mountApp("/communaute", 1440)
    expect(expanded.find(".rift-tabs").exists()).toBe(false)
    expanded.unmount()
  })

  it("téléphone : body.has-tabbar décale les éléments flottants, retiré hors du palier mobile et au démontage", async () => {
    const wrapper = await mountApp("/", 390)
    expect(document.body.classList.contains("has-tabbar")).toBe(true)
    wrapper.unmount()
    expect(document.body.classList.contains("has-tabbar")).toBe(false)
    const desktop = await mountApp("/", 1440)
    expect(document.body.classList.contains("has-tabbar")).toBe(false)
    desktop.unmount()
  })

  it("tablette : rail replié par défaut ; le choix est mémorisé", async () => {
    const wrapper = await mountApp("/", 900)
    expect(wrapper.get(".rail").classes()).toContain("collapsed")
    await wrapper.get(".rail-collapse").trigger("click")
    expect(wrapper.get(".rail").classes()).not.toContain("collapsed")
    expect(localStorage.getItem("riftarium_rail_collapsed")).toBe("0")
    wrapper.unmount()
  })

  it("stockage bloqué : la coquille s'affiche quand même et le rail se replie", async () => {
    /* Navigation privée : tout accès à localStorage lève. On remplace l'objet entier
       (espionner Storage.prototype ne marche pas sous Node 26, où setup.js fournit un
       objet de remplacement qui n'est pas une instance de Storage). */
    const saved = Object.getOwnPropertyDescriptor(globalThis, "localStorage")
    const blocked = () => {
      throw new Error("bloqué")
    }
    Object.defineProperty(globalThis, "localStorage", {
      configurable: true,
      value: { getItem: blocked, setItem: blocked, removeItem: blocked, clear() {} }
    })
    try {
      const wrapper = await mountApp("/", 1440)
      expect(wrapper.get(".rail").classes()).not.toContain("collapsed")
      await wrapper.get(".rail-collapse").trigger("click")
      expect(wrapper.get(".rail").classes()).toContain("collapsed")
      wrapper.unmount()
    } finally {
      if (saved) Object.defineProperty(globalThis, "localStorage", saved)
      else delete globalThis.localStorage
    }
  })

  it("Ctrl+K ouvre la palette, Échap la ferme", async () => {
    const wrapper = await mountApp("/")
    keydown({ key: "k", ctrlKey: true })
    await nextTick()
    expect(document.querySelector(".palette")).not.toBeNull()
    keydown({ key: "Escape" })
    await nextTick()
    expect(document.querySelector(".palette")).toBeNull()
    wrapper.unmount()
  })

  it("une surcouche active (body.nav-locked) : Ctrl K et « / » n'ouvrent pas la palette", async () => {
    const wrapper = await mountApp("/")
    document.body.classList.add("nav-locked")
    keydown({ key: "k", ctrlKey: true })
    keydown({ key: "/" })
    await nextTick()
    expect(document.querySelector(".palette")).toBeNull()
    wrapper.unmount()
  })

  it("Ctrl K ferme la palette ouverte même si le défilement est verrouillé", async () => {
    const wrapper = await mountApp("/")
    keydown({ key: "k", ctrlKey: true })
    await nextTick()
    document.body.classList.add("nav-locked")
    keydown({ key: "k", ctrlKey: true })
    await nextTick()
    expect(document.querySelector(".palette")).toBeNull()
    wrapper.unmount()
  })

  it("avis hors ligne : role=status, en haut du contenu, effacé à la navigation suivante", async () => {
    const wrapper = await mountApp("/")
    expect(wrapper.find(".bandeau-horsligne").exists()).toBe(false)
    window.dispatchEvent(new Event("riftarium:offline-page"))
    await nextTick()
    const notice = wrapper.get(".bandeau-horsligne")
    expect(notice.attributes("role")).toBe("status")
    expect(notice.classes()).toContain("bandeau-cadre--info")
    expect(notice.text()).toContain("Hors ligne : cette page n'est pas disponible sans connexion.")
    /* Bandeaux globaux au-dessus du contenu de la page, pas dedans. */
    expect(wrapper.get(".shell-main").element.contains(notice.element)).toBe(true)
    expect(wrapper.get("#contenu").element.contains(notice.element)).toBe(false)
    await wrapper.vm.$router.push("/cartes")
    await nextTick()
    expect(wrapper.find(".bandeau-horsligne").exists()).toBe(false)
    wrapper.unmount()
  })

  it("bandeau des traceurs : en haut du contenu, avant la page", async () => {
    const wrapper = await mountApp("/")
    const notice = wrapper.get(".bandeau-traceurs")
    expect(wrapper.get(".shell-main").element.contains(notice.element)).toBe(true)
    expect(wrapper.get("#contenu").element.contains(notice.element)).toBe(false)
    wrapper.unmount()
  })

  it("App : aucune directive v-reveal / v-tilt enregistrée", async () => {
    const wrapper = await mountApp("/")
    const directives = wrapper.vm.$.appContext.directives
    expect(directives.reveal).toBeUndefined()
    expect(directives.tilt).toBeUndefined()
    wrapper.unmount()
    /* L'application réelle (main.js) n'en déclare plus, et aucun gabarit ne s'en sert. */
    const main = fs.readFileSync("src/main.js", "utf8")
    expect(main).not.toMatch(/\.directive\(/)
    const offenders = walk("src")
      .filter((file) => file.endsWith(".vue"))
      .filter((file) => /\sv-(reveal|tilt)\b/.test(fs.readFileSync(file, "utf8")))
    expect(offenders).toEqual([])
  })

  it("« / » ouvre la palette, sauf pendant une saisie", async () => {
    const wrapper = await mountApp("/")
    const field = document.createElement("input")
    document.body.appendChild(field)
    keydown({ key: "/" }, field)
    await nextTick()
    expect(document.querySelector(".palette")).toBeNull()
    keydown({ key: "/" })
    await nextTick()
    expect(document.querySelector(".palette")).not.toBeNull()
    wrapper.unmount()
  })
})
