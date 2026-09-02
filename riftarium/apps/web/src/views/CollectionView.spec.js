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

  it("classeur par défaut : ouvre le premier set incomplet, pochettes pleines et fantômes", async () => {
    const { wrapper } = await mountView()

    // un onglet par set : le set incomplet affiche son pourcentage, le complet sa gemme
    const tabs = wrapper.findAll(".binder-tab")
    expect(tabs).toHaveLength(2)
    expect(tabs[0].text()).toContain("Origins")
    expect(tabs[0].text()).toContain("50 %")
    expect(tabs[0].classes()).toContain("active")
    expect(tabs[1].find(".progress-gem").exists()).toBe(true)

    // en-tête du classeur : set ouvert, complétion et coût des manquantes
    expect(wrapper.get(".binder-title").text()).toBe("Origins")
    expect(wrapper.get(".binder-sub").text()).toContain("149/298")
    expect(wrapper.get(".binder-sub").text()).toContain("il manque 149 carte(s) (~42,50")

    // la double page demande 18 cartes du set, triées par numéro collector
    expect(
      api.mock.calls.some(([path]) => String(path).includes("set_id=OGN") && String(path).includes("size=18"))
    ).toBe(true)

    // 18 pochettes : les cartes reçues puis des pochettes vides
    expect(wrapper.findAll(".pocket")).toHaveLength(18)
    expect(wrapper.get(".pocket .pocket-qty").text()).toBe("×3")

    // carte manquante : fantôme cliquable vers la fiche, numéro et prix affichés
    const ghost = wrapper.get(".pocket.ghost")
    expect(ghost.attributes("href")).toBe("/cartes/card-9")
    expect(ghost.get(".pocket-num").text()).toBe("OGN-009-298")
    expect(ghost.get(".pocket-price").text()).toContain("2,50")
    wrapper.unmount()
  })

  it("stats : totaux de l'inventaire et complétion globale", async () => {
    const { wrapper } = await mountView()
    const stats = wrapper.findAll(".stat")
    expect(wrapper.get(".stat-row").text()).toContain("6")
    expect(stats[2].text()).toContain("Valeur estimée")
    expect(stats[2].text()).toContain("15,00")
    expect(stats[2].attributes("title")).toContain("marché US")
    expect(stats[3].text()).toContain("Complétion")
    expect(stats[3].text()).toContain("63 %")
    wrapper.unmount()
  })

  it("chips du classeur : « Manquantes » filtre la double page sur owned=0", async () => {
    const { wrapper } = await mountView()
    api.mockClear()
    const chip = wrapper.findAll(".binder-chips .filter").find((button) => button.text() === "Manquantes")
    await chip.trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("owned=0"))).toBe(true)
    })
    wrapper.unmount()
  })

  it("tourner la page : demande la double page suivante du set", async () => {
    const { wrapper } = await mountView()
    api.mockClear()
    const nav = wrapper.findAll(".binder-nav button")
    expect(nav[0].attributes("disabled")).toBeDefined()
    await nav[1].trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("page=2"))).toBe(true)
    })
    wrapper.unmount()
  })

  it("cascade des pochettes : à l'ouverture d'un set, pas au tournage de page", async () => {
    const { wrapper } = await mountView()
    // Première ouverture : la double page « distribue » ses pochettes.
    expect(wrapper.get(".binder-spread").classes()).toContain("deal")

    // Tourner la page du même set : la page arrive pleine, sans cascade.
    await wrapper.findAll(".binder-nav button")[1].trigger("click")
    await vi.waitFor(() => {
      expect(wrapper.get(".binder-spread").classes()).not.toContain("deal")
    })

    // Changer de set : nouvelle distribution.
    await wrapper.findAll(".binder-tab")[1].trigger("click")
    await vi.waitFor(() => {
      expect(wrapper.get(".binder-spread").classes()).toContain("deal")
    })
    wrapper.unmount()
  })

  it("flèches du clavier : feuillettent le classeur", async () => {
    const { wrapper } = await mountView()
    api.mockClear()
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight" }))
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("page=2"))).toBe(true)
    })
    wrapper.unmount()
  })

  it("clic sur un onglet de set : ouvre ce set à la première page", async () => {
    const { wrapper } = await mountView()
    api.mockClear()
    await wrapper.findAll(".binder-tab")[1].trigger("click")
    await vi.waitFor(() => {
      expect(
        api.mock.calls.some(([path]) => String(path).includes("set_id=SFD") && String(path).includes("page=1"))
      ).toBe(true)
    })
    wrapper.unmount()
  })

  it("commutateur : passe à l'inventaire et le note dans l'URL", async () => {
    const { wrapper, router } = await mountView()
    const toggle = wrapper.findAll(".view-switch button").find((button) => button.text() === "Inventaire")
    await toggle.trigger("click")
    expect(wrapper.find(".filter-board").exists()).toBe(true)
    expect(wrapper.find(".binder").exists()).toBe(false)
    await vi.waitFor(() => {
      expect(router.currentRoute.value.query.vue).toBe("inventaire")
    })
    wrapper.unmount()
  })

  it("inventaire : reprend les filtres de la cartothèque", async () => {
    const { wrapper } = await mountView("/collection?vue=inventaire")
    const labels = wrapper.findAll(".fsel-btn").map((button) => button.text().trim())
    expect(labels).toEqual(["Domaines", "Types", "Raretés", "Coût", "Sets", "Trier"])
    wrapper.unmount()
  })

  it("inventaire : quantité, lots et prix de chaque carte, sans aperçu au survol", async () => {
    const { wrapper } = await mountView("/collection?vue=inventaire")
    expect(wrapper.find(".card-qty").text()).toBe("×3")
    expect(wrapper.find(".col-state").text()).toContain("NM · FR")
    expect(wrapper.findAll(".col-state")[1].text()).toContain("2 lots")
    // valeur du lot (3 × 2,50 €) sous la tuile, badge prix unitaire dans la zone méta
    expect(wrapper.get(".col-state .price-lot").text()).toContain("7,50")
    expect(wrapper.get(".card-tile .price-tag").text()).toContain("2,50")
    const tile = wrapper.get(".card-tile")
    await tile.trigger("mouseenter")
    await vi.waitFor(() => expect(document.body.querySelector(".card-preview")).toBeNull())
    expect(tile.attributes("href")).toBe("/cartes/card-1")
    wrapper.unmount()
  })

  it("tri par prix : le sélecteur déclenche le paramètre sort et le synchronise à l'URL", async () => {
    const { wrapper, router } = await mountView("/collection?vue=inventaire")
    api.mockClear()
    /* FilterSelect en mode single : on ouvre le popup « Trier » puis on choisit une option. */
    const sortBtn = wrapper.findAll(".fsel-btn").find((b) => b.text().includes("Trier"))
    await sortBtn.trigger("click")
    let option = wrapper.findAll(".fsel-opt").find((b) => b.text().includes("Prix décroissant"))
    await option.trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("sort=price_desc"))).toBe(true)
    })
    expect(router.currentRoute.value.query.sort).toBe("price_desc")

    api.mockClear()
    await sortBtn.trigger("click")
    option = wrapper.findAll(".fsel-opt").find((b) => b.text().includes("Prix croissant"))
    await option.trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("sort=price_asc"))).toBe(true)
    })
    wrapper.unmount()
  })

  it("mode sélection : le clic coche au lieu de naviguer, puis applique une opération de masse", async () => {
    const { wrapper, router } = await mountView("/collection?vue=inventaire")
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

  it("connecté : le bouton Exporter (CSV) pointe directement sur l'export, sans fetch", async () => {
    session.token = "1"
    const { wrapper } = await mountView("/collection?vue=inventaire")
    const link = wrapper.findAll(".filter-board a").find((a) => a.text().includes("Exporter (CSV)"))
    expect(link).toBeTruthy()
    expect(link.attributes("href")).toBe("/api/collection/export.csv")
    expect(link.attributes("download")).toBeDefined()
    expect(api.mock.calls.some(([path]) => String(path).includes("export.csv"))).toBe(false)
    wrapper.unmount()
  })

  it("retire de la collection après confirmation dans la modale du site", async () => {
    const { wrapper } = await mountView("/collection?vue=inventaire")
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
