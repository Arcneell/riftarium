import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import CardsView from "./CardsView.vue"
import { api } from "../api.js"
import { makeRouter } from "../test/makeRouter.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function fakeCard(index) {
  return {
    id: `card-${index}`,
    riftbound_id: `ogn-00${index}-298`,
    name: `Carte ${index}`,
    image_url: `https://cdn.example/${index}.png`,
    domains: ["Fury"],
    type: "Unit",
    rarity: "Epic"
  }
}

function viewport(width, height) {
  window.innerWidth = width
  window.innerHeight = height
}

const originalMatchMedia = window.matchMedia
function stubWidth(px) {
  window.matchMedia = (query) => ({
    matches: px <= Number(query.match(/max-width:\s*(\d+)px/)?.[1] ?? 0),
    addEventListener() {},
    removeEventListener() {}
  })
}

async function mountView(path = "/cartes") {
  const router = await makeRouter(path)
  const wrapper = mount(CardsView, {
    global: { plugins: [router], stubs: { Icon: true } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

const facet = (wrapper, legend) =>
  wrapper.findAll("fieldset.facet").find((node) => node.get("legend").text() === legend)
const SETS = [
  { set_id: "ogn", name: "Origins" },
  { set_id: "sfd", name: "Spiritforged" }
]

describe("CardsView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve(SETS)
      return Promise.resolve({ total: 300, page: 1, size: 30, items: [fakeCard(1), fakeCard(2)] })
    })
  })

  afterEach(() => {
    viewport(1024, 768)
    window.matchMedia = originalMatchMedia
    document.body.innerHTML = ""
  })

  it("propose les raretés officielles dans l'ordre du jeu", async () => {
    const { wrapper } = await mountView()
    const labels = facet(wrapper, "Raretés")
      .findAll("button.rift-chip")
      .map((button) => button.text().trim())
    expect(labels).toEqual(["Commun", "Peu commun", "Rare", "Épique", "Showcase", "Promo"])
    wrapper.unmount()
  })

  it("affiche les runes officielles dans le filtre des domaines", async () => {
    const { wrapper } = await mountView()
    const runes = facet(wrapper, "Domaines").findAll("button.rift-chip img.rb-glyph.rune")
    expect(runes).toHaveLength(6)
    expect(runes[0].attributes("src")).toContain("rune_fury.svg")
    wrapper.unmount()
  })

  it("charge plus de cartes sur un grand écran que sur mobile", async () => {
    const requestedSize = () => {
      const call = api.mock.calls.map(([path]) => path).findLast((path) => path.startsWith("/api/cards"))
      return Number(new URL(call, "http://x").searchParams.get("size"))
    }

    viewport(1920, 1200)
    const { wrapper: large } = await mountView()
    const largeSize = requestedSize()
    large.unmount()

    api.mockClear()
    viewport(390, 780)
    const { wrapper: small } = await mountView()
    const smallSize = requestedSize()
    small.unmount()

    expect(largeSize).toBeGreaterThan(smallSize)
    expect(smallSize).toBeGreaterThanOrEqual(8)
  })

  it("aucun résultat : la page le dit et propose de réinitialiser les filtres", async () => {
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve(SETS)
      return Promise.resolve({ total: 0, page: 1, size: 30, items: [] })
    })
    const { wrapper } = await mountView("/cartes?q=zzz")

    const empty = wrapper.get(".rift-empty")
    expect(empty.text()).toContain("Aucune carte ne correspond")
    await empty.get("button").trigger("click")
    await flushPromises()
    expect(wrapper.get(".card-filters input").element.value).toBe("")
    wrapper.unmount()
  })

  it("répercute les filtres choisis dans l'URL et dans la requête", async () => {
    const { wrapper, router } = await mountView()
    await facet(wrapper, "Domaines").get("button.rift-chip").trigger("click")
    await flushPromises()
    await vi.waitFor(() => expect(router.currentRoute.value.query.domain).toBe("Fury"))
    await vi.waitFor(() => expect(api.mock.calls.at(-1)[0]).toContain("domain=Fury"))
    wrapper.unmount()
  })

  it("une URL avec filtres (lien du mur de l'accueil) s'affiche en puces actives", async () => {
    const { wrapper } = await mountView("/cartes?set=sfd&domain=Fury")
    const labels = wrapper
      .get(".active-filters")
      .findAll("button.rift-chip")
      .map((chip) => chip.text())
    expect(labels.some((label) => label.includes("Fureur"))).toBe(true)
    expect(labels.some((label) => label.includes("Spiritforged"))).toBe(true)
    expect(api.mock.calls.some(([path]) => path.includes("domain=Fury") && path.includes("set_id=sfd"))).toBe(true)
    wrapper.unmount()
  })

  it("téléphone : bouton Filtres (N), feuille qui reste ouverte au changement, fermée par « Voir les N cartes »", async () => {
    stubWidth(390)
    viewport(390, 780)
    const { wrapper } = await mountView("/cartes?domain=Fury")
    expect(wrapper.find(".filters-panel").exists()).toBe(false)
    const open = wrapper.findAll("button").find((button) => button.text().startsWith("Filtres"))
    expect(open.text().replace(/\s+/g, " ")).toBe("Filtres (1)")
    await open.trigger("click")

    const sheet = () => document.body.querySelector(".rift-sheet")
    expect(sheet()).not.toBeNull()
    const rarity = [...sheet().querySelectorAll("fieldset.facet")].find(
      (node) => node.querySelector("legend").textContent === "Raretés"
    )
    rarity.querySelector("button.rift-chip").click()
    await flushPromises()
    expect(sheet()).not.toBeNull()
    await vi.waitFor(() => expect(api.mock.calls.at(-1)[0]).toContain("rarity=Common"))

    const done = [...sheet().querySelectorAll("button")].find((button) =>
      /^Voir les \d+ cartes$/.test(button.textContent.trim())
    )
    expect(done.textContent.trim()).toBe("Voir les 300 cartes")
    done.click()
    await flushPromises()
    expect(sheet()).toBeNull()
    wrapper.unmount()
  })

  it("premier chargement : squelettes ; rechargement : grille atténuée, pas vidée", async () => {
    let release
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve(SETS)
      return new Promise((resolve) => {
        release = resolve
      })
    })
    const { wrapper } = await mountView()
    expect(wrapper.findAll(".rift-skeleton")).toHaveLength(12)
    expect(wrapper.findAll(".cards-grid")).toHaveLength(1)
    release({ total: 2, page: 1, size: 30, items: [fakeCard(1), fakeCard(2)] })
    await flushPromises()
    expect(wrapper.findAll(".rift-skeleton")).toHaveLength(0)
    expect(wrapper.findAll(".rift-tile")).toHaveLength(2)
    expect(wrapper.get(".cards-grid").classes()).not.toContain("reloading")

    await facet(wrapper, "Domaines").get("button.rift-chip").trigger("click")
    await vi.waitFor(() => expect(wrapper.find(".cards-grid.reloading").exists()).toBe(true))
    expect(wrapper.findAll(".rift-tile")).toHaveLength(2)
    expect(wrapper.findAll(".rift-skeleton")).toHaveLength(0)
    release({ total: 1, page: 1, size: 30, items: [fakeCard(1)] })
    await flushPromises()
    expect(wrapper.find(".cards-grid.reloading").exists()).toBe(false)
    wrapper.unmount()
  })
})
