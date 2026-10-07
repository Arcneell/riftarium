import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import DeckEditView from "./DeckEditView.vue"
import DeckView from "../decks/DeckView.vue"
import viewSource from "./DeckEditView.vue?raw"
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

/* Réponses par défaut ; `deck` remplace le deck renvoyé par GET /api/decks/1. */
function mockApi(deck = freshDeck()) {
  api.mockImplementation((path, options = {}) => {
    if (path === "/api/decks/1" && options.method === "PUT") {
      return Promise.resolve({
        checks: [{ rule: "legend", ok: true, message: "Exactement 1 légende (1 actuellement)" }],
        moderation_status: "published",
        updated_at: "2026-08-18T00:00:00"
      })
    }
    if (path === "/api/decks/1") return Promise.resolve(deck)
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
}

/* matchMedia simulé : largeur de fenêtre (requêtes max-width), pointeur précis et
   réduction des animations (jsdom n'a pas Element.animate : le vol du fantôme est coupé). */
const originalMatchMedia = window.matchMedia
function stubMedia({ width = 1440, fine = false, reduced = true } = {}) {
  window.matchMedia = (query) => {
    const text = String(query)
    const max = text.match(/max-width:\s*(\d+)px/)
    let matches = false
    if (max) matches = width <= Number(max[1])
    else if (text.includes("hover: hover") || text.includes("pointer: fine")) matches = fine
    else if (text.includes("prefers-reduced-motion")) matches = reduced
    return {
      matches,
      media: query,
      addEventListener() {},
      removeEventListener() {},
      addListener() {},
      removeListener() {},
      dispatchEvent() {
        return false
      }
    }
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

const tile = (wrapper, name) => wrapper.findAll(".galerie-card").find((t) => t.attributes("aria-label").includes(name))
/* Le lien « ℹ » est un frère du bouton (un lien dans un bouton est du HTML invalide) : on passe par la cellule. */
const slot = (wrapper, name) =>
  wrapper.findAll(".galerie-slot").find((cell) => cell.get(".galerie-card").attributes("aria-label").includes(name))
const missingButton = (wrapper) => wrapper.findAll("button").find((b) => b.text() === "Trouver les cartes manquantes")
const pane = (wrapper, name) => wrapper.get(`.atelier-pane--${name}`)
const hidden = (element) => element.attributes("style")?.includes("display: none") ?? false
const tabButton = (wrapper, value) => wrapper.get(`#atelier-tab-${value}`)
/* Appui souris sur une tuile (jsdom : MouseEvent, pointerType absent donc pas « touch »). */
const pressOn = async (target, x, y) => {
  target.element.dispatchEvent(new MouseEvent("pointerdown", { button: 0, clientX: x, clientY: y, bubbles: true }))
  await flushPromises()
}
const pointer = (type, x, y) => window.dispatchEvent(new MouseEvent(type, { clientX: x, clientY: y, bubbles: true }))

describe("DeckEditView", () => {
  beforeEach(() => {
    stubMedia()
    session.token = "jeton-test"
    session.handle = "testeur"
    api.mockReset()
    mockApi()
  })

  afterEach(() => {
    session.token = null
    session.handle = null
    window.matchMedia = originalMatchMedia
    document.body.innerHTML = ""
    document.body.className = ""
  })

  it("format : RiftChoice bascule légal / illégal", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    const group = wrapper.get('.atelier-bar [role="radiogroup"]')
    expect(group.attributes("aria-label")).toBe("Format")
    const radio = (label) => group.findAll('[role="radio"]').find((r) => r.text() === label)
    expect(radio("Légal").attributes("aria-checked")).toBe("true")
    expect(tile(wrapper, "Moine du Calme").classes()).toContain("offdomain")

    // la page applique update:format : hors tournoi, plus de hachures hors domaine
    await radio("Illégal").trigger("click")
    expect(radio("Illégal").attributes("aria-checked")).toBe("true")
    expect(radio("Légal").attributes("aria-checked")).toBe("false")
    expect(tile(wrapper, "Moine du Calme").classes()).not.toContain("offdomain")

    // re-cliquer sur l'option active ne laisse jamais le deck sans format
    await radio("Illégal").trigger("click")
    expect(radio("Illégal").attributes("aria-checked")).toBe("true")

    await radio("Légal").trigger("click")
    expect(tile(wrapper, "Moine du Calme").classes()).toContain("offdomain")
    wrapper.unmount()
  })

  it("nom et visibilité : la page applique ce qu'émet la barre", async () => {
    const { wrapper } = await mountView()
    await wrapper.get("input.atelier-name").setValue("Fureur rouge")
    expect(wrapper.get("input.atelier-name").element.value).toBe("Fureur rouge")
    const publicChip = wrapper.findAll(".atelier-bar button").find((b) => b.text() === "Public")
    expect(publicChip.attributes("aria-pressed")).toBe("false")
    await publicChip.trigger("click")
    expect(publicChip.attributes("aria-pressed")).toBe("true")
    wrapper.unmount()
    const put = api.mock.calls.find(([path, options]) => path === "/api/decks/1" && options?.method === "PUT")
    expect(put[1].body).toMatchObject({ name: "Fureur rouge", is_public: true })
  })

  it("sans légende : galerie ouverte sur les légendes, ajout d'une autre carte refusé", async () => {
    const { wrapper } = await mountView()
    // le deck vide force le filtre type=Legend (rechargement débouncé de la galerie)
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => path.startsWith("/api/cards") && path.includes("type=Legend"))).toBe(true)
    })
    expect(wrapper.find(".decklist-hero--empty").text()).toContain("Choisissez votre légende")

    await tile(wrapper, "Phénix").trigger("click")
    expect(wrapper.find(".decklist-message").text()).toContain("Choisissez d'abord votre légende")
    expect(wrapper.findAll(".decklist-row")).toHaveLength(0)
    wrapper.unmount()
  })

  it("légende choisie : vitrine avec runes, remplacement possible, hors-domaine bloqué", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    expect(wrapper.find(".decklist-hero-name").text()).toBe("Légende Fury")
    expect(wrapper.findAll(".decklist-hero-runes img")).toHaveLength(1)
    expect(wrapper.findAll(".decklist-meter")[0].text()).toContain("1")

    // même légende : refus
    await tile(wrapper, "Légende Fury").trigger("click")
    expect(wrapper.find(".decklist-message").text()).toContain("déjà dans le deck")

    // hors domaine : grisée et refusée
    const calmTile = tile(wrapper, "Moine du Calme")
    expect(calmTile.classes()).toContain("offdomain")
    await calmTile.trigger("click")
    expect(wrapper.find(".decklist-message").text()).toContain("hors des domaines")

    // autre légende : remplacement
    await tile(wrapper, "Légende Calm").trigger("click")
    expect(wrapper.find(".decklist-hero-name").text()).toBe("Légende Calm")
    expect(wrapper.findAll(".decklist-meter")[0].text()).toContain("1")
    wrapper.unmount()
  })

  it("un clic ajoute la carte, plafond 3 exemplaires en tournoi", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    const unitTile = tile(wrapper, "Phénix")
    await unitTile.trigger("click")
    await unitTile.trigger("click")
    await unitTile.trigger("click")

    expect(wrapper.find(".decklist-row .decklist-qty").text()).toBe("×3")
    expect(unitTile.find(".galerie-indeck").text()).toBe("3")
    expect(wrapper.findAll(".decklist-meter")[1].text()).toContain("3")

    await unitTile.trigger("click")
    expect(wrapper.find(".decklist-message").text()).toContain("Maximum 3 exemplaires")
    expect(wrapper.find(".decklist-row .decklist-qty").text()).toBe("×3")
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
    expect(wrapper.find(".decklist-message").text()).toContain("Maximum 3 exemplaires")
    expect(wrapper.findAll(".decklist-row")).toHaveLength(1)
    wrapper.unmount()
  })

  it("galerie : possédées en couleur, manquantes grisées mais ajoutables", async () => {
    const { wrapper } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")
    expect(tile(wrapper, "Phénix").classes()).not.toContain("unowned")
    expect(tile(wrapper, "Phénix").find(".galerie-owned").text()).toBe("×2")
    const ghostTile = tile(wrapper, "Carte Fantôme")
    expect(ghostTile.classes()).toContain("unowned")
    /* Manquante : pas de pastille du tout, la vignette grisée porte l'information. */
    expect(ghostTile.find(".galerie-owned").exists()).toBe(false)

    await ghostTile.trigger("click")
    expect(wrapper.findAll(".decklist-row .decklist-name").some((n) => n.text() === "Carte Fantôme")).toBe(true)
    wrapper.unmount()
  })

  it("tactile : le bouton « ℹ » ouvre la fiche de la carte sans l'ajouter au deck", async () => {
    const { wrapper, router } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")

    const info = slot(wrapper, "Phénix").get(".galerie-info")
    expect(info.attributes("aria-label")).toContain("Voir la fiche")
    /* Vrai lien, atteignable au clavier, et hors du bouton d'ajout. */
    expect(info.element.tagName).toBe("A")
    expect(info.attributes("href")).toBe("/cartes/u1")
    expect(slot(wrapper, "Phénix").get(".galerie-card").find(".galerie-info").exists()).toBe(false)

    await info.trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/cartes/u1")
    // le clic ne remonte pas jusqu'à la tuile : la carte n'est pas ajoutée (seule la légende est là)
    expect(wrapper.findAll(".decklist-row")).toHaveLength(0)
    wrapper.unmount()
  })

  it("validation, coût, description et cartes manquantes sont dans l'analyse, pas dans la zone de dépôt", async () => {
    const { wrapper } = await mountView()
    const analysis = pane(wrapper, "stats")
    const dropZone = wrapper.get(".decklist")
    expect(analysis.find(".analyse-checks").exists()).toBe(true)
    expect(analysis.find(".analyse-curve").exists()).toBe(true)
    expect(analysis.findAll("button").some((b) => b.text() === "Trouver les cartes manquantes")).toBe(true)
    const desc = analysis.get("textarea.atelier-desc")
    expect(desc.attributes("aria-label")).toBe("Description du deck")
    expect(analysis.text()).toContain("Énergie")
    expect(dropZone.find(".analyse-checks").exists()).toBe(false)
    expect(dropZone.find(".analyse-curve").exists()).toBe(false)
    expect(dropZone.findAll("button").some((b) => b.text() === "Trouver les cartes manquantes")).toBe(false)
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
    /* Texte lisible au doigt : le « ! » n'était explicité que par une infobulle. */
    expect(wrapper.get(".decklist-row.lacking .decklist-lack").text()).toBe("manque 1")

    await missingButton(wrapper).trigger("click")
    await flushPromises()
    const modal = document.body.querySelector(".rift-modal")
    expect(modal).not.toBeNull()
    expect(modal.textContent).toContain("Phénix Immortel")
    expect(modal.querySelectorAll(".atelier-missing-list .atelier-missing-item")).toHaveLength(1)
    expect(api.mock.calls.some(([path, options]) => path === "/api/decks/1" && options?.method === "PUT")).toBe(true)
    /* La sauvegarde part avant la lecture des manquantes. */
    const putIndex = api.mock.calls.findIndex(([path, options]) => path === "/api/decks/1" && options?.method === "PUT")
    const missingIndex = api.mock.calls.findIndex(([path]) => path === "/api/decks/1/missing")
    expect(putIndex).toBeLessThan(missingIndex)
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
    expect(pane(wrapper, "stats").text()).toContain("30,50")
    expect(tile(wrapper, "Phénix").get(".galerie-price").text()).toContain("4,50")

    await missingButton(wrapper).trigger("click")
    await flushPromises()
    const modal = document.body.querySelector(".rift-modal")
    expect(modal.textContent).toContain("Coût pour compléter :")
    expect(modal.textContent).toContain("4,50")
    wrapper.unmount()
  })

  it("affiche la carte en grand au survol du nom ou de la vignette manquante", async () => {
    stubMedia({ fine: true })
    const { wrapper } = await mountView()
    await missingButton(wrapper).trigger("click")
    await flushPromises()

    const thumb = document.body.querySelector(".atelier-missing-list .atelier-missing-thumb")
    const nameCell = document.body.querySelector(".atelier-missing-list .atelier-missing-copy")
    expect(thumb).not.toBeNull()
    expect(nameCell).not.toBeNull()

    thumb.dispatchEvent(new MouseEvent("mouseenter"))
    await flushPromises()
    let preview = document.body.querySelector(".atelier-preview.atelier-preview--large img")
    expect(preview).not.toBeNull()
    expect(preview.getAttribute("src")).toContain("cdn.example")
    /* Téléporté dans le body, sans les anciennes classes de main.css. */
    expect(preview.closest(".atelier-preview").parentElement).toBe(document.body)
    expect(document.body.querySelector(".builder-preview")).toBeNull()

    thumb.dispatchEvent(new MouseEvent("mouseleave"))
    await flushPromises()
    expect(document.body.querySelector(".atelier-preview")).toBeNull()

    nameCell.dispatchEvent(new MouseEvent("mouseenter"))
    await flushPromises()
    preview = document.body.querySelector(".atelier-preview.atelier-preview--large img")
    expect(preview).not.toBeNull()

    nameCell.dispatchEvent(new MouseEvent("mouseleave"))
    await flushPromises()
    expect(document.body.querySelector(".atelier-preview")).toBeNull()
    wrapper.unmount()
  })

  it("navigation sortante : le deck n'est pas vidé et le save de secours part au démontage", async () => {
    const { wrapper, router } = await mountView()
    await tile(wrapper, "Légende Fury").trigger("click")

    // transition out-in : l'id de route devient undefined, le brouillon doit rester affiché
    router.push("/decks")
    await flushPromises()
    expect(wrapper.find(".atelier-name").exists()).toBe(true)
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
    await missingButton(wrapper).trigger("click")
    await flushPromises()

    expect(wrapper.find(".galerie").exists()).toBe(true) // pas de bascule en lecture seule
    expect(wrapper.findComponent(DeckView).exists()).toBe(false)
    expect(wrapper.get(".decklist-hero-name").text()).toBe("Légende Fury") // brouillon conservé
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
    expect(wrapper.find(".galerie").exists()).toBe(false)
    expect(wrapper.find(".atelier").exists()).toBe(false)
    expect(wrapper.find(".lecture").exists()).toBe(true)
    expect(wrapper.find(".lecture-visual").exists()).toBe(true)
    expect(wrapper.get(".lecture-back").text()).toContain("Communauté")
    expect(wrapper.text()).toContain("Liste Rift Atlas")
    expect(wrapper.findComponent(DeckView).props("likeBusy")).toBe(false)
    expect(api.mock.calls.some(([path, options]) => path === "/api/decks/1/view" && options?.method === "POST")).toBe(
      true
    )
    await vi.waitFor(() => expect(wrapper.text()).toContain("3"))
    wrapper.unmount()
  })

  /* ---------- Onglets sur téléphone, colonnes sur bureau ---------- */

  it("téléphone : trois onglets, panneaux montés, ajout depuis Cartes met à jour le badge Deck", async () => {
    stubMedia({ width: 375 })
    const { wrapper } = await mountView()
    const tablist = wrapper.get('[role="tablist"]')
    expect(tablist.findAll('[role="tab"]').map((t) => t.text())).toEqual(["Cartes", "Deck 0", "Analyse ✕"])

    for (const name of ["cards", "deck", "stats"]) {
      const panel = pane(wrapper, name)
      expect(panel.attributes("role")).toBe("tabpanel")
      expect(panel.attributes("id")).toBe(`atelier-panel-${name}`)
      expect(panel.attributes("aria-labelledby")).toBe(`atelier-tab-${name}`)
      expect(tabButton(wrapper, name).attributes("aria-controls")).toBe(`atelier-panel-${name}`)
    }
    // les panneaux restent montés, masqués par v-show
    expect(hidden(pane(wrapper, "cards"))).toBe(false)
    expect(hidden(pane(wrapper, "deck"))).toBe(true)
    expect(hidden(pane(wrapper, "stats"))).toBe(true)
    expect(pane(wrapper, "deck").find(".decklist").exists()).toBe(true)
    expect(pane(wrapper, "stats").find(".analyse-curve").exists()).toBe(true)

    await tile(wrapper, "Légende Fury").trigger("click")
    await tile(wrapper, "Phénix").trigger("click")
    await tile(wrapper, "Phénix").trigger("click")
    expect(tabButton(wrapper, "deck").get(".rift-segments-badge").text()).toBe("3")

    await tabButton(wrapper, "deck").trigger("click")
    expect(hidden(pane(wrapper, "deck"))).toBe(false)
    expect(hidden(pane(wrapper, "cards"))).toBe(true)
    expect(tabButton(wrapper, "deck").attributes("aria-selected")).toBe("true")
    wrapper.unmount()
  })

  it("téléphone : le message de plafond reste visible hors de l'onglet Deck", async () => {
    stubMedia({ width: 375 })
    const { wrapper } = await mountView()
    expect(wrapper.find(".atelier-toast").exists()).toBe(false)
    await tile(wrapper, "Phénix").trigger("click")
    const toast = wrapper.get(".atelier-toast")
    expect(toast.attributes("role")).toBe("status")
    expect(toast.text()).toContain("Choisissez d'abord votre légende")

    // sur l'onglet Deck, la liste porte déjà le message : pas de toast en double
    await tabButton(wrapper, "deck").trigger("click")
    expect(wrapper.find(".atelier-toast").exists()).toBe(false)
    expect(wrapper.get(".decklist-message").text()).toContain("Choisissez d'abord votre légende")
    wrapper.unmount()
  })

  it("téléphone : onglet par défaut Deck avec légende, Cartes sans légende", async () => {
    stubMedia({ width: 375 })
    const first = await mountView()
    expect(tabButton(first.wrapper, "cards").attributes("aria-selected")).toBe("true")
    expect(hidden(pane(first.wrapper, "cards"))).toBe(false)
    first.wrapper.unmount()

    mockApi({ ...freshDeck(), cards: [{ card: legend, qty: 1 }] })
    const second = await mountView()
    expect(tabButton(second.wrapper, "deck").attributes("aria-selected")).toBe("true")
    expect(hidden(pane(second.wrapper, "deck"))).toBe(false)
    expect(hidden(pane(second.wrapper, "cards"))).toBe(true)
    second.wrapper.unmount()
  })

  it("téléphone : Voir les légendes bascule sur Cartes et filtre les légendes", async () => {
    stubMedia({ width: 375 })
    mockApi({ ...freshDeck(), cards: [{ card: legend, qty: 1 }] })
    const { wrapper } = await mountView()
    expect(tabButton(wrapper, "deck").attributes("aria-selected")).toBe("true")
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/cards") && path.includes("type=Legend"))).toBe(false)

    // la légende retirée, la vitrine vide propose « Voir les légendes »
    await wrapper.get(".decklist-hero-remove").trigger("click")
    const show = wrapper.findAll(".decklist button").find((b) => b.text() === "Voir les légendes")
    await show.trigger("click")
    expect(tabButton(wrapper, "cards").attributes("aria-selected")).toBe("true")
    expect(hidden(pane(wrapper, "cards"))).toBe(false)
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => path.startsWith("/api/cards") && path.includes("type=Legend"))).toBe(true)
    })
    wrapper.unmount()
  })

  it("bureau : pas de tablist, trois panneaux visibles", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.find('[role="tablist"]').exists()).toBe(false)
    for (const name of ["cards", "deck", "stats"]) {
      const panel = pane(wrapper, name)
      expect(hidden(panel)).toBe(false)
      expect(panel.attributes("role")).toBeUndefined()
      expect(panel.attributes("id")).toBeUndefined()
      expect(panel.attributes("aria-labelledby")).toBeUndefined()
    }
    wrapper.unmount()
  })

  it("mise en page : trois colonnes au-delà de 1 280 px, deux en dessous, liste et analyse collantes", () => {
    const css = viewSource.slice(viewSource.indexOf("<style"))
    expect(css).toMatch(/\.atelier \{[^}]*grid-template-columns: minmax\(0, 1fr\) 340px 300px/)
    expect(css).toMatch(/@media \(max-width: 1279px\)[\s\S]*?grid-template-columns: minmax\(0, 1fr\) 340px;/)
    expect(css).toMatch(/\.atelier-pane--deck,\s*\.atelier-pane--stats \{[^}]*position: sticky/)
    expect(css).not.toMatch(/drag-ghost|builder-preview/)
  })

  /* ---------- Glisser-déposer ---------- */

  it("glisser une tuile de la galerie et la déposer sur la liste l'ajoute au deck", async () => {
    stubMedia({ fine: true })
    const { wrapper } = await mountView()
    const list = wrapper.get(".decklist").element
    list.getBoundingClientRect = () => ({ left: 500, right: 800, top: 0, bottom: 600, width: 300, height: 600 })

    await pressOn(tile(wrapper, "Légende Fury"), 100, 100)
    pointer("pointermove", 140, 120)
    await flushPromises()
    expect(document.body.classList).toContain("drag-active")
    const ghostEl = document.body.querySelector(".atelier-ghost")
    expect(ghostEl).not.toBeNull()
    expect(ghostEl.parentElement).toBe(document.body)
    expect(document.body.querySelector(".drag-ghost")).toBeNull()

    pointer("pointermove", 600, 300)
    await flushPromises()
    expect(wrapper.get(".decklist").classes()).toContain("decklist-hot")
    expect(document.body.querySelector(".atelier-ghost").classList).toContain("atelier-ghost--over")

    pointer("pointerup", 600, 300)
    await flushPromises()
    expect(wrapper.get(".decklist-hero-name").text()).toBe("Légende Fury")
    expect(document.body.classList).not.toContain("drag-active")
    expect(document.body.querySelector(".atelier-ghost")).toBeNull()

    // le clic qui suit un vrai glissement n'ajoute pas une seconde fois
    await tile(wrapper, "Phénix").trigger("click")
    expect(wrapper.findAll(".decklist-row")).toHaveLength(1)
    wrapper.unmount()
  })

  it("démontage pendant un glisser : écouteurs retirés", async () => {
    stubMedia({ fine: true })
    const { wrapper } = await mountView()
    await pressOn(tile(wrapper, "Légende Fury"), 100, 100)
    pointer("pointermove", 160, 140)
    await flushPromises()
    expect(document.body.classList).toContain("drag-active")

    const removed = vi.spyOn(window, "removeEventListener")
    wrapper.unmount()
    const types = removed.mock.calls.map(([type]) => type)
    expect(types).toContain("pointermove")
    expect(types).toContain("pointerup")
    expect(document.body.classList).not.toContain("drag-active")
    removed.mockRestore()

    // un relâchement tardif ne fait plus rien (aucune sauvegarde déclenchée par un ajout fantôme)
    const callsBefore = api.mock.calls.length
    pointer("pointerup", 600, 300)
    await flushPromises()
    expect(api.mock.calls.length).toBe(callsBefore)
  })

  it("deck vide : analyse sans NaN", async () => {
    mockApi({ ...freshDeck(), checks: [] })
    const { wrapper } = await mountView()
    const analysis = pane(wrapper, "stats")
    expect(analysis.text()).not.toContain("NaN")
    expect(analysis.html()).not.toContain("NaN")
    expect(wrapper.get(".decklist").html()).not.toContain("NaN")
    expect(analysis.text()).toContain("0")
    wrapper.unmount()
  })
})
