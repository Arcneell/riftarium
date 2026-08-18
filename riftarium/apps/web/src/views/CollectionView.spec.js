import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CollectionView from "./CollectionView.vue"
import { api } from "../api.js"

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
      rarity: "Epic"
    },
    total_qty: qty,
    entries: [{ id: index * 10, qty, condition: "NM", lang: "FR" }]
  }
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/collection", component: CollectionView },
      { path: "/cartes", component: { template: "<div />" } },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  router.push("/collection")
  await router.isReady()
  const wrapper = mount(CollectionView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("CollectionView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation((path) => {
      if (path === "/api/sets") return Promise.resolve([{ set_id: "OGN", name: "Origins" }])
      if (path === "/api/collection/bulk") return Promise.resolve({ updated: 1, removed: 0 })
      const multi = fakeItem(2, 3)
      multi.entries = [
        { id: 20, qty: 2, condition: "NM", lang: "EN" },
        { id: 21, qty: 1, condition: "PL", lang: "FR" }
      ]
      return Promise.resolve({
        total: 2,
        total_cards: 6,
        unique_cards: 2,
        page: 1,
        size: 30,
        items: [fakeItem(1, 3), multi]
      })
    })
  })

  it("reprend les filtres de la cartothèque et affiche les stats", async () => {
    const { wrapper } = await mountView()
    const labels = wrapper.findAll(".fsel-btn").map((button) => button.text().trim())
    expect(labels).toEqual(["Domaines", "Types", "Raretés", "Coût", "Sets"])
    expect(wrapper.find(".stat-row").text()).toContain("6")
    wrapper.unmount()
  })

  it("affiche la quantité et les lots de chaque carte, sans aperçu au survol", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.find(".card-qty").text()).toBe("×3")
    expect(wrapper.find(".col-state").text()).toContain("NM · FR")
    expect(wrapper.findAll(".col-state")[1].text()).toContain("2 lots")
    const tile = wrapper.get(".card-tile")
    await tile.trigger("mouseenter")
    await vi.waitFor(() => expect(document.body.querySelector(".card-preview")).toBeNull())
    expect(tile.attributes("href")).toBe("/cartes/card-1")
    wrapper.unmount()
  })

  it("mode sélection : le clic coche au lieu de naviguer, puis applique une opération de masse", async () => {
    const { wrapper, router } = await mountView()
    const toggle = wrapper.findAll(".filter-board button").find((button) => button.text() === "Sélectionner")
    await toggle.trigger("click")
    await wrapper.get(".col-cell .card-tile").trigger("click")
    expect(router.currentRoute.value.path).toBe("/collection")
    expect(wrapper.find(".col-cell").classes()).toContain("selected")

    const plusOne = wrapper.findAll(".bulk-bar button").find((button) => button.text().includes("+1"))
    await plusOne.trigger("click")
    await flushPromises()
    const call = api.mock.calls.find(([path]) => path === "/api/collection/bulk")
    expect(call[1].body).toEqual({ card_ids: ["card-1"], qty_delta: 1 })
    wrapper.unmount()
  })
})
