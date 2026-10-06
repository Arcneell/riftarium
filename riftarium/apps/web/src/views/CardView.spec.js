import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CardView from "./CardView.vue"
import { api, session } from "../api.js"
import { resetPricesMeta } from "../prices.js"
import { pageCrumb } from "../shell/pageCrumb.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function sample(extras = {}) {
  return {
    id: "ogn-037-298",
    riftbound_id: "ogn-037-298",
    name: "Immortal Phoenix",
    set_id: "OGN",
    type: "Unit",
    rarity: "Epic",
    domains: ["Fury"],
    energy: 3,
    might: 3,
    power: 1,
    text: "[Assault 2] (+2 :rb_might: while I'm an attacker.)",
    flavour: "Rise.",
    artist: "Kudos Productions",
    orientation: "portrait",
    image_url: "https://cdn.example/phoenix.png",
    variants: [],
    ...extras
  }
}

async function mountView(id, card, meta = null) {
  if (meta) api.mockImplementation((path) => Promise.resolve(path === "/api/prices/meta" ? meta : card))
  else api.mockResolvedValue(card)
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/cartes", component: { template: "<div />" } },
      { path: "/cartes/:id", component: CardView },
      { path: "/connexion", component: { template: "<div />" } }
    ]
  })
  router.push(`/cartes/${id}`)
  await router.isReady()
  const wrapper = mount(CardView, {
    global: { plugins: [router], components: { Icon: true } }
  })
  await flushPromises()
  return { wrapper, router }
}

describe("CardView", () => {
  beforeEach(() => {
    session.token = null
    session.handle = null
    api.mockReset()
    resetPricesMeta()
  })

  it("affiche une unité en deux colonnes, avec l'image entière", async () => {
    const { wrapper } = await mountView("ogn-037-298", sample())
    expect(wrapper.get(".fiche").classes()).not.toContain("landscape")
    expect(wrapper.get(".fiche-art img").attributes("src")).toContain("w=720")
    expect(wrapper.get("h1").text()).toBe("Immortal Phoenix")
    expect(wrapper.text()).toContain("Unité")
    expect(wrapper.text()).toContain("Fureur")
    expect(wrapper.get(".rift-stat img.rb-glyph").attributes("src")).toContain("energy_3.svg")
    expect(wrapper.get(".rift-stat img.rb-glyph.rune").attributes("src")).toContain("rune_fury.svg")
    expect(wrapper.findAll(".rift-stat img.rb-glyph.rune")).toHaveLength(1)
    wrapper.unmount()
  })

  it("l'énergie est lisible par un lecteur d'écran : l'alt contient le nombre", async () => {
    const { wrapper } = await mountView("ogn-037-298", sample({ energy: 3 }))
    expect(wrapper.get(".rift-stat img.rb-glyph.energy").attributes("alt")).toBe("3 énergie")
    wrapper.unmount()
  })

  it("passe en mise en page terrain pour une carte paysage", async () => {
    const { wrapper } = await mountView(
      "ogn-275-298",
      sample({
        id: "ogn-275-298",
        riftbound_id: "ogn-275-298",
        name: "Altar to Unity",
        type: "Battlefield",
        orientation: "landscape",
        energy: null,
        might: null,
        power: null,
        domains: ["Colorless"]
      })
    )
    expect(wrapper.get(".fiche").classes()).toContain("landscape")
    expect(wrapper.get(".fiche-art").classes()).toContain("landscape")
    expect(wrapper.get(".fiche-art img").attributes("src")).toContain("w=1100")
    expect(wrapper.text()).toContain("Champ de bataille")
    expect(wrapper.find(".rift-stat").exists()).toBe(false)
    wrapper.unmount()
  })

  it("affiche le bloc prix : montant, foil, note de la méta et lien Cardmarket non affilié", async () => {
    const { wrapper } = await mountView(
      "ogn-037-298",
      sample({ price_eur: 13.3, price_usd: 15.6, price_foil_eur: 42.05 }),
      {
        updated_day: "2026-08-19",
        rate: 0.92,
        rate_date: "2026-08-19",
        priced_cards: 512,
        source: "tcgplayer",
        currency_note: "Prix du marché US (TCGplayer), convertis en euros au taux BCE — estimation indicative."
      }
    )
    const block = wrapper.get(".fiche-price")
    expect(block.text()).toContain("Prix indicatif")
    expect(block.get(".fiche-price-amount").text()).toContain("13,30")
    expect(block.get(".fiche-price-foil").text()).toContain("42,05")
    expect(block.get(".fiche-price-note").text()).toContain("TCGplayer")
    expect(block.get(".fiche-price-note").text()).toContain("Mise à jour : 2026-08-19")
    expect(block.get(".fiche-price-note").text()).toContain("Ni cote officielle ni offre d'achat")
    const link = block.get("a.fiche-price-link")
    expect(link.attributes("href")).toBe(
      "https://www.cardmarket.com/fr/Riftbound/Products/Search?searchString=Immortal%20Phoenix"
    )
    expect(link.attributes("target")).toBe("_blank")
    expect(link.attributes("rel")).toBe("noopener")
    wrapper.unmount()
  })

  it("sans prix : aucun bloc vide ni lien Cardmarket", async () => {
    const { wrapper } = await mountView("ogn-037-298", sample({ price_eur: null, price_foil_eur: 8 }))
    expect(wrapper.find(".fiche-price").exists()).toBe(false)
    expect(wrapper.find(".fiche-price-link").exists()).toBe(false)
    wrapper.unmount()
  })

  it("navigation sortante : pas de requête parasite GET /api/cards/undefined", async () => {
    const { wrapper, router } = await mountView("ogn-037-298", sample())
    api.mockClear()
    router.push("/cartes")
    await flushPromises()
    expect(api.mock.calls.every(([path]) => !String(path).includes("undefined"))).toBe(true)
    // la fiche en cours n'est pas effacée pendant la transition de sortie
    expect(wrapper.find("h1").exists()).toBe(true)
    wrapper.unmount()
  })

  it("sort sans puissance ni pouvoir : seule la stat d'énergie est rendue", async () => {
    const { wrapper } = await mountView("ogn-037-298", sample({ type: "Spell", might: null, power: null }))
    const stats = wrapper.findAll(".rift-stat")
    expect(stats).toHaveLength(1)
    expect(stats[0].text()).toContain("Énergie")
    wrapper.unmount()
  })

  it("champ de bataille sans énergie : aucun RiftStat", async () => {
    const { wrapper } = await mountView(
      "ogn-275-298",
      sample({ type: "Battlefield", orientation: "landscape", energy: null, might: null, power: null })
    )
    expect(wrapper.findAll(".rift-stat")).toHaveLength(0)
    wrapper.unmount()
  })

  it("le fil d'Ariane prend le nom de la carte, puis celui de la variante ouverte", async () => {
    const variants = [
      { id: "ogn-037-298", name: "Immortal Phoenix", variant: "standard" },
      { id: "ogn-037a-298", name: "Immortal Phoenix (Alt)", variant: "alternate_art" }
    ]
    const { wrapper } = await mountView("ogn-037-298", sample({ variants }))
    expect(pageCrumb.value).toBe("Immortal Phoenix")
    api.mockResolvedValue(sample({ id: "ogn-037a-298", name: "Immortal Phoenix (Alt)", variants }))
    await wrapper.findAll(".fiche-visual .rift-chip")[1].trigger("click")
    await flushPromises()
    expect(pageCrumb.value).toBe("Immortal Phoenix (Alt)")
    wrapper.unmount()
  })

  it("les variantes sont sous l'illustration et marquent la variante affichée", async () => {
    const variants = [
      { id: "ogn-037-298", name: "Immortal Phoenix", variant: "standard" },
      { id: "ogn-037a-298", name: "Immortal Phoenix", variant: "alternate_art" }
    ]
    const { wrapper } = await mountView("ogn-037-298", sample({ variants }))
    const chips = wrapper.findAll(".fiche-visual .rift-chip")
    expect(chips).toHaveLength(2)
    expect(chips[0].attributes("aria-pressed")).toBe("true")
    expect(chips[1].attributes("aria-pressed")).toBe("false")
    wrapper.unmount()
  })
})
