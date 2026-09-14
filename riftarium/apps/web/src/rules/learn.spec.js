import { describe, expect, it } from "vitest"
import { CHAPTERS, chapterBySlug, chapterPath, DEFAULT_CHAPTER, LEARN_INTRO } from "../rules/learn.js"

describe("learn.js", () => {
  it("expose neuf chapitres avec un aperçu en tête", () => {
    expect(CHAPTERS).toHaveLength(9)
    expect(DEFAULT_CHAPTER).toBe("apercu")
    expect(CHAPTERS[0].slug).toBe("apercu")
    expect(LEARN_INTRO).toContain("8 points")
  })

  it("résout les slugs et construit les chemins", () => {
    expect(chapterBySlug("tour").title).toBe("Le tour de jeu")
    expect(chapterBySlug("inconnu")).toBeNull()
    expect(chapterPath("apercu")).toBe("/regles/debutant")
    expect(chapterPath("combat")).toBe("/regles/debutant/combat")
  })

  it("chaque chapitre a un lead, une référence officielle et des blocs", () => {
    for (const chapter of CHAPTERS) {
      expect(chapter.lead.length).toBeGreaterThan(40)
      expect(chapter.ref).toMatch(/^\d+$/)
      expect(chapter.blocks.length).toBeGreaterThanOrEqual(2)
    }
  })
})
