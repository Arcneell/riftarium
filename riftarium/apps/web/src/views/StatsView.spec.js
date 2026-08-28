import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import StatsView from "./StatsView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

/* Intl insère une espace insécable étroite devant « % ». */
const plain = (value) => value.replace(/[\u202f\u00a0]/g, " ")

const stats = {
  totals: { played: 12, won: 8, lost: 4, win_rate: 0.667, current_streak: 3, best_streak: 5 },
  by_format: [
    { mode: "duel", played: 8, won: 6, lost: 2 },
    { mode: "match", played: 4, won: 2, lost: 2 }
  ],
  by_deck: [{ deck_id: 7, name: "Fureur de Noxus", format: "tournament", played: 9, won: 6, lost: 3, win_rate: 0.667 }],
  by_legend: [
    { card_id: "leg-1", name: "Jinx", image_url: "https://cdn.example/jinx.png", played: 9, won: 6, lost: 3 }
  ],
  by_opponent_legend: [
    { card_id: "leg-2", name: "Viktor", image_url: "https://cdn.example/viktor.png", played: 5, won: 2, lost: 3 }
  ],
  /* Volontairement à trous : le zéro-remplissage sur 30 jours se fait côté client. */
  recent: [
    { day: "2026-08-18", played: 2, won: 1 },
    { day: "2026-08-19", played: 3, won: 3 }
  ]
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/statistiques", component: StatsView },
      { path: "/historique", component: { template: "<div />" } },
      { path: "/decks/:id", component: { template: "<div />" } },
      { path: "/salon/:code?", component: { template: "<div />" } }
    ]
  })
  router.push("/statistiques")
  await router.isReady()
  const wrapper = mount(StatsView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("StatsView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockResolvedValue({ totals: { played: 0, won: 0, lost: 0 } })
  })

  it("affiche les totaux, le graphique et les tableaux du contrat", async () => {
    api.mockResolvedValue(stats)
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/play/stats")

    const tiles = wrapper.findAll(".stat")
    expect(tiles).toHaveLength(6)
    expect(tiles[0].text()).toContain("12")
    expect(plain(tiles[3].text())).toContain("67 %")
    expect(tiles[4].text()).toContain("victoires d'affilée")

    /* Graphique des 30 derniers jours : axe zéro-rempli jusqu'au dernier jour renvoyé. */
    const chart = wrapper.getComponent({ name: "ColumnChart" })
    expect(chart.props("days")).toHaveLength(30)
    expect(chart.props("days").at(-1)).toBe("2026-08-19")
    expect(chart.props("values").at(-1)).toBe(3)
    expect(chart.props("lineValues").at(-1)).toBe(3)
    expect(chart.props("values").at(0)).toBe(0)

    const panels = wrapper.findAll(".play-panel")
    const deckPanel = panels.find((panel) => panel.text().includes("Par deck"))
    expect(deckPanel.get("tbody a").attributes("href")).toBe("/decks/7")
    expect(deckPanel.text()).toContain("légal")
    expect(plain(deckPanel.get(".play-bar-value").text())).toBe("67 %")
    expect(deckPanel.get(".play-bar-fill").attributes("style")).toContain("width: 67%")

    const legendPanel = panels.find((panel) => panel.text().includes("Par légende adverse"))
    expect(legendPanel.get("img.play-legend-thumb").attributes("src")).toContain("w=72")
    expect(legendPanel.text()).toContain("Viktor")
    expect(legendPanel.text()).toContain("2 V / 3 D")

    const formatPanel = panels.find((panel) => panel.text().includes("Par format"))
    expect(formatPanel.text()).toContain("Duel")
    expect(formatPanel.text()).toContain("Match")
    wrapper.unmount()
  })

  it("invite à jouer une partie suivie quand aucune partie n'est comptée", async () => {
    const { wrapper } = await mountView()
    const empty = wrapper.get(".play-empty")
    expect(empty.text()).toContain("Partie suivie")
    expect(empty.get("a.btn-gold").attributes("href")).toBe("/salon")
    expect(wrapper.find(".stat").exists()).toBe(false)
    wrapper.unmount()
  })

  it("affiche l'erreur de l'API à la place des tuiles", async () => {
    api.mockRejectedValue(new Error("Trop de requêtes, réessayez dans une minute"))
    const { wrapper } = await mountView()
    expect(wrapper.get(".error").text()).toBe("Trop de requêtes, réessayez dans une minute")
    expect(wrapper.find(".play-empty").exists()).toBe(false)
    wrapper.unmount()
  })
})
