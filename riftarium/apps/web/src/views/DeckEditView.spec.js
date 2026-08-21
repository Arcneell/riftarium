import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import DeckEditView from "./DeckEditView.vue"
import { api, ApiError, session } from "../api.js"

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
    price_eur: null,
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
  owned_qty: 2,
  price_eur: 4.5
})
const phoenixOn = card({
  id: "u1-on",
  riftbound_id: "sfd-037-221",
  name: "Phénix Immortel (Overnumbered)",
  rarity: "Epic",
  energy: 4,
  owned_qty: 0
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
    views: 0,
    owner: "testeur",
    card_count: 0,
    cards: [],
    checks: [{ rule: "legend", ok: false, message: "Exactement 1 légende (0 actuellement)" }],
    prices: null,
    updated_at: null
  }
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/decks", component: { template: "<div />" } },
      { path: "/decks/:id", component: DeckEditView },
      { path: "/cartes/:id", component: { template: "<div />" } },
      { path: "/communaute", component: { template: "<div />" } },
      { path: "/connexion", component: { template: "<div />" } }
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
    session.handle = "testeur"
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
        return Promise.resolve({
          total: 6,
          page: 1,
          size: 24,
          items: [legend, legendCalm, unit, phoenixOn, ghost, calmUnit]
        })
      }
      if (path === "/api/sets") return Promise.resolve([{ set_id: "OGN", name: "Origins" }])
      return Promise.resolve(null)
    })
  })

  afterEach(() => {
    session.token = null
    session.handle = null
  })

  it("format : sélecteur au style des filtres, bascule légal / illégal", async () => {
    const { wrapper } = await mountView()
    const button = wrapper.get(".dbuilder-bar .fsel-btn")
    expect(button.text()).toContain("Format")
    expect(button.get(".fsel-single").text()).toBe("Légal")

    await button.trigger("click")
    expect(wrapper.find(".dbuilder-bar .fsel-clear").exists()).toBe(false) // un deck a toujours un format
    const illegal = wrapper.findAll(".dbuilder-bar .fsel-opt").find((o) => o.text() === "Illégal")
    await illegal.trigger("click")
    expect(wrapper.get(".dbuilder-bar .fsel-btn .fsel-single").text()).toBe("Illégal")

    // re-cliquer sur l'option active ne laisse jamais le deck sans format
    await wrapper.get(".dbuilder-bar .fsel-btn").trigger("click")
    await wrapper
      .findAll(".dbuilder-bar .fsel-opt")
      .find((o) => o.text() === "Illégal")
      .trigger("click")
    expect(wrapper.get(".dbuilder-bar .fsel-btn .fsel-single").text()).toBe("Illégal")
    wrapper.unmount()
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

  it("plafond 3 exemplaires : reprints et overnumbered comptent comme la même carte", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    const unitTile = tile(wrapper, "Phénix Immortel")
    await unitTile.trigger("click")
    await unitTile.trigger("click")
    await unitTile.trigger("click")

    const reprint = tile(wrapper, "Overnumbered")
    await reprint.trigger("click")
    expect(wrapper.find(".deck-limit").text()).toContain("Maximum 3 exemplaires")
    expect(wrapper.findAll(".deck-row")).toHaveLength(1)
    wrapper.unmount()
  })

  it("galerie : possédées en couleur, manquantes grisées mais ajoutables", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    expect(tile(wrapper, "Phénix").classes()).not.toContain("unowned")
    expect(tile(wrapper, "Phénix").find(".gcard-owned").text()).toBe("×2")
    const ghostTile = tile(wrapper, "Carte Fantôme")
    expect(ghostTile.classes()).toContain("unowned")
    /* Manquante : pas de pastille du tout, la vignette grisée porte l'information. */
    expect(ghostTile.find(".gcard-owned").exists()).toBe(false)

    await ghostTile.trigger("click")
    expect(wrapper.findAll(".deck-row .row-name").some((n) => n.text() === "Carte Fantôme")).toBe(true)
    wrapper.unmount()
  })

  it("tactile : le bouton « ℹ » ouvre la fiche de la carte sans l'ajouter au deck", async () => {
    const { wrapper, router } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")

    const info = tile(wrapper, "Phénix").get(".gcard-info")
    expect(info.attributes("aria-label")).toContain("Voir la fiche")

    await info.trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/cartes/u1")
    // le clic ne remonte pas jusqu'à la tuile : la carte n'est pas ajoutée
    expect(wrapper.findAll(".deck-row")).toHaveLength(0)
    wrapper.unmount()
  })

  it("validation, coût, description et cartes manquantes sont sur la page, pas dans la zone de dépôt", async () => {
    const { wrapper } = await mountView()
    const overview = wrapper.get(".dbuilder-overview")
    const dropZone = wrapper.get(".dbuilder-deck")
    expect(overview.find(".validator").exists()).toBe(true)
    expect(overview.find(".curve").exists()).toBe(true)
    expect(overview.find(".missing-btn").exists()).toBe(true)
    expect(overview.find("textarea").exists()).toBe(true)
    expect(overview.text()).toContain("énergie")
    expect(dropZone.find(".validator").exists()).toBe(false)
    expect(dropZone.find(".curve").exists()).toBe(false)
    expect(dropZone.find(".missing-btn").exists()).toBe(false)
    expect(dropZone.find("textarea").exists()).toBe(false)
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

  it("affiche la valeur du deck, la pastille € de la galerie et le coût des manquants", async () => {
    const pricedDeck = {
      ...freshDeck(),
      cards: [
        { card: legend, qty: 1 },
        { card: unit, qty: 3 }
      ],
      prices: { total_eur: 30.5, missing_eur: 4.5 }
    }
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/1" && options.method === "PUT") {
        return Promise.resolve({ checks: [], moderation_status: "published", updated_at: "2026-08-18T00:00:00" })
      }
      if (path === "/api/decks/1") return Promise.resolve(pricedDeck)
      if (path === "/api/decks/1/missing") {
        return Promise.resolve({
          items: [{ card: unit, needed: 3, owned: 2, missing: 1 }],
          missing_total: 1,
          deck_total: 4
        })
      }
      if (path.startsWith("/api/cards")) return Promise.resolve({ total: 1, page: 1, size: 24, items: [unit] })
      if (path === "/api/sets") return Promise.resolve([])
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    expect(wrapper.get(".dbuilder-overview .price-deck").text()).toContain("30,50")
    expect(tile(wrapper, "Phénix").get(".gcard-price").text()).toContain("4,50")

    await wrapper.get(".missing-btn").trigger("click")
    await flushPromises()
    const modal = document.body.querySelector(".modal")
    expect(modal.textContent).toContain("Coût pour compléter :")
    expect(modal.textContent).toContain("4,50")
    wrapper.unmount()
  })

  it("affiche la carte en grand au survol du nom ou de la vignette manquante", async () => {
    window.matchMedia = (query) => ({
      matches: String(query).includes("hover: hover") || String(query).includes("pointer: fine"),
      media: query,
      addEventListener() {},
      removeEventListener() {},
      addListener() {},
      removeListener() {},
      dispatchEvent() {
        return false
      }
    })
    const { wrapper } = await mountView()
    await wrapper.get(".missing-btn").trigger("click")
    await flushPromises()

    const thumb = document.body.querySelector(".missing-table .row-thumb")
    const nameCell = document.body.querySelector(".missing-table td.missing-zoom")
    expect(thumb).not.toBeNull()
    expect(nameCell).not.toBeNull()

    thumb.dispatchEvent(new MouseEvent("mouseenter"))
    await flushPromises()
    let preview = document.body.querySelector(".builder-preview.large img")
    expect(preview).not.toBeNull()
    expect(preview.getAttribute("src")).toContain("cdn.example")

    thumb.dispatchEvent(new MouseEvent("mouseleave"))
    await flushPromises()
    expect(document.body.querySelector(".builder-preview")).toBeNull()

    nameCell.dispatchEvent(new MouseEvent("mouseenter"))
    await flushPromises()
    preview = document.body.querySelector(".builder-preview.large img")
    expect(preview).not.toBeNull()

    nameCell.dispatchEvent(new MouseEvent("mouseleave"))
    await flushPromises()
    expect(document.body.querySelector(".builder-preview")).toBeNull()
    wrapper.unmount()
  })

  it("navigation sortante : le deck n'est pas vidé et le save de secours part au démontage", async () => {
    const { wrapper, router } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")

    // transition out-in : l'id de route devient undefined, le brouillon doit rester affiché
    router.push("/decks")
    await flushPromises()
    expect(wrapper.find(".dbuilder-name").exists()).toBe(true)
    expect(api.mock.calls.every(([path]) => !String(path).includes("undefined"))).toBe(true)
    expect(api.mock.calls.some(([path, options]) => path === "/api/decks/1" && options?.method === "PUT")).toBe(false)

    // le démontage déclenche la sauvegarde de rattrapage avant toute remise à zéro
    wrapper.unmount()
    expect(api.mock.calls.some(([path, options]) => path === "/api/decks/1" && options?.method === "PUT")).toBe(true)
  })

  it("beforeunload : demande confirmation seulement s'il reste des modifications non sauvegardées", async () => {
    const { wrapper } = await mountView()

    const clean = new Event("beforeunload", { cancelable: true })
    window.dispatchEvent(clean)
    expect(clean.defaultPrevented).toBe(false)

    await tile(wrapper, "Légende Fury").trigger("click")
    const dirty = new Event("beforeunload", { cancelable: true })
    window.dispatchEvent(dirty)
    expect(dirty.defaultPrevented).toBe(true)

    wrapper.unmount()
    const after = new Event("beforeunload", { cancelable: true })
    window.dispatchEvent(after)
    expect(after.defaultPrevented).toBe(false)
  })

  it("session expirée pendant l'édition : le brouillon reste affiché avec un message clair", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")

    api.mockImplementation((path, options = {}) => {
      if (options.method === "PUT" || options.method === "POST") {
        // comme api() le fait sur un vrai 401 : session locale fermée + rejet
        session.token = null
        session.handle = null
        return Promise.reject(new ApiError(401, "Connexion requise"))
      }
      if (path === "/api/decks/1/missing") return Promise.reject(new ApiError(401, "Connexion requise"))
      if (path.startsWith("/api/cards")) return Promise.resolve({ total: 0, page: 1, size: 24, items: [] })
      return Promise.resolve(null)
    })

    // openMissing déclenche la sauvegarde immédiatement (pas d'attente du débounce)
    await wrapper.get(".missing-btn").trigger("click")
    await flushPromises()

    expect(wrapper.find(".dbuilder-gallery").exists()).toBe(true) // pas de bascule en lecture seule
    expect(wrapper.get(".deck-hero h3").text()).toBe("Légende Fury") // brouillon conservé
    expect(wrapper.text()).toContain("Session expirée, reconnectez-vous")
    wrapper.unmount()
  })

  it("en consultation publique : pas de galerie, une vue est comptée", async () => {
    session.token = null
    session.handle = null
    const publicDeck = {
      ...freshDeck(),
      owner: "autre",
      is_public: true,
      moderation_status: "published",
      views: 2,
      cards: [{ card: legend, qty: 1 }]
    }
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/1/view" && options.method === "POST") {
        return Promise.resolve({ views: 3, counted: true })
      }
      if (path === "/api/decks/1") return Promise.resolve(publicDeck)
      if (path.startsWith("/api/cards")) return Promise.resolve({ total: 0, page: 1, size: 24, items: [] })
      if (path === "/api/sets") return Promise.resolve([])
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    expect(wrapper.find(".dbuilder-gallery").exists()).toBe(false)
    expect(wrapper.find(".dbuilder.readonly").exists()).toBe(false)
    expect(wrapper.find(".deck-view").exists()).toBe(true)
    expect(wrapper.find(".dvis").exists()).toBe(true)
    expect(wrapper.get(".dbuilder-back").text()).toContain("Communauté")
    expect(wrapper.text()).toContain("Liste Rift Atlas")
    expect(api.mock.calls.some(([path, options]) => path === "/api/decks/1/view" && options?.method === "POST")).toBe(
      true
    )
    await vi.waitFor(() => expect(wrapper.text()).toContain("3"))
    wrapper.unmount()
  })
})
