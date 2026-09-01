import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import PublicProfileView from "./PublicProfileView.vue"
import { ApiError, api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const LEGEND = { id: "leg-1", name: "Jinx", type: "Legend", domains: ["Fury"], image_url: "https://cdn.example/j.png" }

const CARD = {
  id: "ogn-001",
  riftbound_id: "ogn-001",
  name: "Poro glouton",
  image_url: "https://cdn.example/poro.png",
  type: "Unit",
  rarity: "Common",
  domains: ["Body"]
}

const HISTORY_ITEM = {
  match_id: 31,
  mode: "duel",
  status: "confirmed",
  played_at: "2026-08-12T19:30:00Z",
  opponent: { handle: "kai", avatar_url: null },
  my_legend: LEGEND,
  opponent_legend: null,
  my_deck: null,
  opponent_deck: null,
  my_score: 8,
  opponent_score: 3,
  my_rounds: 1,
  opponent_rounds: 0,
  outcome: "win"
}

function makeProfile(over = {}) {
  return {
    id: 3,
    handle: "nova",
    avatar_url: "https://cdn.example/nova.png",
    bio: "Main Ahri, La Réunion",
    created_at: "2026-01-15T10:00:00Z",
    is_me: false,
    is_followed: false,
    followers_count: 2,
    following_count: 5,
    visibility: { show_stats: true, show_collection: true, show_decks: true, show_achievements: true },
    stats: {
      totals: { played: 10, won: 6, lost: 4 },
      by_legend: [{ card_id: "leg-1", name: "Jinx", image_url: LEGEND.image_url, played: 5, won: 4, lost: 1 }]
    },
    achievements: [
      {
        key: "first_blood",
        family: "duels",
        title: "Premier sang",
        description: "Remporter un duel suivi.",
        icon: "emoji_events",
        tier: "bronze",
        threshold: 1,
        current: 1,
        unlocked_at: "2026-08-01T10:00:00Z"
      }
    ],
    collection_summary: {
      unique_cards: 120,
      total_cards: 300,
      sets: [{ set_id: "ogn", name: "Origines", owned: 50, total: 200 }]
    },
    decks: [{ id: 7, name: "Fureur de Noxus", format: "tournament", likes: 3, legend: LEGEND }],
    ...over
  }
}

function setupApi(profile = makeProfile()) {
  api.mockImplementation((path) => {
    if (path === "/api/users/nova") return Promise.resolve(profile)
    if (path.startsWith("/api/users/nova/collection"))
      return Promise.resolve({ total: 1, page: 1, size: 24, items: [{ card: CARD, total_qty: 3 }] })
    if (path.startsWith("/api/users/nova/history")) return Promise.resolve({ total: 1, page: 1, items: [HISTORY_ITEM] })
    return Promise.resolve(null)
  })
}

const called = (fragment) => api.mock.calls.some(([path]) => String(path).includes(fragment))

async function mountView(path = "/u/nova") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/u/:handle", component: PublicProfileView },
      { path: "/profil", component: { template: "<div />" } },
      { path: "/connexion", component: { template: "<div />" } },
      { path: "/decks/:id", component: { template: "<div />" } },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  router.push(path)
  await router.isReady()
  const wrapper = mount(PublicProfileView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

const buttonWith = (wrapper, label) => wrapper.findAll("button").find((button) => button.text().includes(label))

describe("PublicProfileView", () => {
  beforeEach(() => {
    session.token = "jeton-test"
    session.handle = "moi"
    api.mockReset()
    setupApi()
  })

  it("affiche l'en-tête du joueur et toutes ses sections autorisées", async () => {
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/users/nova")

    const hero = wrapper.get(".profile-hero")
    expect(hero.text()).toContain("nova")
    expect(hero.text()).toContain("Main Ahri")
    expect(hero.text()).toContain("Membre depuis janvier 2026")
    expect(hero.text()).toContain("2 abonné(s)")
    expect(hero.text()).toContain("5 suivi(s)")

    /* Hauts faits débloqués, en médaillons colorés par palier. */
    const medal = wrapper.get(".medal")
    expect(medal.text()).toContain("Premier sang")
    expect(medal.classes()).toContain("tier-bronze")

    /* Duels : totaux, top légendes et historique du point de vue du profil. */
    expect(wrapper.text()).toContain("Taux de victoire")
    expect(wrapper.get(".play-legend-name").text()).toBe("Jinx")
    expect(called("/api/users/nova/history")).toBe(true)
    const row = wrapper.get(".profile-history .play-row")
    expect(row.text()).toContain("nova")
    expect(row.text()).toContain("kai")
    expect(row.text()).not.toContain("Moi")

    /* Collection : résumé par set puis grille paginée. */
    expect(called("/api/users/nova/collection")).toBe(true)
    expect(wrapper.get(".profile-sets .progress-count").text()).toBe("50 / 200")
    expect(wrapper.findAll(".profile-cards .card-tile")).toHaveLength(1)

    /* Decks publics, en lecture seule : ni suppression, ni mention privé. */
    expect(wrapper.get(".deck-box-title").text()).toContain("Fureur de Noxus")
    expect(buttonWith(wrapper, "Supprimer")).toBeUndefined()
    expect(wrapper.find(".profile-hidden").exists()).toBe(false)
    wrapper.unmount()
  })

  it("tait les sections masquées et ne les demande pas à l'API", async () => {
    setupApi(
      makeProfile({
        visibility: { show_stats: false, show_collection: false, show_decks: false, show_achievements: false },
        stats: null,
        achievements: null,
        collection_summary: null,
        decks: null
      })
    )
    const { wrapper } = await mountView()

    expect(wrapper.findAll(".profile-hidden")).toHaveLength(4)
    expect(wrapper.get(".profile-hidden").text()).toContain("Masqué par ce joueur")
    expect(called("/api/users/nova/collection")).toBe(false)
    expect(called("/api/users/nova/history")).toBe(false)
    expect(wrapper.find(".medal").exists()).toBe(false)
    wrapper.unmount()
  })

  it("suit puis cesse de suivre le joueur, compteur mis à jour sans attendre", async () => {
    const { wrapper } = await mountView()
    const follow = buttonWith(wrapper, "Suivre")
    await follow.trigger("click")
    expect(wrapper.get(".profile-follow-counts").text()).toContain("3 abonné(s)")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/users/nova/follow", { method: "PUT" })

    await buttonWith(wrapper, "Ne plus suivre").trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/users/nova/follow", { method: "DELETE" })
    expect(wrapper.get(".profile-follow-counts").text()).toContain("2 abonné(s)")
    wrapper.unmount()
  })

  it("revient en arrière si l'API refuse le suivi", async () => {
    setupApi()
    const base = api.getMockImplementation()
    api.mockImplementation((path, options) => {
      if (path === "/api/users/nova/follow") return Promise.reject(new ApiError(409, "On ne se suit pas soi-même"))
      return base(path, options)
    })
    const { wrapper } = await mountView()
    await buttonWith(wrapper, "Suivre").trigger("click")
    await flushPromises()
    expect(wrapper.get(".error").text()).toBe("On ne se suit pas soi-même")
    expect(wrapper.get(".profile-follow-counts").text()).toContain("2 abonné(s)")
    expect(buttonWith(wrapper, "Suivre")).toBeTruthy()
    wrapper.unmount()
  })

  it("sur mon propre profil : pas de bouton Suivre, un lien vers l'édition", async () => {
    setupApi(makeProfile({ is_me: true }))
    const { wrapper } = await mountView()
    expect(buttonWith(wrapper, "Suivre")).toBeUndefined()
    expect(wrapper.get(".profile-hero-actions a").attributes("href")).toBe("/profil")
    wrapper.unmount()
  })

  it("visiteur non connecté : le suivi renvoie à la connexion", async () => {
    session.token = null
    const { wrapper } = await mountView()
    expect(buttonWith(wrapper, "Suivre")).toBeUndefined()
    expect(wrapper.get(".profile-hero-actions a").attributes("href")).toBe("/connexion")
    wrapper.unmount()
  })

  it("pseudo inconnu : la page 404 du site", async () => {
    api.mockImplementation(() => Promise.reject(new ApiError(404, "Joueur introuvable")))
    const { wrapper } = await mountView()
    expect(wrapper.text()).toContain("Page introuvable")
    expect(wrapper.find(".profile-hero").exists()).toBe(false)
    wrapper.unmount()
  })

  it("erreur serveur : le message est affiché, sans page 404 trompeuse", async () => {
    api.mockImplementation(() => Promise.reject(new ApiError(500, "Le serveur a rencontré une erreur")))
    const { wrapper } = await mountView()
    expect(wrapper.get(".error").text()).toBe("Le serveur a rencontré une erreur")
    expect(wrapper.text()).not.toContain("Page introuvable")
    wrapper.unmount()
  })
})
