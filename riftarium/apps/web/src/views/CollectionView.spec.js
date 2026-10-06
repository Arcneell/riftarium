import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CollectionView from "./CollectionView.vue"
import CollectionBinder from "../collection/CollectionBinder.vue"
import CollectionInventory from "../collection/CollectionInventory.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function fakeItem(index, qty = 2) {
  return {
    card: {
      id: `card-${index}`,
      riftbound_id: `ogn-00${index}-298`,
      name: `Carte ${index}`,
      image_url: `https://cdn.example/${index}.png`,
      domains: ["Fury"],
      type: "Unit",
      rarity: "Epic",
      price_eur: 2.5
    },
    total_qty: qty,
    price_eur: 2.5,
    value_eur: qty * 2.5,
    entries: [{ id: index * 10, qty, condition: "NM", lang: "FR" }]
  }
}

/* Une page de classeur : une carte possédée (×3) et une manquante (fantôme). */
function fakeCard(index, ownedQty) {
  return {
    id: `card-${index}`,
    riftbound_id: `ogn-00${index}-298`,
    name: `Carte ${index}`,
    image_url: `https://cdn.example/${index}.png`,
    domains: ["Fury"],
    type: "Unit",
    rarity: "Epic",
    price_eur: 2.5,
    owned_qty: ownedQty
  }
}

async function mountView(path = "/collection") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/collection", component: CollectionView },
      { path: "/cartes", component: { template: "<div />" } },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  router.push(path)
  await router.isReady()
  const wrapper = mount(CollectionView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  /* Le classeur charge sa double page après la progression : second tour. */
  await flushPromises()
  return { wrapper, router }
}

describe("CollectionView", () => {
  beforeEach(() => {
    session.token = null
    api.mockReset()
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve([{ set_id: "OGN", name: "Origins" }])
      if (path === "/api/collection/sets") {
        return Promise.resolve({
          sets: [
            {
              set_id: "OGN",
              name: "Origins",
              total: 298,
              owned: 149,
              missing: 149,
              missing_cost_eur: 42.5,
              owned_value_eur: 100
            },
            {
              set_id: "SFD",
              name: "Spirit Forged",
              total: 100,
              owned: 100,
              missing: 0,
              missing_cost_eur: null,
              owned_value_eur: 50
            }
          ],
          overall: {
            set_id: null,
            name: "Tous",
            total: 398,
            owned: 249,
            missing: 149,
            missing_cost_eur: 42.5,
            owned_value_eur: 150
          }
        })
      }
      if (path === "/api/collection/bulk") return Promise.resolve({ updated: 1, removed: 0 })
      if (String(path).startsWith("/api/cards?")) {
        return Promise.resolve({
          total: 298,
          page: 1,
          size: 18,
          items: [fakeCard(1, 3), fakeCard(9, 0)]
        })
      }
      const multi = fakeItem(2, 3)
      multi.entries = [
        { id: 20, qty: 2, condition: "NM", lang: "EN" },
        { id: 21, qty: 1, condition: "PL", lang: "FR" }
      ]
      return Promise.resolve({
        total: 2,
        total_cards: 6,
        unique_cards: 2,
        value_eur: 15,
        page: 1,
        size: 30,
        items: [fakeItem(1, 3), multi]
      })
    })
  })

  it("stats : totaux de l'inventaire et complétion globale", async () => {
    const { wrapper } = await mountView()
    const stats = wrapper.findAll(".rift-stat")
    expect(stats).toHaveLength(4)
    expect(stats[0].text()).toContain("6")
    expect(stats[2].text()).toContain("Valeur estimée")
    expect(stats[2].text()).toContain("15,00")
    expect(stats[2].attributes("title")).toContain("marché US")
    expect(stats[3].text()).toContain("Complétion")
    expect(stats[3].text()).toContain("63 %")
    expect(stats[3].attributes("title")).toContain("il manque 149")
    wrapper.unmount()
  })

  it("commutateur : passe à l'inventaire et le note dans l'URL", async () => {
    const { wrapper, router } = await mountView()
    const group = wrapper.get('[role="group"][aria-label="Affichage de la collection"]')
    const toggle = group.findAll("button").find((button) => button.text() === "Inventaire")
    await toggle.trigger("click")
    expect(toggle.attributes("aria-pressed")).toBe("true")
    await vi.waitFor(() => {
      expect(router.currentRoute.value.query.vue).toBe("inventaire")
    })
    wrapper.unmount()
  })

  it("le mode classeur affiche le classeur, le mode inventaire l'inventaire", async () => {
    const first = await mountView()
    expect(first.wrapper.findComponent(CollectionBinder).exists()).toBe(true)
    expect(first.wrapper.findComponent(CollectionInventory).exists()).toBe(false)
    first.wrapper.unmount()
    const second = await mountView("/collection?vue=inventaire")
    expect(second.wrapper.findComponent(CollectionInventory).exists()).toBe(true)
    expect(second.wrapper.findComponent(CollectionBinder).exists()).toBe(false)
    second.wrapper.unmount()
  })
})
