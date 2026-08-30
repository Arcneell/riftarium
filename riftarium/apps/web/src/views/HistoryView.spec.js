import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import HistoryView from "./HistoryView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const item = {
  match_id: 31,
  mode: "match",
  status: "confirmed",
  played_at: "2026-08-12T19:30:00Z",
  opponent: { handle: "nova", avatar_url: "https://cdn.example/nova.png" },
  my_legend: { id: "leg-1", name: "Jinx", image_url: "https://cdn.example/jinx.png" },
  opponent_legend: { id: "leg-2", name: "Viktor", image_url: "https://cdn.example/viktor.png" },
  my_deck: { id: 7, name: "Fureur de Noxus", format: "tournament" },
  opponent_deck: { id: 9, name: "Contrôle Ordre", format: "free" },
  my_score: 3,
  opponent_score: 8,
  my_rounds: 1,
  opponent_rounds: 2,
  outcome: "loss"
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/historique", component: HistoryView },
      { path: "/decks/:id", component: { template: "<div />" } },
      { path: "/salon/:code?", component: { template: "<div />" } },
      { path: "/u/:handle", component: { template: "<div />" } }
    ]
  })
  router.push("/historique")
  await router.isReady()
  const wrapper = mount(HistoryView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("HistoryView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockResolvedValue({ items: [], total: 0 })
  })

  it("liste les parties : date, adversaire, légendes, decks, score et issue", async () => {
    api.mockResolvedValue({ items: [item], total: 1 })
    const { wrapper } = await mountView()

    expect(api).toHaveBeenCalledWith("/api/play/history?page=1&size=20")
    const row = wrapper.get(".play-row")
    expect(row.get(".play-score b").text()).toBe("3 – 8")
    /* Format « match » : les manches gagnées s'affichent sous le score. */
    expect(row.text()).toContain("manches 1 – 2")
    expect(row.text()).toContain("nova")
    expect(row.text()).toContain("Jinx")
    expect(row.text()).toContain("Viktor")

    const outcome = row.get(".play-outcome")
    expect(outcome.text()).toBe("Défaite")
    expect(outcome.classes()).toContain("fury")

    /* Seul mon deck est cliquable : celui de l'adversaire n'est pas forcément public. */
    const links = row.findAll(".play-side-deck a")
    expect(links).toHaveLength(1)
    expect(links[0].attributes("href")).toBe("/decks/7")
    expect(row.text()).toContain("Contrôle Ordre")

    /* Vignettes de légende en 72 px (cardThumb réduit l'URL du CDN). */
    const thumbs = row.findAll("img.play-legend-thumb")
    expect(thumbs).toHaveLength(2)
    expect(thumbs[0].attributes("src")).toContain("w=72")

    /* Le pseudo de l'adversaire mène à son profil public. */
    expect(row.get(".play-side-who a").attributes("href")).toBe("/u/nova")
    wrapper.unmount()
  })

  it("n'affiche pas les manches pour un duel", async () => {
    api.mockResolvedValue({ items: [{ ...item, mode: "duel" }], total: 1 })
    const { wrapper } = await mountView()
    expect(wrapper.text()).not.toContain("manches")
    expect(wrapper.get(".play-mode").text()).toBe("Duel")
    wrapper.unmount()
  })

  it("remplace l'adversaire supprimé par une mention explicite", async () => {
    api.mockResolvedValue({ items: [{ ...item, opponent: null }], total: 1 })
    const { wrapper } = await mountView()
    expect(wrapper.text()).toContain("Compte supprimé")
    wrapper.unmount()
  })

  it("invite à lancer une partie suivie quand l'historique est vide", async () => {
    const { wrapper } = await mountView()
    const empty = wrapper.get(".play-empty")
    expect(empty.text()).toContain("Partie suivie")
    expect(empty.text()).toContain("application Riftarium")
    expect(empty.get("a.btn-gold").attributes("href")).toBe("/salon")
    expect(wrapper.find(".play-row").exists()).toBe(false)
    wrapper.unmount()
  })

  it("affiche l'erreur de l'API sans état vide trompeur", async () => {
    api.mockRejectedValue(new Error("Le serveur a rencontré une erreur"))
    const { wrapper } = await mountView()
    expect(wrapper.get(".error").text()).toBe("Le serveur a rencontré une erreur")
    expect(wrapper.find(".play-empty").exists()).toBe(false)
    wrapper.unmount()
  })

  it("pagine : la page suivante redemande l'historique", async () => {
    api.mockResolvedValue({ items: [item], total: 25 })
    const { wrapper } = await mountView()
    const next = wrapper.findAll(".pager button").at(1)
    await next.trigger("click")
    await flushPromises()
    expect(api).toHaveBeenLastCalledWith("/api/play/history?page=2&size=20")
    expect(wrapper.get(".pager span").text()).toContain("page 2 / 2")
    wrapper.unmount()
  })
})
