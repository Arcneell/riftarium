import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { reactive } from "vue"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import DeckGallery from "./DeckGallery.vue"

function card(overrides) {
  return {
    riftbound_id: "ogn-000-298",
    type: "Unit",
    rarity: "Common",
    domains: ["Fury"],
    energy: 2,
    image_url: "https://cdn.example/c.png",
    orientation: null,
    owned_qty: 0,
    price_eur: null,
    ...overrides
  }
}

const unit = card({ id: "u1", name: "Phénix Immortel", owned_qty: 2, price_eur: 4.5 })
const ghost = card({ id: "g1", name: "Carte Fantôme" })
const calmUnit = card({ id: "c1", name: "Moine du Calme", domains: ["Calm"], owned_qty: 1 })

const originalMatchMedia = window.matchMedia
function stubWidth(px) {
  window.matchMedia = (query) => ({
    matches: px <= Number(query.match(/max-width:\s*(\d+)px/)?.[1] ?? 0),
    addEventListener() {},
    removeEventListener() {}
  })
}

const gallery = () => reactive({ q: "", set_id: [], type: [], domain: [], rarity: [], energy: [], owned: "", page: 1 })

async function mountGallery(overrides = {}) {
  const router = await makeRouter("/decks/1/edit")
  const wrapper = mount(DeckGallery, {
    props: {
      gallery: gallery(),
      result: { total: 3, items: [unit, ghost, calmUnit] },
      loading: false,
      activeCount: 0,
      pageCount: 1,
      sets: [{ value: "ogn", label: "Origins" }],
      inDeckQty: () => 0,
      offDomain: () => false,
      tournament: false,
      shakes: new Set(),
      ...overrides
    },
    global: { plugins: [router], components: { Icon } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

const tile = (wrapper, name) => wrapper.get(`button[aria-label="Ajouter ${name} au deck"]`)
const slot = (wrapper, name) => tile(wrapper, name).element.closest(".galerie-slot")

describe("DeckGallery", () => {
  beforeEach(() => {
    session.token = "jwt"
    stubWidth(1280)
  })
  afterEach(() => {
    window.matchMedia = originalMatchMedia
    session.token = null
    document.body.innerHTML = ""
  })

  it("galerie : possédées en couleur, manquantes grisées mais ajoutables", async () => {
    const { wrapper } = await mountGallery()
    expect(tile(wrapper, "Phénix Immortel").classes()).not.toContain("unowned")
    expect(tile(wrapper, "Phénix Immortel").get(".galerie-owned").text()).toBe("×2")
    const ghostTile = tile(wrapper, "Carte Fantôme")
    expect(ghostTile.classes()).toContain("unowned")
    /* Manquante : pas de pastille du tout, la vignette grisée porte l'information. */
    expect(ghostTile.find(".galerie-owned").exists()).toBe(false)

    await ghostTile.trigger("click")
    expect(wrapper.emitted("add").at(-1)).toEqual([ghost])
    wrapper.unmount()
  })

  it("tactile : le bouton « ℹ » ouvre la fiche de la carte sans l'ajouter au deck", async () => {
    const { wrapper, router } = await mountGallery()
    const info = slot(wrapper, "Phénix Immortel").querySelector(".galerie-info")
    expect(info.getAttribute("aria-label")).toContain("Voir la fiche")
    /* Vrai lien, atteignable au clavier, et hors du bouton d'ajout. */
    expect(info.tagName).toBe("A")
    expect(info.getAttribute("href")).toBe("/cartes/u1")
    expect(tile(wrapper, "Phénix Immortel").find(".galerie-info").exists()).toBe(false)

    info.click()
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/cartes/u1")
    // le clic ne remonte pas jusqu'à la tuile : la carte n'est pas ajoutée
    expect(wrapper.emitted("add")).toBeUndefined()
    wrapper.unmount()
  })

  it("clic : émet add avec la carte", async () => {
    const { wrapper } = await mountGallery()
    await tile(wrapper, "Phénix Immortel").trigger("click")
    expect(wrapper.emitted("add")).toEqual([[unit]])
    wrapper.unmount()
  })

  it("hors domaine en tournoi : classe offdomain", async () => {
    const offDomain = (c) => c.id === "c1"
    const { wrapper } = await mountGallery({ tournament: true, offDomain })
    expect(tile(wrapper, "Moine du Calme").classes()).toContain("offdomain")
    expect(tile(wrapper, "Phénix Immortel").classes()).not.toContain("offdomain")
    wrapper.unmount()

    const { wrapper: libre } = await mountGallery({ tournament: false, offDomain })
    expect(tile(libre, "Moine du Calme").classes()).not.toContain("offdomain")
    libre.unmount()
  })

  it("facettes en feuille sur téléphone", async () => {
    stubWidth(500)
    const { wrapper } = await mountGallery({ activeCount: 2 })
    expect(document.body.querySelector(".rift-sheet")).toBeNull()
    const button = wrapper.findAll("button").find((b) => b.text().startsWith("Filtres"))
    expect(button.text()).toBe("Filtres (2)")
    await button.trigger("click")
    const sheet = document.body.querySelector(".rift-sheet")
    expect(sheet).not.toBeNull()
    expect(sheet.querySelectorAll("fieldset.facet").length).toBe(5)
    // la recherche n'est pas dupliquée dans la feuille
    expect(sheet.querySelector("input")).toBeNull()
    wrapper.unmount()
  })

  it("bureau : les facettes se replient dans un volet, fermé par défaut", async () => {
    const { wrapper } = await mountGallery()
    expect(wrapper.find(".galerie-facets").exists()).toBe(false)
    const button = wrapper.findAll("button").find((b) => b.text().startsWith("Filtres"))
    expect(button.attributes("aria-expanded")).toBe("false")
    await button.trigger("click")
    expect(button.attributes("aria-expanded")).toBe("true")
    expect(wrapper.find(".galerie-facets").findAll("fieldset.facet")).toHaveLength(5)
    wrapper.unmount()
  })

  it("possession : RiftChoice émet update('owned', '1')", async () => {
    const { wrapper } = await mountGallery()
    const radios = wrapper.get('[role="radiogroup"]').findAll('[role="radio"]')
    expect(radios.map((r) => r.text())).toEqual(["Toutes", "Possédées", "Manquantes"])
    await radios[1].trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["owned", "1"])
    wrapper.unmount()
  })

  it("visiteur sans session : pas de filtre de possession ni de pastille", async () => {
    session.token = null
    const { wrapper } = await mountGallery()
    expect(wrapper.find('[role="radiogroup"]').exists()).toBe(false)
    expect(wrapper.find(".galerie-owned").exists()).toBe(false)
    expect(tile(wrapper, "Carte Fantôme").classes()).not.toContain("unowned")
    wrapper.unmount()
  })

  it("compteur, vide et réinitialisation", async () => {
    const { wrapper } = await mountGallery({
      result: { total: 0, items: [] },
      loading: true,
      activeCount: 1
    })
    expect(wrapper.get(".galerie-count").text()).toBe("0 carte(s) — chargement…")
    expect(wrapper.text()).not.toContain("Aucune carte ne correspond")
    await wrapper.setProps({ loading: false })
    expect(wrapper.text()).toContain("Aucune carte ne correspond aux filtres")
    const reset = wrapper.findAll("button").filter((b) => b.text() === "Réinitialiser")
    expect(reset.length).toBeGreaterThan(0)
    await reset.at(-1).trigger("click")
    expect(wrapper.emitted("reset")).toBeTruthy()
    wrapper.unmount()
  })

  it("Suivant émet page avec la page suivante", async () => {
    const { wrapper } = await mountGallery({ pageCount: 3 })
    await wrapper.findAll("nav button").at(-1).trigger("click")
    expect(wrapper.emitted("page")).toEqual([[2]])
    await wrapper.findAll("nav button")[0].trigger("click")
    expect(wrapper.emitted("page")).toHaveLength(1)
    wrapper.unmount()
  })

  it("Précédent désactivé en page 1 et Suivant désactivé en dernière page", async () => {
    const { wrapper } = await mountGallery({ pageCount: 3 })
    const [prev, next] = wrapper.findAll("nav button")
    expect(prev.attributes("disabled")).toBeDefined()
    expect(next.attributes("disabled")).toBeUndefined()
    wrapper.unmount()

    const last = await mountGallery({ pageCount: 3, gallery: { ...gallery(), page: 3 } })
    const buttons = last.wrapper.findAll("nav button")
    expect(buttons[0].attributes("disabled")).toBeUndefined()
    expect(buttons[1].attributes("disabled")).toBeDefined()
    last.wrapper.unmount()
  })

  it("survol, focus et pointerdown relayés ; pagination", async () => {
    const { wrapper } = await mountGallery({ pageCount: 3 })
    const t = tile(wrapper, "Phénix Immortel")
    await t.trigger("mouseenter")
    expect(wrapper.emitted("preview").at(-1)[0]).toEqual(unit)
    await t.trigger("mouseleave")
    await t.trigger("focusin")
    await t.trigger("focusout")
    expect(wrapper.emitted("hide-preview")).toHaveLength(2)
    await t.trigger("pointerdown")
    expect(wrapper.emitted("tile-pointerdown").at(-1)[0]).toEqual(unit)

    expect(wrapper.text()).toContain("page 1 / 3")
    wrapper.unmount()
  })
})
