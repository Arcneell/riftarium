import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import DeckCard from "./DeckCard.vue"

function fakeDeck(extras = {}) {
  return {
    id: 1,
    name: "Deck de la Faille",
    format: "tournament",
    card_count: 56,
    likes: 3,
    is_public: true,
    cards: [],
    checks: null,
    ...extras
  }
}

function mountCard(deck, props = {}) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/decks/:id", component: { template: "<div />" } },
      { path: "/u/:handle", component: { template: "<div />" } }
    ]
  })
  return mount(DeckCard, {
    props: { deck, to: "/decks/1", ...props },
    global: { plugins: [router], stubs: { Icon: true } }
  })
}

describe("DeckCard", () => {
  it("habille la fiche des couleurs des domaines de la légende", () => {
    const legend = { id: "l1", name: "Ahri", type: "Legend", domains: ["Fury", "Mind", "Colorless"], image_url: "u" }
    const wrapper = mountCard(fakeDeck({ cards: [{ card: legend, qty: 1 }] }))
    const style = wrapper.get(".deck-card").attributes("style")
    expect(style).toContain("--d1: var(--fury)")
    expect(style).toContain("--d2: var(--mind)") // Colorless ignoré
    expect(style).toContain("--cover")
    wrapper.unmount()

    // Sans légende : repli sur l'or du site, jamais de variable vide.
    const plain = mountCard(fakeDeck())
    expect(plain.get(".deck-card").attributes("style")).toContain("--d1: var(--bronze)")
    plain.unmount()
  })

  it("mentionne la valeur € du deck quand total_eur est présent", () => {
    const wrapper = mountCard(fakeDeck({ prices: { total_eur: 87.4, missing_eur: null } }))
    const price = wrapper.get(".deck-card-meta .deck-card-price")
    expect(price.text()).toContain("87,40")
    expect(price.attributes("title")).toContain("TCGplayer")
    wrapper.unmount()
  })

  it("affiche la pastille Légal quand toutes les règles passent", () => {
    const wrapper = mountCard(fakeDeck({ checks: [{ rule: "legend", ok: true, message: "" }] }))
    const badge = wrapper.get(".legalite")
    expect(badge.text()).toContain("Légal")
    expect(badge.classes()).toContain("legalite--ok")
    wrapper.unmount()
  })

  it("passe la pastille en Illégal si une règle échoue ou si le format est libre", () => {
    const failing = mountCard(fakeDeck({ checks: [{ rule: "legend", ok: false, message: "" }] }))
    expect(failing.get(".legalite").classes()).toContain("legalite--ko")
    expect(failing.get(".legalite").text()).toContain("Illégal")
    failing.unmount()

    const free = mountCard(fakeDeck({ format: "free", checks: [{ rule: "legend", ok: true, message: "" }] }))
    expect(free.get(".legalite").classes()).toContain("legalite--ko")
    free.unmount()
  })

  it("deck illégal : la raison est écrite sous la pastille, pas seulement dans l'infobulle", () => {
    /* Au doigt le :title ne s'ouvre jamais : « Illégal » sans raison n'apprend rien. */
    const failing = mountCard(fakeDeck({ checks: [{ rule: "legend", ok: false, message: "" }] }))
    expect(failing.get(".legalite-why").text()).toContain("ne respecte pas")
    failing.unmount()

    const ok = mountCard(fakeDeck({ checks: [{ rule: "legend", ok: true, message: "" }] }))
    expect(ok.find(".legalite-why").exists()).toBe(false)
    ok.unmount()
  })

  it("communauté : la pastille suit le booléen legal du listing", () => {
    const wrapper = mountCard(fakeDeck({ legal: false, checks: undefined }), { community: true })
    expect(wrapper.get(".legalite").classes()).toContain("legalite--ko")
    wrapper.unmount()
  })

  it("n'affiche plus le décompte de règles ni le format en texte", () => {
    const wrapper = mountCard(fakeDeck({ checks: [{ rule: "legend", ok: true, message: "" }] }))
    expect(wrapper.text()).not.toContain("règles")
    expect(wrapper.get(".deck-card-meta").text()).not.toContain("légal")
    expect(wrapper.text()).toContain("public")
    wrapper.unmount()
  })

  it("reste muet sans prix agrégé (prices absent ou total null)", () => {
    for (const deck of [fakeDeck(), fakeDeck({ prices: null }), fakeDeck({ prices: { total_eur: null } })]) {
      const wrapper = mountCard(deck)
      expect(wrapper.find(".deck-card-price").exists()).toBe(false)
      expect(wrapper.text()).toContain("56 cartes")
      wrapper.unmount()
    }
  })

  it("communauté : le pseudo de l'auteur mène à son profil public", () => {
    const wrapper = mountCard(fakeDeck({ owner: "nova", owner_avatar: null }), { community: true })
    expect(wrapper.get(".deck-card-owner a").attributes("href")).toBe("/u/nova")
    wrapper.unmount()
  })

  it("lecture seule (profil public) : ni suppression, ni mention public/privé", () => {
    const wrapper = mountCard(fakeDeck({ card_count: undefined }), { readonly: true })
    expect(wrapper.findAll("button").some((button) => button.text().includes("Supprimer"))).toBe(false)
    expect(wrapper.get(".deck-card-meta").text()).not.toContain("public")
    /* Le résumé du profil n'envoie pas le décompte de cartes : pas de « undefined cartes ». */
    expect(wrapper.text()).not.toContain("undefined")
    wrapper.unmount()
  })

  it("sans légende : classe deck-card--blank et texte Sans légende", () => {
    const blank = mountCard(fakeDeck())
    expect(blank.get(".deck-card").classes()).toContain("deck-card--blank")
    expect(blank.text()).toContain("Sans légende")
    blank.unmount()

    const legend = { id: "l1", name: "Ahri", type: "Legend", domains: ["Fury"], image_url: "u" }
    const withLegend = mountCard(fakeDeck({ cards: [{ card: legend, qty: 1 }] }))
    expect(withLegend.get(".deck-card").classes()).not.toContain("deck-card--blank")
    expect(withLegend.text()).not.toContain("Sans légende")
    expect(withLegend.get(".deck-card-legend").text()).toBe("Ahri")
    withLegend.unmount()
  })

  it("le lien principal couvre la fiche et porte le nom du deck", () => {
    const wrapper = mountCard(fakeDeck())
    const link = wrapper.get("a.deck-card-link")
    expect(link.attributes("href")).toBe("/decks/1")
    expect(link.attributes("aria-label")).toBe("Ouvrir le deck Deck de la Faille")
    wrapper.unmount()
  })

  it("le like ne déclenche pas la navigation (événement stoppé) et est désactivé quand likeBusy", async () => {
    let reached = 0
    const wrapper = mountCard(fakeDeck({ liked_by_me: false }), { community: true })
    wrapper.element.addEventListener("click", () => (reached += 1))
    const like = wrapper.get("button.deck-card-like")
    expect(like.attributes("aria-label")).toBe("Aimer ce deck")
    expect(like.attributes("aria-pressed")).toBe("false")

    const event = new MouseEvent("click", { bubbles: true, cancelable: true })
    like.element.dispatchEvent(event)
    expect(event.defaultPrevented).toBe(true)
    expect(reached).toBe(0)
    expect(wrapper.emitted("like")).toHaveLength(1)

    await wrapper.setProps({ likeBusy: true })
    expect(wrapper.get("button.deck-card-like").attributes("disabled")).toBeDefined()
    wrapper.unmount()
  })

  it("titre long : classe d'ellipse et title complet", () => {
    const name = "Un deck au nom vraiment très long qui ne tiendra jamais sur une seule ligne de la fiche"
    const wrapper = mountCard(fakeDeck({ name }))
    const title = wrapper.get("h3.deck-card-title")
    expect(title.attributes("title")).toBe(name)
    expect(title.text()).toBe(name)
    wrapper.unmount()
  })

  it("bilan V/D affiché seulement hors communauté avec record.played > 0", () => {
    const record = { played: 5, won: 3, lost: 2 }
    const mine = mountCard(fakeDeck(), { record })
    expect(mine.get(".deck-card-record").text()).toBe("3 V · 2 D")
    mine.unmount()

    const community = mountCard(fakeDeck(), { record, community: true })
    expect(community.find(".deck-card-record").exists()).toBe(false)
    community.unmount()

    const unplayed = mountCard(fakeDeck(), { record: { played: 0, won: 0, lost: 0 } })
    expect(unplayed.find(".deck-card-record").exists()).toBe(false)
    unplayed.unmount()
  })

  it("Supprimer émet remove sans suivre le lien", () => {
    const wrapper = mountCard(fakeDeck())
    const button = wrapper.findAll("button").find((b) => b.text().includes("Supprimer"))
    const event = new MouseEvent("click", { bubbles: true, cancelable: true })
    button.element.dispatchEvent(event)
    expect(event.defaultPrevented).toBe(true)
    expect(wrapper.emitted("remove")).toHaveLength(1)
    wrapper.unmount()
  })
})
