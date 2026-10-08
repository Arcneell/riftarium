import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import { reactive } from "vue"
import Icon from "../components/Icon.vue"
import DeckList from "./DeckList.vue"
import listSource from "./DeckList.vue?raw"

const ZONES = [
  { key: "Legend", label: "Légende", target: 1 },
  { key: "main", label: "Deck", target: 40 },
  { key: "Rune", label: "Runes", target: 12 },
  { key: "Battlefield", label: "Champs", target: 3 }
]
const LIST_ZONES = ZONES.filter((zone) => zone.key !== "Legend")

const legend = { id: "l1", name: "Jinx", type: "Legend", image_url: "https://cdn.example/l.png" }
const unit = {
  id: "u1",
  name: "Phénix Immortel",
  type: "Unit",
  energy: 3,
  owned_qty: 1,
  image_url: "https://cdn.example/u.png"
}

function mountList(overrides = {}) {
  const grouped = { Legend: [], main: [{ card: unit, qty: 3 }], Rune: [], Battlefield: [] }
  return mount(DeckList, {
    props: {
      deck: { id: 1, cards: [] },
      canEdit: true,
      zones: ZONES,
      listZones: LIST_ZONES,
      grouped,
      zoneCounts: { Legend: 0, main: 3, Rune: 0, Battlefield: 0 },
      legendEntry: null,
      legendRunes: [],
      flashes: new Set(),
      limitMessage: "",
      missingInDeck: 0,
      drag: reactive({ active: false, card: null, from: "", x: 0, y: 0, overDeck: false }),
      finePointer: true,
      signedIn: true,
      ...overrides
    },
    global: { components: { Icon } }
  })
}

describe("DeckList", () => {
  it("vitrine de légende avec runes et bouton retirer", async () => {
    const wrapper = mountList({
      legendEntry: { card: legend, qty: 1 },
      legendRunes: [
        { domain: "Fury", label: "Fureur", src: "https://cdn.example/fury.svg" },
        { domain: "Chaos", label: "Chaos", src: "https://cdn.example/chaos.svg" }
      ]
    })
    const hero = wrapper.get(".decklist-hero")
    expect(hero.text()).toContain("Légende")
    expect(hero.text()).toContain("Jinx")
    expect(hero.findAll(".decklist-hero-runes img")).toHaveLength(2)
    await hero.get('button[aria-label="Retirer la légende du deck"]').trigger("click")
    expect(wrapper.emitted("remove-one")[0]).toEqual(["l1"])

    await wrapper.setProps({ canEdit: false })
    expect(wrapper.find('button[aria-label="Retirer la légende du deck"]').exists()).toBe(false)
  })

  it("sans légende : bouton Voir les légendes émet show-legends", async () => {
    const wrapper = mountList()
    expect(wrapper.text()).toContain("Choisissez votre légende : elle fixe les deux domaines du deck.")
    const button = wrapper.findAll("button").find((b) => b.text() === "Voir les légendes")
    await button.trigger("click")
    expect(wrapper.emitted("show-legends")).toHaveLength(1)

    await wrapper.setProps({ canEdit: false })
    expect(wrapper.text()).toContain("Ce deck n'a pas encore de légende")
    expect(wrapper.findAll("button").some((b) => b.text() === "Voir les légendes")).toBe(false)
  })

  it("− et + émettent set-qty", async () => {
    const wrapper = mountList()
    await wrapper.get('button[aria-label="Retirer un exemplaire de Phénix Immortel"]').trigger("click")
    await wrapper.get('button[aria-label="Ajouter un exemplaire de Phénix Immortel"]').trigger("click")
    const [first, second] = wrapper.emitted("set-qty")
    expect(first[0].card.id).toBe("u1")
    expect(first[1]).toBe(-1)
    expect(second[1]).toBe(1)
    expect(wrapper.get(".decklist-qty").text()).toBe("×3")
    expect(wrapper.get(".decklist-meters").text()).toContain("3/40+")

    await wrapper.setProps({ canEdit: false })
    expect(wrapper.find(".decklist-actions").exists()).toBe(false)
  })

  it("ligne flash et lacking", () => {
    const wrapper = mountList({ flashes: new Set(["u1"]) })
    const row = wrapper.get('[data-row="u1"]')
    expect(row.classes()).toContain("flash")
    expect(row.classes()).toContain("lacking")
    expect(row.get(".decklist-lack").text()).toBe("manque 2")
  })

  it("zone vide : texte tactile ou souris", async () => {
    const wrapper = mountList()
    const empties = () => wrapper.findAll(".decklist-empty").map((p) => p.text())
    expect(empties()).toEqual(["Glissez des cartes ici.", "Glissez des cartes ici."])
    await wrapper.setProps({ finePointer: false })
    expect(empties()[0]).toBe("Touchez une carte de la galerie pour l'ajouter.")
    await wrapper.setProps({ canEdit: false })
    expect(empties()[0]).toBe("Aucune carte dans cette zone.")
  })

  it("boutons −/+ atteignables au clavier : masqués par l'opacité, visibles au survol, au focus et au tactile", () => {
    /* jsdom ne calcule pas les styles des SFC : on vérifie les règles de la feuille. */
    const css = listSource.slice(listSource.indexOf("<style"))
    const base = css.match(/\n\.decklist-actions\s*\{([^}]*)\}/)[1]
    expect(base).not.toMatch(/display:\s*none/)
    expect(base).toMatch(/opacity:\s*0/)
    expect(base).toMatch(/pointer-events:\s*none/)
    const shown = css.match(
      /\.decklist-row:hover \.decklist-actions,\s*\.decklist-row:focus-within \.decklist-actions\s*\{([^}]*)\}/
    )[1]
    expect(shown).toMatch(/opacity:\s*1/)
    expect(shown).toMatch(/pointer-events:\s*auto/)
    const touch = css.match(/@media \(hover: none\)\s*\{(?:\s*\/\*[^*]*\*\/)?\s*\.decklist-actions\s*\{([^}]*)\}/)[1]
    expect(touch).toMatch(/opacity:\s*1/)
    expect(touch).toMatch(/pointer-events:\s*auto/)
    expect(css).not.toMatch(/\.decklist-actions\s*\{[^}]*display:\s*none/)
  })
})
