import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CollectionView from "./CollectionView.vue"
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

  it("affiche la valeur estimée totale, celle des lots et le badge prix des tuiles", async () => {
    const { wrapper } = await mountView()
    const stats = wrapper.get(".stat-row")
    expect(stats.text()).toContain("Valeur estimée")
    expect(stats.text()).toContain("15,00")
    expect(stats.findAll(".stat")[2].attributes("title")).toContain("marché US")
    // valeur du lot (3 × 2,50 €) sous la tuile, badge prix unitaire dans la zone méta
    expect(wrapper.get(".col-state .price-lot").text()).toContain("7,50")
    expect(wrapper.get(".card-tile .price-tag").text()).toContain("2,50")
    wrapper.unmount()
  })

  it("tri par prix : le sélecteur déclenche le paramètre sort et le synchronise à l'URL", async () => {
    const { wrapper, router } = await mountView()
    api.mockClear()
    await wrapper.get("select.filter-sort").setValue("price_desc")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("sort=price_desc"))).toBe(true)
    })
    expect(router.currentRoute.value.query.sort).toBe("price_desc")

    api.mockClear()
    await wrapper.get("select.filter-sort").setValue("price_asc")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("sort=price_asc"))).toBe(true)
    })
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

  it("affiche la progression par set : ligne globale en tête, barres et cartes manquantes", async () => {
    const { wrapper } = await mountView()
    const panel = wrapper.get(".progress-panel")
    expect(panel.get(".progress-title").text()).toBe("Progression par set")

    // la ligne « tous sets confondus » (overall) ouvre la section
    const overall = panel.get(".progress-overall")
    expect(overall.get(".progress-name").text()).toBe("Tous sets confondus")
    expect(overall.get(".progress-count").text()).toContain("249/398")
    expect(overall.get(".progress-count").text()).toContain("63 %")
    expect(overall.get(".progress-bar i").attributes("style")).toContain("width: 63%")
    expect(overall.get(".progress-missing").text()).toContain("il manque 149 carte(s) (~42,50")

    // une ligne cliquable par set, set complet signalé sans coût
    const rows = panel.findAll("button.progress-row")
    expect(rows).toHaveLength(2)
    expect(rows[0].get(".progress-name").text()).toBe("Origins")
    expect(rows[0].get(".progress-bar i").attributes("style")).toContain("width: 50%")
    expect(rows[1].get(".progress-missing").text()).toContain("set complet ✓")
    expect(rows[1].get(".progress-missing").classes()).toContain("done")
    wrapper.unmount()
  })

  it("clic sur un set de la progression : applique le filtre Sets de la vue", async () => {
    const { wrapper, router } = await mountView()
    api.mockClear()
    await wrapper.findAll("button.progress-row")[0].trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("set_id=OGN"))).toBe(true)
    })
    expect(router.currentRoute.value.query.set).toBe("OGN")
    wrapper.unmount()
  })

  it("connecté : le bouton Exporter (CSV) pointe directement sur l'export, sans fetch", async () => {
    session.token = "1"
    const { wrapper } = await mountView()
    const link = wrapper.findAll(".filter-board a").find((a) => a.text().includes("Exporter (CSV)"))
    expect(link).toBeTruthy()
    expect(link.attributes("href")).toBe("/api/collection/export.csv")
    expect(link.attributes("download")).toBeDefined()
    expect(api.mock.calls.some(([path]) => String(path).includes("export.csv"))).toBe(false)
    wrapper.unmount()
  })

  it("retire de la collection après confirmation dans la modale du site", async () => {
    const { wrapper } = await mountView()
    const toggle = wrapper.findAll(".filter-board button").find((button) => button.text() === "Sélectionner")
    await toggle.trigger("click")
    await wrapper.get(".col-cell .card-tile").trigger("click")

    const confirmSpy = vi.spyOn(window, "confirm")
    const remove = wrapper.findAll(".bulk-bar button").find((button) => button.text().includes("Retirer"))
    await remove.trigger("click")
    expect(confirmSpy).not.toHaveBeenCalled()
    expect(api.mock.calls.some(([path]) => path === "/api/collection/bulk")).toBe(false)

    const modal = document.body.querySelector(".modal")
    expect(modal).not.toBeNull()
    expect(modal.textContent).toContain("1 carte(s)")
    const confirmButton = [...modal.querySelectorAll("button")].find(
      (button) => button.textContent.trim() === "Retirer"
    )
    confirmButton.click()
    await flushPromises()

    const call = api.mock.calls.find(([path]) => path === "/api/collection/bulk")
    expect(call[1].body).toEqual({ card_ids: ["card-1"], remove: true })
    expect(document.body.querySelector(".modal")).toBeNull()
    confirmSpy.mockRestore()
    wrapper.unmount()
  })
})
