import { flushPromises, mount } from "@vue/test-utils"
import { beforeEach, describe, expect, it, vi } from "vitest"
import { defineComponent, h, ref } from "vue"
import CollectionInventory from "./CollectionInventory.vue"
import { api, session } from "../api.js"
import { cardsQuery } from "../cardText.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { makeRouter } from "../test/makeRouter.js"
import Icon from "../components/Icon.vue"

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

const SETS = [{ value: "OGN", label: "Origins" }]
let pageSizes = []

/* Page minimale : crée les filtres comme la page de collection, puis monte l'inventaire. */
const Host = defineComponent({
  setup() {
    const pageSize = ref(30)
    const filters = useQuerySyncedFilters(
      {
        q: { kind: "text" },
        set_id: { kind: "list", param: "set" },
        type: { kind: "list" },
        domain: { kind: "list" },
        rarity: { kind: "list" },
        energy: { kind: "list" },
        sort: { kind: "text" },
        page: { kind: "page" }
      },
      {
        fetcher: (state) => api(`/api/collection?${cardsQuery(state, pageSize.value)}`),
        initialResult: { total: 0, total_cards: 0, unique_cards: 0, value_eur: null, items: [] },
        pageSize
      }
    )
    filters.load()
    return () =>
      h(CollectionInventory, {
        filters,
        sets: SETS,
        onPageSize: (value) => {
          pageSizes.push(value)
          pageSize.value = value
        }
      })
  }
})

async function mountInventory(path = "/collection") {
  const router = await makeRouter(path)
  const wrapper = mount(Host, { global: { plugins: [router], components: { Icon } }, attachTo: document.body })
  await flushPromises()
  return { wrapper, router }
}

function defaultApi(path) {
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
}

const byText = (wrapper, selector, text) => wrapper.findAll(selector).find((node) => node.text().includes(text))
const modalButton = (label) =>
  [...document.body.querySelectorAll(".rift-modal button")].find((button) => button.textContent.trim() === label)

describe("CollectionInventory", () => {
  beforeEach(() => {
    session.token = null
    pageSizes = []
    api.mockReset()
    api.mockImplementation(defaultApi)
  })

  it("filtres : la feuille reprend les filtres de la cartothèque", async () => {
    const { wrapper } = await mountInventory()
    expect(document.body.querySelector(".rift-sheet")).toBeNull()
    await byText(wrapper, "button", "Filtres").trigger("click")
    const sheet = document.body.querySelector(".rift-sheet")
    expect(sheet).not.toBeNull()
    const legends = [...sheet.querySelectorAll("legend")].map((node) => node.textContent.trim())
    expect(legends).toEqual(["Domaines", "Types", "Raretés", "Coût", "Sets"])
    expect(sheet.textContent).toContain("Voir les 2 cartes")
    wrapper.unmount()
  })

  it("quantité, lots et prix de chaque carte, sans aperçu au survol", async () => {
    const { wrapper } = await mountInventory()
    const cells = wrapper.findAll(".inventaire-cell")
    expect(cells).toHaveLength(2)
    expect(cells[0].get(".tile-owned").text()).toBe("×3")
    expect(cells[0].get(".inventaire-meta").text()).toContain("NM · FR")
    expect(cells[1].get(".inventaire-meta").text()).toContain("2 lots")
    expect(cells[1].get(".inventaire-meta span[title]").attributes("title")).toBe("2× NM EN, 1× PL FR")
    // valeur du lot (3 × 2,50 €) sous la tuile, prix unitaire dans la vignette
    expect(cells[0].get(".inventaire-value").text()).toContain("7,50")
    expect(cells[0].get(".tile-price").text()).toContain("2,50")
    const tile = wrapper.get(".rift-tile")
    await tile.trigger("mouseenter")
    await new Promise((resolve) => setTimeout(resolve, 600))
    expect(document.body.querySelector(".card-preview")).toBeNull()
    expect(tile.attributes("href")).toBe("/cartes/card-1")
    wrapper.unmount()
  })

  it("tri par prix : le paramètre sort est synchronisé à l'URL", async () => {
    const { wrapper, router } = await mountInventory()
    api.mockClear()
    await byText(wrapper, ".inventaire-sort button", "Prix décroissant").trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("sort=price_desc"))).toBe(true)
    })
    expect(router.currentRoute.value.query.sort).toBe("price_desc")
    expect(byText(wrapper, ".inventaire-sort button", "Prix décroissant").attributes("aria-pressed")).toBe("true")

    api.mockClear()
    await byText(wrapper, ".inventaire-sort button", "Prix croissant").trigger("click")
    await vi.waitFor(() => {
      expect(api.mock.calls.some(([path]) => String(path).includes("sort=price_asc"))).toBe(true)
    })
    expect(router.currentRoute.value.query.sort).toBe("price_asc")
    wrapper.unmount()
  })

  it("mode sélection : le clic coche au lieu de naviguer, puis applique une opération de masse", async () => {
    const { wrapper, router } = await mountInventory()
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    const pick = wrapper.get(".inventaire-cell button.inventaire-pick")
    expect(pick.attributes("aria-pressed")).toBe("false")
    expect(pick.get("span[inert]").find("a.rift-tile").exists()).toBe(true)
    await pick.get("a.rift-tile").trigger("click")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/collection")
    expect(wrapper.get(".inventaire-cell button.inventaire-pick").attributes("aria-pressed")).toBe("true")
    expect(wrapper.find(".inventaire-cell").classes()).toContain("selected")

    await byText(wrapper, ".inventaire-bulk button", "+1").trigger("click")
    await flushPromises()
    const call = api.mock.calls.find(([path]) => path === "/api/collection/bulk")
    expect(call[1].body).toEqual({ card_ids: ["card-1"], qty_delta: 1 })
    wrapper.unmount()
  })

  it("en mode sélection, Entrée sur une cellule coche sans naviguer", async () => {
    const { wrapper, router } = await mountInventory()
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    const pick = wrapper.get("button.inventaire-pick")
    await pick.trigger("keydown", { key: "Enter" })
    expect(router.currentRoute.value.path).toBe("/collection")
    expect(wrapper.get("button.inventaire-pick").attributes("aria-pressed")).toBe("true")
    await pick.trigger("keydown", { key: "Enter" })
    expect(wrapper.get("button.inventaire-pick").attributes("aria-pressed")).toBe("false")
    wrapper.unmount()
  })

  it("Entrée maintenue (répétition) ne coche qu'une fois", async () => {
    const { wrapper } = await mountInventory()
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    const pick = wrapper.get("button.inventaire-pick")
    await pick.trigger("keydown", { key: "Enter" })
    await pick.trigger("keydown", { key: "Enter", repeat: true })
    await pick.trigger("keydown", { key: "Enter", repeat: true })
    expect(wrapper.get("button.inventaire-pick").attributes("aria-pressed")).toBe("true")
    wrapper.unmount()
  })

  it("Espace : l'activation native du bouton coche sans naviguer", async () => {
    const { wrapper, router } = await mountInventory()
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    const pick = wrapper.get("button.inventaire-pick")
    await pick.trigger("keydown", { key: " " })
    await pick.trigger("keyup", { key: " " })
    // les navigateurs traduisent Espace (keyup) en clic sur le bouton
    await pick.trigger("click")
    expect(router.currentRoute.value.path).toBe("/collection")
    expect(wrapper.get("button.inventaire-pick").attributes("aria-pressed")).toBe("true")
    wrapper.unmount()
  })

  it("inert sur la vignette en mode sélection seulement", async () => {
    const { wrapper } = await mountInventory()
    expect(wrapper.find("[inert]").exists()).toBe(false)
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    expect(wrapper.find(".inventaire-pick [inert]").exists()).toBe(true)
    await byText(wrapper, ".inventaire-toolbar button", "Terminer").trigger("click")
    expect(wrapper.find("[inert]").exists()).toBe(false)
    wrapper.unmount()
  })

  it("connecté : Exporter (CSV) pointe directement sur l'export, sans fetch", async () => {
    session.token = "1"
    const { wrapper } = await mountInventory()
    const link = byText(wrapper, ".inventaire-toolbar a", "Exporter (CSV)")
    expect(link).toBeTruthy()
    expect(link.attributes("href")).toBe("/api/collection/export.csv")
    expect(link.attributes("download")).toBeDefined()
    expect(api.mock.calls.some(([path]) => String(path).includes("export.csv"))).toBe(false)
    wrapper.unmount()
  })

  it("retire de la collection après confirmation dans la modale", async () => {
    const { wrapper } = await mountInventory()
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    await wrapper.get("button.inventaire-pick").trigger("click")

    const confirmSpy = vi.spyOn(window, "confirm")
    await byText(wrapper, ".inventaire-bulk button", "Retirer").trigger("click")
    expect(confirmSpy).not.toHaveBeenCalled()
    expect(api.mock.calls.some(([path]) => path === "/api/collection/bulk")).toBe(false)

    const modal = document.body.querySelector(".rift-modal")
    expect(modal).not.toBeNull()
    expect(modal.textContent).toContain("1 carte(s)")
    modalButton("Retirer").click()
    await flushPromises()

    const call = api.mock.calls.find(([path]) => path === "/api/collection/bulk")
    expect(call[1].body).toEqual({ card_ids: ["card-1"], remove: true })
    expect(document.body.querySelector(".rift-modal")).toBeNull()
    confirmSpy.mockRestore()
    wrapper.unmount()
  })

  it("opération de masse en échec : erreur affichée, sélection conservée, bouton réactivé", async () => {
    const { wrapper } = await mountInventory()
    api.mockImplementation((path) =>
      path === "/api/collection/bulk" ? Promise.reject(new Error("Serveur indisponible")) : defaultApi(path)
    )
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    await wrapper.get("button.inventaire-pick").trigger("click")
    await byText(wrapper, ".inventaire-bulk button", "+1").trigger("click")
    await flushPromises()

    expect(wrapper.get(".inventaire-error").text()).toContain("Serveur indisponible")
    expect(wrapper.get("button.inventaire-pick").attributes("aria-pressed")).toBe("true")
    expect(byText(wrapper, ".inventaire-bulk button", "+1").attributes("disabled")).toBeUndefined()
    wrapper.unmount()
  })

  it("retrait en échec : l'erreur reste dans la modale et la sélection est conservée", async () => {
    const { wrapper } = await mountInventory()
    api.mockImplementation((path) =>
      path === "/api/collection/bulk" ? Promise.reject(new Error("Refusé")) : defaultApi(path)
    )
    await byText(wrapper, ".inventaire-toolbar button", "Sélectionner").trigger("click")
    await wrapper.get("button.inventaire-pick").trigger("click")
    await byText(wrapper, ".inventaire-bulk button", "Retirer").trigger("click")
    modalButton("Retirer").click()
    await flushPromises()

    expect(document.body.querySelector(".rift-modal .inventaire-error").textContent).toContain("Refusé")
    expect(wrapper.find(".inventaire-error").exists()).toBe(false)
    expect(wrapper.get("button.inventaire-pick").attributes("aria-pressed")).toBe("true")
    expect(modalButton("Retirer").disabled).toBe(false)
    wrapper.unmount()
  })

  it("taille de page : la mesure de la grille est émise vers la page", async () => {
    const { wrapper } = await mountInventory()
    expect(pageSizes.length).toBeGreaterThan(0)
    expect(pageSizes.every((value) => Number.isInteger(value) && value > 0)).toBe(true)
    wrapper.unmount()
  })

  it("collection vide : RiftEmpty avec lien vers /cartes", async () => {
    api.mockImplementation(() =>
      Promise.resolve({ total: 0, total_cards: 0, unique_cards: 0, value_eur: null, page: 1, size: 30, items: [] })
    )
    const { wrapper } = await mountInventory()
    const empty = wrapper.get(".rift-empty")
    expect(empty.text()).toContain("Votre vitrine est encore vide")
    expect(empty.get("a").attributes("href")).toBe("/cartes")
    wrapper.unmount()
  })

  it("aucun résultat sous filtres : proposer la réinitialisation", async () => {
    api.mockImplementation(() =>
      Promise.resolve({ total: 0, total_cards: 6, unique_cards: 2, value_eur: 15, page: 1, size: 30, items: [] })
    )
    const { wrapper } = await mountInventory("/collection?q=zzz")
    const empty = wrapper.get(".rift-empty")
    expect(empty.text()).toContain("Aucune carte ne correspond aux filtres")
    expect(byText(empty, "button", "Réinitialiser")).toBeTruthy()
    wrapper.unmount()
  })
})
