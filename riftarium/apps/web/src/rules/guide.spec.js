import { describe, expect, it } from "vitest"
import { CARDS, SPOTS, STEPS } from "./guide.js"
import { CHAPTERS } from "./learn.js"
import { TOPICS } from "./topics.js"

/* Cohérence du scénario du plateau animé : textes et scènes racontent la
   même partie (runes en zone, runes épuisées, réserve, Seal of Rage). */

const step = (key) => {
  const found = STEPS.find((s) => s.key === key)
  if (!found) throw new Error(`étape absente : ${key}`)
  return found
}
const text = (s) => s.text.join(" ")
const isRune = (c) => c.card === CARDS.furyRune || c.card === CARDS.chaosRune
/* Runes posées dans la zone de runes (ni le deck de runes face cachée, ni une
   rune recyclée en transit). */
const zoneRunes = (s) => s.scene.cards.filter((c) => isRune(c) && !c.facedown && !c.ghost && c.spot.y === SPOTS.runeA.y)
const tappedRunes = (s) => zoneRunes(s).filter((c) => c.tapped)
const gear = (s) => s.scene.cards.find((c) => c.card === CARDS.gear)
const index = (key) => STEPS.findIndex((s) => s.key === key)

describe("guide.js : scénario du plateau", () => {
  it("n'appelle jamais Get Excited! un sort « signature »", () => {
    for (const s of STEPS) expect(text(s)).not.toMatch(/signature/i)
    const draw = text(step("debut-tour"))
    expect(draw).toContain("Get Excited!")
    expect(draw).toMatch(/Action/)
    expect(draw).toMatch(/défausser/)
  })

  it("explique la défausse à sa première apparition et dans l'exténuation", () => {
    expect(text(step("mise-en-place"))).toMatch(/\*\*défausse\*\* \(la pile/)
    expect(text(step("victoire"))).toMatch(/défausse \(la pile/)
  })

  it("tour 1 : Legion Rearguard seul, 2 runes épuisées, Seal of Rage reste en main", () => {
    expect(index("recycler")).toBe(-1)
    const t1 = step("jouer")
    expect(zoneRunes(t1)).toHaveLength(2)
    expect(tappedRunes(t1)).toHaveLength(2)
    expect(gear(t1).hand).toBe(true)
    expect(text(step("energie"))).not.toContain("exactement de quoi jouer les deux")
    expect(gear(step("tour-adverse")).hand).toBe(true)
    expect(zoneRunes(step("tour-adverse"))).toHaveLength(2)
  })

  it("tour 2 : 4 runes, Flame Chompers en épuise 3, une reste préparée", () => {
    const t2 = step("tour2")
    expect(text(t2)).toMatch(/4 runes/)
    expect(zoneRunes(t2)).toHaveLength(4)
    expect(tappedRunes(t2)).toHaveLength(3)
    expect(t2.scene.chips).toEqual({ energy: 3 })
    expect(gear(t2).hand).toBe(true)
    /* Pendant son tour, vos runes ne se redressent pas. */
    expect(tappedRunes(step("tour2-adverse"))).toHaveLength(3)
  })

  it("tour 3 : recycler pour Seal of Rage et garder 2 énergies en réserve (règle 167)", () => {
    const t3 = step("tour3")
    expect(index("tour3")).toBe(index("deplacement") - 1)
    expect(t3.ref).toBe("167")
    const body = text(t3)
    expect(body).toMatch(/6 runes/)
    expect(body).toContain("Seal of Rage")
    expect(body).toMatch(/recycl/)
    expect(body).toMatch(/réserve runique/)
    expect(body).toMatch(/fin du tour/)
    expect(body).toMatch(/règle 167/)
    expect(zoneRunes(t3)).toHaveLength(5)
    expect(tappedRunes(t3)).toHaveLength(2)
    expect(t3.scene.cards.some((c) => isRune(c) && c.ghost)).toBe(true)
    expect(t3.scene.chips).toEqual({ energy: 2 })
    expect(gear(t3).hand).toBeFalsy()
    expect(gear(t3).tapped).toBeFalsy()
  })

  it("déplacement : la réserve attend toujours, Seal of Rage prêt", () => {
    const move = step("deplacement")
    expect(zoneRunes(move)).toHaveLength(5)
    expect(tappedRunes(move)).toHaveLength(2)
    expect(move.scene.chips).toEqual({ energy: 2 })
    expect(gear(move).tapped).toBeFalsy()
  })

  it("confrontation : Get Excited! payé par la réserve et Seal of Rage", () => {
    const clash = step("confrontation")
    const body = text(clash)
    expect(body).toMatch(/réserve/)
    expect(body).toContain("Seal of Rage")
    expect(body).toMatch(/Bouclier/)
    expect(body).toMatch(/4/)
    expect(zoneRunes(clash)).toHaveLength(5)
    expect(tappedRunes(clash)).toHaveLength(2)
    expect(clash.scene.chips).toBeUndefined()
    expect(gear(clash).tapped).toBe(true)
    for (const key of ["degats", "conquete"]) {
      expect(zoneRunes(step(key))).toHaveLength(5)
      expect(tappedRunes(step(key))).toHaveLength(2)
    }
  })

  it("tour 4 : 7 runes après canalisation, 6 après le recyclage, 5 épuisées", () => {
    const t4 = step("champion-elu")
    const body = text(t4)
    expect(body).toMatch(/7 runes/)
    expect(body).toMatch(/6 runes/)
    expect(zoneRunes(t4)).toHaveLength(6)
    expect(tappedRunes(t4)).toHaveLength(5)
    expect(t4.scene.chips).toEqual({ energy: 5, essence: 1 })
  })

  it("garde 17 étapes, toutes avec un texte et une scène", () => {
    expect(STEPS).toHaveLength(17)
    expect(new Set(STEPS.map((s) => s.key)).size).toBe(STEPS.length)
    for (const s of STEPS) {
      expect(s.text.length).toBeGreaterThan(0)
      expect(Array.isArray(s.scene.cards)).toBe(true)
    }
  })
})

describe("exténuation : la défausse est expliquée", () => {
  it("learn.js et topics.js disent ce qu'est la défausse", () => {
    const learn = JSON.stringify(CHAPTERS)
    expect(learn).toMatch(/Exténuation\*\* : [^"]*défausse \(la pile/)
    const duel = TOPICS.find((t) => t.slug === "mode-duel")
    const faq = duel.cases.map((f) => f.a).join(" ")
    expect(faq).toMatch(/Exténuation : [^"]*défausse \(la pile/)
  })
})
