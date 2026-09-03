import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import WishlistView from "./WishlistView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function wishItem(index, qty = 2) {
  return {
    card: {
      id: `card-${index}`,
      riftbound_id: `ogn-00${index}-298`,
      name: `Carte ${index}`,
      image_url: `https://cdn.example/${index}.png`,
      set_id: "OGN",
      domains: ["Fury"],
      type: "Unit",
      rarity: "Epic",
      price_eur: 3.5,
      wished_qty: qty
    },
    qty,
    created_at: "2026-08-01T00:00:00"
  }
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/wishlist", component: WishlistView },
      { path: "/cartes", component: { template: "<div />" } },
      { path: "/cartes/:id", component: { template: "<div />" } }
    ]
  })
  router.push("/wishlist")
  await router.isReady()
  const wrapper = mount(WishlistView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("WishlistView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/wishlist" && !options.method) {
        return Promise.resolve({ total: 2, value_eur: 12.25, items: [wishItem(1, 2), wishItem(2, 1)] })
      }
      return Promise.resolve(null)
    })
  })

  it("affiche le total, la valeur estimée et la grille des cartes souhaitées", async () => {
    const { wrapper } = await mountView()
    const stats = wrapper.get(".stat-row")
    expect(stats.text()).toContain("Cartes souhaitées")
    expect(stats.text()).toContain("2")
    expect(stats.text()).toContain("12,25")
    expect(stats.findAll(".stat")[1].attributes("title")).toContain("marché US")
    expect(wrapper.findAll(".wish-cell")).toHaveLength(2)
    expect(wrapper.get(".card-tile").attributes("href")).toBe("/cartes/card-1")
    expect(wrapper.get(".wish-stepper input").element.value).toBe("2")
    wrapper.unmount()
  })

  it("le stepper envoie un PUT avec la nouvelle quantité, bornée de 1 à 99", async () => {
    const { wrapper } = await mountView()
    api.mockClear()
    const plus = wrapper.get('.wish-cell .wish-stepper button[aria-label="Un exemplaire de plus"]')
    await plus.trigger("click")
    await flushPromises()
    let call = api.mock.calls.find(([path, options]) => path === "/api/wishlist/card-1" && options?.method === "PUT")
    expect(call[1].body).toEqual({ qty: 3 })
    // la liste est rechargée pour garder total et valeur à jour
    expect(api.mock.calls.some(([path, options]) => path === "/api/wishlist" && !options?.method)).toBe(true)

    // saisie manuelle hors bornes : ramenée à 99
    api.mockClear()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/wishlist" && !options.method) {
        return Promise.resolve({ total: 2, value_eur: 12.25, items: [wishItem(1, 2), wishItem(2, 1)] })
      }
      return Promise.resolve(null)
    })
    await wrapper.get(".wish-cell .wish-stepper input").setValue("120")
    await wrapper.get(".wish-cell .wish-stepper input").trigger("change")
    await flushPromises()
    call = api.mock.calls.find(([path, options]) => path === "/api/wishlist/card-1" && options?.method === "PUT")
    expect(call[1].body).toEqual({ qty: 99 })
    wrapper.unmount()
  })

  it("pendant une requête en vol, tous les steppers sont désactivés", async () => {
    const { wrapper } = await mountView()
    /* La requête reste en attente : on observe l'état « occupé » de la page. */
    let release
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/wishlist/card-1" && options.method === "PUT") {
        return new Promise((resolve) => {
          release = () => resolve(null)
        })
      }
      if (path === "/api/wishlist" && !options.method) {
        return Promise.resolve({ total: 2, value_eur: 12.25, items: [wishItem(1, 2), wishItem(2, 1)] })
      }
      return Promise.resolve(null)
    })

    await wrapper.get('.wish-cell .wish-stepper button[aria-label="Un exemplaire de plus"]').trigger("click")
    await flushPromises()

    /* Une seule requête modifie la liste entière : aucune action ne doit rester
       cliquable sur les autres cartes non plus. */
    for (const button of wrapper.findAll(".wish-cell button")) {
      expect(button.attributes("disabled")).toBeDefined()
    }
    for (const input of wrapper.findAll(".wish-cell .wish-stepper input")) {
      expect(input.attributes("disabled")).toBeDefined()
    }

    release()
    await flushPromises()
    expect(wrapper.get('.wish-cell button[aria-label="Un exemplaire de plus"]').attributes("disabled")).toBeUndefined()
    wrapper.unmount()
  })

  it("le bouton − est désactivé à 1 exemplaire", async () => {
    const { wrapper } = await mountView()
    const cells = wrapper.findAll(".wish-cell")
    const minusAtOne = cells[1].get('button[aria-label="Un exemplaire de moins"]')
    expect(minusAtOne.attributes("disabled")).toBeDefined()
    const minusAtTwo = cells[0].get('button[aria-label="Un exemplaire de moins"]')
    expect(minusAtTwo.attributes("disabled")).toBeUndefined()
    wrapper.unmount()
  })

  it("retire une carte : DELETE puis rechargement de la liste", async () => {
    let removed = false
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/wishlist/card-1" && options.method === "DELETE") {
        removed = true
        return Promise.resolve(null)
      }
      if (path === "/api/wishlist" && !options.method) {
        return removed
          ? Promise.resolve({ total: 1, value_eur: 3.5, items: [wishItem(2, 1)] })
          : Promise.resolve({ total: 2, value_eur: 12.25, items: [wishItem(1, 2), wishItem(2, 1)] })
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    await wrapper.get(".wish-cell .wish-remove").trigger("click")
    await flushPromises()
    expect(
      api.mock.calls.some(([path, options]) => path === "/api/wishlist/card-1" && options?.method === "DELETE")
    ).toBe(true)
    expect(wrapper.findAll(".wish-cell")).toHaveLength(1)
    expect(wrapper.get(".stat-row").text()).toContain("3,50")
    wrapper.unmount()
  })

  it("wishlist vide : message accueillant avec lien vers la cartothèque", async () => {
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/wishlist" && !options.method) {
        return Promise.resolve({ total: 0, value_eur: null, items: [] })
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    expect(wrapper.findAll(".wish-cell")).toHaveLength(0)
    const empty = wrapper.get(".wish-empty")
    expect(empty.text()).toContain("wishlist est vide")
    expect(empty.find("a").attributes("href")).toBe("/cartes")
    wrapper.unmount()
  })
})
