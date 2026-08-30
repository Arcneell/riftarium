import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import RoomView from "./RoomView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const ME = { id: 12, handle: "nyra", avatar_url: null }
const HOST = { id: 12, handle: "nyra", avatar_url: null }
const GUEST = { id: 27, handle: "nova", avatar_url: "https://cdn.example/nova.png" }
const JINX = { id: "leg-1", name: "Jinx", image_url: "https://cdn.example/jinx.png" }
/* Le deck range une impression alt-art de la même légende : c'est cet `id`-là
   que le salon doit reprendre, pas celui de la carte de base. */
const JINX_ALT = { id: "leg-1-alt", name: "Jinx", type: "Legend", image_url: "https://cdn.example/jinx-alt.png" }
const DECK_7 = { id: 7, name: "Fureur", cards: [{ card: JINX_ALT, qty: 1 }] }

const seat = (user, over = {}) => ({
  user,
  seat: user === HOST ? 0 : 1,
  legend: null,
  deck: null,
  ready: false,
  ...over
})

function makeRoom(over = {}) {
  return {
    code: "ABC234",
    mode: "duel",
    status: "open",
    host_id: HOST.id,
    match_id: null,
    expires_at: "2026-08-12T21:00:00Z",
    version: 3,
    victory_score: 8,
    rounds_to_win: 1,
    players: [seat(HOST)],
    ...over
  }
}

/* Le dernier appel réseau ayant ce chemin (et cette méthode), options comprises. */
function lastCall(path, method) {
  const call = [...api.mock.calls]
    .reverse()
    .find(([called, options]) => called === path && (!method || options?.method === method))
  return call ? { path: call[0], ...(call[1] || {}) } : null
}

function setupApi({ me = ME, room = makeRoom(), match = null, decks = [], cards = [JINX], deck = DECK_7 } = {}) {
  api.mockImplementation((path) => {
    if (path === "/api/auth/me") return Promise.resolve(me)
    if (path === "/api/decks/mine") return Promise.resolve(decks)
    if (path.startsWith("/api/decks/")) return deck ? Promise.resolve(deck) : Promise.reject(new Error("Introuvable"))
    if (path.startsWith("/api/cards")) return Promise.resolve({ items: cards, total: cards.length })
    if (path === "/api/play/current") return Promise.resolve({ room: null, match: null })
    if (path.startsWith("/api/play/matches/")) return Promise.resolve(match)
    if (path.startsWith("/api/play/rooms/")) return Promise.resolve(room)
    return Promise.resolve(null)
  })
}

async function mountView(path = "/salon/ABC234") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/salon/:code?", component: RoomView },
      { path: "/historique", component: { template: "<div />" } },
      { path: "/statistiques", component: { template: "<div />" } },
      { path: "/u/:handle", component: { template: "<div />" } }
    ]
  })
  router.push(path)
  await router.isReady()
  const wrapper = mount(RoomView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

const buttonWith = (wrapper, label) => wrapper.findAll("button").find((button) => button.text().includes(label))

describe("RoomView", () => {
  beforeEach(() => {
    api.mockReset()
    setupApi()
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it("affiche le salon lu par son code et sonde toutes les 5 secondes", async () => {
    const intervalSpy = vi.spyOn(globalThis, "setInterval")
    setupApi({ room: makeRoom({ players: [seat(HOST, { ready: true }), seat(GUEST)] }) })
    const { wrapper } = await mountView()

    expect(api).toHaveBeenCalledWith("/api/play/rooms/ABC234")
    expect(wrapper.get(".play-room-code").text()).toContain("ABC234")
    expect(wrapper.get(".play-mode").text()).toBe("Duel")
    expect(wrapper.get(".play-status").text()).toBe("En attente d'un adversaire")
    expect(wrapper.findAll(".play-seat")).toHaveLength(2)
    expect(wrapper.text()).toContain("nova")
    expect(wrapper.text()).toContain("Prêt ✓")

    const tick = intervalSpy.mock.calls.find(([, delay]) => delay === 5000)
    expect(tick).toBeTruthy()
    api.mockClear()
    tick[0]()
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/play/rooms/ABC234")
    wrapper.unmount()
  })

  it("propose de rejoindre un salon ouvert dont je ne fais pas partie", async () => {
    setupApi({ room: makeRoom({ host_id: GUEST.id, players: [seat(GUEST)] }) })
    const { wrapper } = await mountView()

    const join = buttonWith(wrapper, "Rejoindre")
    expect(join).toBeTruthy()
    await join.trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/rooms/ABC234/join")).toMatchObject({ method: "POST" })
    wrapper.unmount()
  })

  it("ne montre ni choix ni bouton « Rejoindre » quand le salon est complet", async () => {
    setupApi({
      room: makeRoom({ host_id: GUEST.id, players: [seat(GUEST), seat({ id: 99, handle: "kai" })] })
    })
    const { wrapper } = await mountView()
    expect(buttonWith(wrapper, "Rejoindre")).toBeUndefined()
    expect(wrapper.find(".play-picker").exists()).toBe(false)
    expect(wrapper.text()).toContain("Ce salon est complet")
    wrapper.unmount()
  })

  it("choisit une légende par la recherche et un deck, puis se déclare prêt", async () => {
    setupApi({
      room: makeRoom({
        players: [seat(HOST, { legend: JINX, deck: { id: 7, name: "Fureur", format: "tournament" } })]
      }),
      decks: [{ id: 7, name: "Fureur" }]
    })
    const { wrapper } = await mountView()

    const search = wrapper.get("#room-legend")
    await search.setValue("jin")
    /* Recherche débrayée de 300 ms : on laisse passer le délai réel. */
    await new Promise((resolve) => setTimeout(resolve, 360))
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/cards?type=Legend&q=jin")

    await wrapper.get(".play-legend-results button").trigger("click")
    await flushPromises()
    /* Un changement de choix remet le joueur « pas prêt ». */
    expect(lastCall("/api/play/rooms/ABC234/me")).toMatchObject({
      method: "PUT",
      body: { legend_card_id: "leg-1", deck_id: 7, ready: false }
    })

    await buttonWith(wrapper, "Je suis prêt").trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/rooms/ABC234/me").body).toEqual({
      legend_card_id: "leg-1",
      deck_id: 7,
      ready: true
    })
    wrapper.unmount()
  })

  it("renvoie l'hôte vers son téléphone quand les deux joueurs sont prêts", async () => {
    setupApi({ room: makeRoom({ players: [seat(HOST, { ready: true }), seat(GUEST, { ready: true })] }) })
    const { wrapper } = await mountView()
    expect(wrapper.get(".play-notice").text()).toContain(
      "Lancez la partie depuis l'application Riftarium sur votre téléphone"
    )
    /* Le lancement n'est jamais proposé sur le web : le compteur vit sur le mobile. */
    expect(buttonWith(wrapper, "Lancer")).toBeUndefined()
    expect(buttonWith(wrapper, "Annuler le salon")).toBeTruthy()
    wrapper.unmount()
  })

  it("laisse l'invité quitter le salon", async () => {
    setupApi({ room: makeRoom({ host_id: GUEST.id, players: [seat(GUEST), seat(HOST)] }) })
    const { wrapper } = await mountView()
    await buttonWith(wrapper, "Quitter le salon").trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/rooms/ABC234/leave")).toMatchObject({ method: "POST" })
    expect(buttonWith(wrapper, "Annuler le salon")).toBeUndefined()
    wrapper.unmount()
  })

  it("laisse l'hôte annuler le salon", async () => {
    const { wrapper } = await mountView()
    await buttonWith(wrapper, "Annuler le salon").trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/rooms/ABC234", "DELETE")).toMatchObject({ method: "DELETE" })
    wrapper.unmount()
  })

  it("suit le match en lecture seule et permet de confirmer le résultat", async () => {
    const match = {
      id: 31,
      room_code: "ABC234",
      mode: "duel",
      status: "awaiting_confirmation",
      host_id: HOST.id,
      players: [
        { user: HOST, seat: 0, score: 5, rounds_won: 0, confirmed: false },
        { user: GUEST, seat: 1, score: 8, rounds_won: 1, confirmed: true }
      ],
      state: { round: 1, turn: 6 },
      version: 9
    }
    setupApi({
      room: makeRoom({ status: "playing", match_id: 31, players: [seat(HOST), seat(GUEST)] }),
      match
    })
    const { wrapper } = await mountView()

    expect(api).toHaveBeenCalledWith("/api/play/matches/31")
    const panel = wrapper.get(".play-match")
    expect(panel.text()).toContain("En attente de confirmation")
    expect(panel.text()).toContain("lecture seule")
    expect(panel.findAll(".play-match-score").map((node) => node.text())).toEqual(["5", "8"])

    await buttonWith(wrapper, "Confirmer le résultat").trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/matches/31/confirm")).toMatchObject({ method: "POST" })

    await buttonWith(wrapper, "Contester").trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/matches/31/dispute")).toMatchObject({ method: "POST" })
    wrapper.unmount()
  })

  it("sans code : propose la saisie manuelle et ouvre le salon demandé", async () => {
    const { wrapper, router } = await mountView("/salon")
    expect(api).toHaveBeenCalledWith("/api/play/current")
    expect(api).not.toHaveBeenCalledWith("/api/play/rooms/")

    await wrapper.get("#room-code").setValue("abc234")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/salon/ABC234")
    wrapper.unmount()
  })

  it("affiche l'erreur quand le salon est introuvable", async () => {
    api.mockImplementation((path) => {
      if (path === "/api/auth/me") return Promise.resolve(ME)
      return Promise.reject(new Error("Salon introuvable"))
    })
    const { wrapper } = await mountView()
    expect(wrapper.get(".error").text()).toBe("Salon introuvable")
    expect(wrapper.find(".play-seat").exists()).toBe(false)
    wrapper.unmount()
  })
  it("choisir un deck envoie la légende telle qu'elle est rangée dans le deck", async () => {
    setupApi({ room: makeRoom({ players: [seat(HOST)] }), decks: [{ id: 7, name: "Fureur" }] })
    const { wrapper } = await mountView()

    await wrapper.get("#room-deck").setValue("7")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/decks/7")
    /* Même impression que dans le deck (alt-art), et le joueur repasse « pas prêt ». */
    expect(lastCall("/api/play/rooms/ABC234/me")).toMatchObject({
      method: "PUT",
      body: { legend_card_id: "leg-1-alt", deck_id: 7, ready: false }
    })
    wrapper.unmount()
  })

  it("deck sans légende ou illisible : la légende déjà choisie est conservée", async () => {
    setupApi({
      room: makeRoom({ players: [seat(HOST, { legend: JINX })] }),
      decks: [{ id: 7, name: "Fureur" }],
      deck: { id: 7, name: "Fureur", cards: [] }
    })
    const { wrapper } = await mountView()
    await wrapper.get("#room-deck").setValue("7")
    await flushPromises()
    expect(lastCall("/api/play/rooms/ABC234/me").body).toEqual({
      legend_card_id: "leg-1",
      deck_id: 7,
      ready: false
    })
    wrapper.unmount()
  })

  it("retirer le deck ne touche pas à la légende et n'interroge aucun deck", async () => {
    setupApi({
      room: makeRoom({ players: [seat(HOST, { legend: JINX, deck: { id: 7, name: "Fureur" } })] }),
      decks: [{ id: 7, name: "Fureur" }]
    })
    const { wrapper } = await mountView()
    api.mockClear()
    await wrapper.get("#room-deck").setValue("")
    await flushPromises()
    expect(api.mock.calls.some(([path]) => path === "/api/decks/7")).toBe(false)
    expect(lastCall("/api/play/rooms/ABC234/me").body).toEqual({
      legend_card_id: "leg-1",
      deck_id: null,
      ready: false
    })
    wrapper.unmount()
  })

  it("le pseudo d'un joueur mène à son profil public", async () => {
    setupApi({ room: makeRoom({ players: [seat(HOST), seat(GUEST)] }) })
    const { wrapper } = await mountView()
    const links = wrapper.findAll(".play-seat-who a").map((link) => link.attributes("href"))
    expect(links).toEqual(["/u/nyra", "/u/nova"])
    wrapper.unmount()
  })
})
