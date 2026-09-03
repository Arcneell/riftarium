import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import HomeView from "./HomeView.vue"
import { api } from "../api.js"
import { BANNERS } from "../banners.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

/* L'éventail du héros est conditionné à la media query desktop : on la pilote
   explicitement, sinon jsdom répond « pas de correspondance » à tout. */
function stubMatchMedia(wide) {
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query) => ({
      matches: wide && String(query).includes("min-width: 761px"),
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

function mountHome() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: HomeView },
      { path: "/cartes", component: { template: "<div />" } },
      { path: "/regles", component: { template: "<div />" } },
      { path: "/decks", component: { template: "<div />" } },
      { path: "/collection", component: { template: "<div />" } },
      { path: "/communaute", component: { template: "<div />" } },
      { path: "/scan", component: { template: "<div />" } },
      { path: "/wishlist", component: { template: "<div />" } }
    ]
  })
  return mount(HomeView, {
    global: {
      plugins: [router],
      stubs: {
        CardRiver: { template: '<div class="river-stub" />' },
        Icon: true
      },
      directives: { tilt: {}, reveal: {} }
    }
  })
}

describe("HomeView", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    /* Les vues montées sans démontage laissent leur <link rel=preload> : le
       <head> de jsdom est partagé par tous les tests du fichier. */
    document.head.querySelectorAll('link[rel="preload"]').forEach((node) => node.remove())
  })

  /* Trois cartes portrait fictives retournées par le mock de l'API fan. */
  const FAN_MOCK = [
    { id: "ahri-1", orientation: "portrait", image_url: "https://cdn.example.com/ahri.png" },
    { id: "leesin-1", orientation: "portrait", image_url: "https://cdn.example.com/leesin.png" },
    { id: "kaisa-1", orientation: "portrait", image_url: "https://cdn.example.com/kaisa.png" }
  ]

  beforeEach(() => {
    stubMatchMedia(true)
    api.mockReset()
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve([{ set_id: "OGN" }, { set_id: "SFD" }])
      if (path === "/api/cards?size=1") return Promise.resolve({ total: 1315, items: [] })
      if (path.startsWith("/api/cards?size=12")) return Promise.resolve({ total: 1315, items: FAN_MOCK })
      return Promise.resolve({})
    })
  })

  it("affiche trois cartes portrait depuis l'API avec le reflet foil", async () => {
    const wrapper = mountHome()
    await flushPromises()

    const fan = wrapper.get(".hero-fan")
    expect(fan.attributes("aria-hidden")).toBe("true")
    expect(wrapper.findAll(".fan-card")).toHaveLength(3)
    expect(wrapper.findAll(".fan-foil")).toHaveLength(3)
    /* La bêta fermée n'est pas annoncée sur l'accueil (badge d'en-tête + mentions légales seulement). */
    expect(wrapper.text()).not.toContain("Bêta fermée")

    /* Les sources viennent de l'API (image_url redimensionnée via cardThumb). */
    const sources = wrapper.findAll(".fan-card img").map((img) => img.attributes("src"))
    for (const card of FAN_MOCK) {
      expect(sources.some((src) => src.includes(card.image_url) && src.includes("w=460"))).toBe(true)
    }
  })

  it("précharge la cinématique du héros au montage et retire la balise au démontage", async () => {
    const wrapper = mountHome()
    await flushPromises()

    const link = document.head.querySelector('link[rel="preload"][as="image"]')
    expect(link).not.toBeNull()
    expect(link.getAttribute("href")).toBe(BANNERS.home)

    wrapper.unmount()
    expect(document.head.querySelector('link[rel="preload"][as="image"]')).toBeNull()
  })

  it("déroule les salles de la vitrine avec leurs liens et la Règle d'or", async () => {
    const wrapper = mountHome()
    await flushPromises()

    expect(wrapper.findAll(".hall-art")).toHaveLength(3)
    for (const to of ["/cartes", "/decks", "/communaute", "/collection", "/scan", "/wishlist", "/regles"]) {
      expect(wrapper.find(`a[href="${to}"]`).exists()).toBe(true)
    }
    expect(wrapper.text()).toContain("Règle d'or")
  })

  it("sur téléphone, l'éventail décoratif n'est pas rendu du tout (aucune image téléchargée)", async () => {
    stubMatchMedia(false)
    const wrapper = mountHome()
    await flushPromises()

    expect(wrapper.find(".hero-fan").exists()).toBe(false)
    expect(wrapper.findAll(".fan-card img")).toHaveLength(0)
    /* Le reste du héros, lui, reste en place. */
    expect(wrapper.text()).toContain("Vos cartes, vos decks,")
  })
})
