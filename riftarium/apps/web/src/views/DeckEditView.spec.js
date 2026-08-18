import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import DeckEditView from "./DeckEditView.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function card(overrides) {
  return {
    riftbound_id: "ogn-000-298",
    type: "Unit",
    rarity: "Common",
    domains: ["Fury"],
    energy: 2,
    image_url: "https://cdn.example/c.png",
    orientation: null,
    text: "",
    owned_qty: 0,
    ...overrides
  }
}

const legend = card({
  id: "l1",
  riftbound_id: "ogn-247-298",
  name: "Légende Fury",
  type: "Legend",
  energy: null,
  owned_qty: 1
})
const legendCalm = card({
  id: "l2",
  riftbound_id: "ogn-248-298",
  name: "Légende Calm",
  type: "Legend",
  domains: ["Calm"],
  energy: null
})
const unit = card({
  id: "u1",
  riftbound_id: "ogn-037-298",
  name: "Phénix Immortel",
  rarity: "Epic",
  energy: 4,
  text: "[Assault 2]",
  owned_qty: 2
})
const ghost = card({ id: "g1", riftbound_id: "ogn-100-298", name: "Carte Fantôme", energy: 1 })
const calmUnit = card({
  id: "c1",
  riftbound_id: "ogn-078-298",
  name: "Moine du Calme",
  domains: ["Calm"],
  energy: 3,
  owned_qty: 1
})

function freshDeck() {
  return {
    id: 1,
    name: "Mon deck",
    description: "",
    format: "tournament",
    is_public: false,
    moderation_status: "published",
    likes: 0,
    liked_by_me: false,
    owner: "testeur",
    card_count: 0,
    cards: [],
    checks: [{ rule: "legend", ok: false, message: "Exactement 1 légende (0 actuellement)" }],
    updated_at: null
  }
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/decks", component: { template: "<div />" } },
      { path: "/decks/:id", component: DeckEditView },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  router.push("/decks/1")
  await router.isReady()
  const wrapper = mount(DeckEditView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

const tile = (wrapper, name) => wrapper.findAll(".gcard").find((t) => t.attributes("aria-label").includes(name))

describe("DeckEditView", () => {
  beforeEach(() => {
    session.token = "jeton-test"
    api.mockReset()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/1" && options.method === "PUT") {
        return Promise.resolve({
          checks: [{ rule: "legend", ok: true, message: "Exactement 1 légende (1 actuellement)" }],
          moderation_status: "published",
          updated_at: "2026-08-18T00:00:00"
        })
      }
      if (path === "/api/decks/1") return Promise.resolve(freshDeck())
      if (path === "/api/decks/1/missing") {
        return Promise.resolve({
          items: [{ card: unit, needed: 3, owned: 2, missing: 1 }],
          missing_total: 1,
          deck_total: 4
        })
      }
      if (path.startsWith("/api/cards")) {
        return Promise.resolve({ total: 5, page: 1, size: 24, items: [legend, legendCalm, unit, ghost, calmUnit] })
      }
      if (path === "/api/sets") return Promise.resolve([{ set_id: "OGN", name: "Origins" }])
      return Promise.resolve(null)
    })
  })

  afterEach(() => {
    session.token = null
  })

  it("sans légende : galerie ouverte sur les légendes, ajout d'une autre carte refusé", async () => {
    const { wrapper } = await mountView()
    // le deck vide force le filtre type=Legend (rechargement débouncé de la galerie)
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => path.startsWith("/api/cards") && path.includes("type=Legend"))).toBe(true)
    })
    expect(wrapper.find(".deck-hero.empty").text()).toContain("Choisissez votre légende")

    await tile(wrapper, "Phénix").trigger("click")
    expect(wrapper.find(".deck-limit").text()).toContain("Choisissez d'abord votre légende")
    expect(wrapper.findAll(".deck-row")).toHaveLength(0)
    wrapper.unmount()
  })

  it("légende choisie : vitrine avec runes, remplacement possible, hors-domaine bloqué", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    expect(wrapper.find(".deck-hero h3").text()).toBe("Légende Fury")
    expect(wrapper.findAll(".deck-hero-runes img")).toHaveLength(1)
    expect(wrapper.findAll(".deck-meters .meter")[0].text()).toContain("1")

    // même légende : refus
    await tile(wrapper, "Légende Fury").trigger("click")
    expect(wrapper.find(".deck-limit").text()).toContain("déjà dans le deck")

    // hors domaine : grisée et refusée
    const calmTile = tile(wrapper, "Moine du Calme")
    expect(calmTile.classes()).toContain("offdomain")
    await calmTile.trigger("click")
    expect(wrapper.find(".deck-limit").text()).toContain("hors des domaines")

    // autre légende : remplacement
    await tile(wrapper, "Légende Calm").trigger("click")
    expect(wrapper.find(".deck-hero h3").text()).toBe("Légende Calm")
    expect(wrapper.findAll(".deck-meters .meter")[0].text()).toContain("1")
    wrapper.unmount()
  })

  it("un clic ajoute la carte, plafond 3 exemplaires en tournoi", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    const unitTile = tile(wrapper, "Phénix")
    await unitTile.trigger("click")
    await unitTile.trigger("click")
    await unitTile.trigger("click")

    expect(wrapper.find(".deck-row .row-qty").text()).toBe("×3")
    expect(unitTile.find(".gcard-indeck").text()).toBe("3")
    expect(wrapper.findAll(".deck-meters .meter")[3].text()).toContain("3")

    await unitTile.trigger("click")
    expect(wrapper.find(".deck-limit").text()).toContain("Maximum 3 exemplaires")
    expect(wrapper.find(".deck-row .row-qty").text()).toBe("×3")
    wrapper.unmount()
  })

  it("galerie : possédées en couleur, manquantes grisées mais ajoutables", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    expect(tile(wrapper, "Phénix").classes()).not.toContain("unowned")
    expect(tile(wrapper, "Phénix").find(".gcard-owned").text()).toBe("×2")
    const ghostTile = tile(wrapper, "Carte Fantôme")
    expect(ghostTile.classes()).toContain("unowned")
    expect(ghostTile.find(".gcard-owned").text()).toBe("non possédée")

    await ghostTile.trigger("click")
    expect(wrapper.findAll(".deck-row .row-name").some((n) => n.text() === "Carte Fantôme")).toBe(true)
    wrapper.unmount()
  })

  it("signale les manquants et liste les cartes à trouver (sauvegarde déclenchée avant)", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    const unitTile = tile(wrapper, "Phénix")
    await unitTile.trigger("click")
    await unitTile.trigger("click")
    await unitTile.trigger("click")
    expect(wrapper.find(".deck-row.lacking .row-lack").exists()).toBe(true)

    await wrapper.get(".missing-btn").trigger("click")
    await flushPromises()
    const modal = document.body.querySelector(".modal")
    expect(modal).not.toBeNull()
    expect(modal.textContent).toContain("Phénix Immortel")
    expect(modal.querySelectorAll("tbody tr")).toHaveLength(1)
    expect(api.mock.calls.some(([path, options]) => path === "/api/decks/1" && options?.method === "PUT")).toBe(true)
    wrapper.unmount()
  })
})
