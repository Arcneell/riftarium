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
    expect(second.wrapper.findComponent(CollectionBinder).isVisible()).toBe(false)
    second.wrapper.unmount()
  })

  it("classeur conservé : le set et la page survivent à un aller-retour par l'inventaire", async () => {
    const { wrapper } = await mountView()
    const tabs = () => wrapper.findAll(".classeur-tab")
    await tabs()[1].trigger("click")
    await flushPromises()
    expect(tabs()[1].classes()).toContain("active")
    const group = wrapper.get('[role="group"][aria-label="Affichage de la collection"]')
    const chip = (label) => group.findAll("button").find((button) => button.text() === label)
    await chip("Inventaire").trigger("click")
    await flushPromises()
    expect(wrapper.findComponent(CollectionInventory).exists()).toBe(true)
    await chip("Classeur").trigger("click")
    await flushPromises()
    expect(tabs()[1].classes()).toContain("active")
    expect(tabs()[0].classes()).not.toContain("active")
    wrapper.unmount()
  })

  it("la page est un div (pas de section : main.css y poserait 88 px de marge)", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.element.tagName).toBe("DIV")
    expect(wrapper.element.classList.contains("collection-page")).toBe(true)
    wrapper.unmount()
  })

  it("après un retrait en masse : statistiques rechargées, double page du classeur rechargée", async () => {
    const { wrapper } = await mountView("/collection?vue=inventaire")
    const calls = (prefix) => api.mock.calls.filter(([path]) => String(path).startsWith(prefix)).length
    expect(calls("/api/collection/sets")).toBe(1)
    const cardCalls = calls("/api/cards?")
    const byText = (selector, text) => wrapper.findAll(selector).find((node) => node.text().includes(text))
    await byText(".inventaire-toolbar button", "Sélectionner").trigger("click")
    await wrapper.get("button.inventaire-pick").trigger("click")
    await byText(".inventaire-bulk button", "Retirer").trigger("click")
    const confirm = [...document.body.querySelectorAll(".rift-modal button")].find(
      (button) => button.textContent.trim() === "Retirer"
    )
    confirm.click()
    await flushPromises()
    expect(calls("/api/collection/sets")).toBe(2)
    /* Le classeur est caché : il ne recharge qu'à sa prochaine activation. */
    expect(calls("/api/cards?")).toBe(cardCalls)
    const group = wrapper.get('[role="group"][aria-label="Affichage de la collection"]')
    await group
      .findAll("button")
      .find((button) => button.text() === "Classeur")
      .trigger("click")
    await flushPromises()
    expect(calls("/api/cards?")).toBe(cardCalls + 1)
    wrapper.unmount()
  })

  it("saisie rapide dans le classeur : la progression est rechargée sans recharger la double page", async () => {
    session.token = "1"
    sessionStorage.setItem("riftarium_quick_add", "1")
    const base = api.getMockImplementation()
    api.mockImplementation((path, opts) => {
      if (opts?.method === "POST") {
        return Promise.resolve({
          card_id: "card-9",
          total_qty: 1,
          entries: [{ id: 5, qty: 1, condition: "NM", lang: "FR" }]
        })
      }
      return base(path, opts)
    })
    const { wrapper } = await mountView()
    const calls = (prefix) => api.mock.calls.filter(([path]) => String(path).startsWith(prefix)).length
    const sets = calls("/api/collection/sets")
    const cards = calls("/api/cards?")
    await wrapper.findAll(".classeur-pocket")[1].get(".rift-stepper-plus").trigger("click")
    await flushPromises()
    expect(calls("/api/collection/sets")).toBe(sets + 1)
    expect(calls("/api/cards?")).toBe(cards)
    expect(wrapper.findAll(".classeur-pocket")[1].classes()).not.toContain("ghost")
    sessionStorage.clear()
    session.token = null
    wrapper.unmount()
  })

  it("statistiques : « — » tant que rien n'est chargé, au lieu de zéros", async () => {
    api.mockImplementation(() => new Promise(() => {}))
    const { wrapper } = await mountView()
    const stats = wrapper.findAll(".rift-stat")
    expect(stats).toHaveLength(3)
    for (const stat of stats) expect(stat.text()).toContain("—")
    wrapper.unmount()
  })

  it("échec de /api/collection/sets : le classeur affiche une erreur, pas un squelette sans fin", async () => {
    const original = api.getMockImplementation()
    api.mockImplementation((path) =>
      path === "/api/collection/sets" ? Promise.reject(new Error("Serveur indisponible")) : original(path)
    )
    const { wrapper } = await mountView()
    expect(wrapper.findComponent(CollectionBinder).get("[role=alert]").text()).toContain("Serveur indisponible")
    expect(wrapper.find(".shimmer").exists()).toBe(false)
    wrapper.unmount()
  })

  it("progression : une réponse tardive d'une lecture ancienne n'écrase pas la plus récente", async () => {
    const original = api.getMockImplementation()
    const { wrapper } = await mountView()
    const resolvers = []
    api.mockImplementation((path) =>
      path === "/api/collection/sets" ? new Promise((resolve) => resolvers.push(resolve)) : original(path)
    )
    const binder = wrapper.findComponent(CollectionBinder)
    binder.vm.$emit("changed")
    binder.vm.$emit("changed")
    await flushPromises()
    expect(resolvers).toHaveLength(2)
    const withOwned = (owned) => ({
      sets: [{ set_id: "OGN", name: "Origins", total: 298, owned, missing: 298 - owned, missing_cost_eur: 1 }],
      overall: { total: 298, owned, missing: 298 - owned, missing_cost_eur: 1 }
    })
    resolvers[1](withOwned(7))
    await flushPromises()
    resolvers[0](withOwned(3))
    await flushPromises()
    expect(binder.props("progress").overall.owned).toBe(7)
    wrapper.unmount()
  })

  it("entrée directe en inventaire : une seule requête, un vrai changement de taille recharge", async () => {
    const { wrapper } = await mountView("/collection?vue=inventaire")
    await new Promise((resolve) => setTimeout(resolve, 400))
    const calls = () => api.mock.calls.filter(([path]) => String(path).startsWith("/api/collection?"))
    expect(calls()).toHaveLength(1)
    wrapper.findComponent(CollectionInventory).vm.$emit("page-size", 12)
    await vi.waitFor(() => expect(calls()).toHaveLength(2))
    expect(String(calls()[1][0])).toContain("size=12")
    wrapper.unmount()
  })
})
