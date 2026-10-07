import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import TableBoard from "./TableBoard.vue"
import { CARDS, SPOTS, STEPS } from "./guide.js"

const mountBoard = (scene) => mount(TableBoard, { props: { scene, spots: SPOTS, cards: CARDS } })

const baseScene = (extra = {}) => ({ cards: [], score: { you: 0, foe: 0 }, ...extra })

describe("TableBoard", () => {
  it("scène : cartes placées aux bons pourcentages", () => {
    const wrapper = mountBoard(
      baseScene({
        cards: [
          { key: "a", card: CARDS.chompers, spot: { x: 33.5, y: 47, r: -9 } },
          { key: "b", card: CARDS.spell, spot: SPOTS.mainDeck, facedown: true, tapped: true }
        ]
      })
    )
    const cards = wrapper.findAll(".plateau-card")
    expect(cards).toHaveLength(2)
    const first = cards[0].attributes("style")
    expect(first).toContain("left: 33.5%")
    expect(first).toContain("top: 47%")
    expect(first).toContain("--r: -9deg")
    expect(cards[1].attributes("style")).toContain(`left: ${SPOTS.mainDeck.x}%`)
    expect(cards[1].classes()).toContain("plateau-card--tapped")
    const bf = wrapper.findAll(".plateau-bf")
    expect(bf).toHaveLength(2)
    expect(bf[0].attributes("style")).toContain(`left: ${SPOTS.bfFoe.x}%`)
  })

  it("les zones nommées par aria-label portent role=group", () => {
    const wrapper = mountBoard(baseScene({ foeHand: 4, chips: { energy: 2 } }))
    for (const label of ["Main adverse", "Vos points", "Points adverses", "Réserve runique"]) {
      expect(wrapper.get(`[aria-label="${label}"]`).attributes("role")).toBe("group")
    }
  })

  it("champ contesté : classe", () => {
    const wrapper = mountBoard(baseScene({ contested: ["bfFoe"], control: { bfYou: "you" } }))
    const [foe, you] = wrapper.findAll(".plateau-bf")
    expect(foe.classes()).toContain("plateau-bf--contested")
    expect(foe.text()).toContain("Contesté")
    expect(you.classes()).not.toContain("plateau-bf--contested")
    expect(you.classes()).toContain("plateau-bf--controlled")
    expect(you.text()).toContain("À vous")
  })

  it("clic sur une carte face visible émet zoom, pas sur une face cachée", async () => {
    const wrapper = mountBoard(
      baseScene({
        cards: [
          { key: "up", card: CARDS.chompers, spot: SPOTS.hand1, hand: true },
          { key: "down", card: CARDS.spell, spot: SPOTS.mainDeck, facedown: true, label: "Deck principal" }
        ]
      })
    )
    const [up, down] = wrapper.findAll(".plateau-card")
    expect(up.element.tagName).toBe("BUTTON")
    expect(down.element.tagName).toBe("DIV")
    await down.trigger("click")
    expect(wrapper.emitted("zoom")).toBeUndefined()
    await up.trigger("click")
    expect(wrapper.emitted("zoom")).toEqual([[CARDS.chompers]])
  })

  it("le gros plan annoté émet aussi zoom", async () => {
    const step = STEPS.find((s) => s.scene.focus)
    const wrapper = mountBoard(step.scene)
    await wrapper.find(".plateau-focus").trigger("click")
    expect(wrapper.emitted("zoom")).toEqual([[step.scene.focus.card]])
  })

  it("score : gemmes remplies", () => {
    const wrapper = mountBoard(baseScene({ score: { you: 3, foe: 1 }, scorePulse: true }))
    expect(wrapper.findAll(".plateau-gem")).toHaveLength(16)
    const you = wrapper.findAll(".plateau-score--you .plateau-gem")
    expect(you.filter((g) => g.classes("plateau-gem--filled"))).toHaveLength(3)
    expect(you[2].classes()).toContain("plateau-gem--pulse")
    const foe = wrapper.findAll(".plateau-score--foe .plateau-gem")
    expect(foe.filter((g) => g.classes("plateau-gem--filled"))).toHaveLength(1)
  })

  it("réserve : énergie en glyphe Riot", () => {
    const wrapper = mountBoard(baseScene({ chips: { energy: 2, essence: 1 } }))
    const energy = wrapper.findAll(".plateau-chip--energy img")
    expect(energy).toHaveLength(2)
    expect(energy[0].attributes("src")).toContain("energy_1")
    expect(wrapper.findAll(".plateau-chip--essence")).toHaveLength(1)
  })
})
