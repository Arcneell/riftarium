import { describe, expect, it } from "vitest"
import { sectionOf } from "./router.js"

/* `sectionOf` alimente la mesure de fréquentation anonyme : une rubrique par page,
   jamais l'URL complète. L'ordre des `startsWith` est le point fragile — la fiche
   (`/cartes/:id`) doit être reconnue avant la liste (`/cartes`). */
describe("sectionOf", () => {
  it("distingue la fiche de la liste (cartes, decks)", () => {
    expect(sectionOf("/cartes")).toBe("cartes")
    expect(sectionOf("/cartes/")).toBe("carte")
    expect(sectionOf("/cartes/OGN-001")).toBe("carte")
    expect(sectionOf("/decks")).toBe("decks")
    expect(sectionOf("/decks/42")).toBe("deck")
  })

  it("ne compte jamais la console d'administration", () => {
    expect(sectionOf("/admin")).toBeNull()
    expect(sectionOf("/admin/utilisateurs")).toBeNull()
  })

  it("nomme chaque rubrique du site", () => {
    const expected = {
      "/": "home",
      "/regles": "regles",
      "/regles/debutant": "regles",
      "/regles/officielles": "regles",
      "/communaute": "communaute",
      "/collection": "collection",
      "/scan": "scan",
      "/profil": "profil",
      "/u/nyra": "profil-public",
      "/amis": "amis",
      "/historique": "historique",
      "/statistiques": "statistiques",
      "/salon": "salon",
      "/salon/AB12CD": "salon"
    }
    for (const [path, section] of Object.entries(expected)) expect(sectionOf(path)).toBe(section)
  })

  it("regroupe le reste sous « autre » (connexion, pages légales, 404)", () => {
    expect(sectionOf("/connexion")).toBe("autre")
    expect(sectionOf("/mentions-legales")).toBe("autre")
    expect(sectionOf("/wishlist")).toBe("autre")
    expect(sectionOf("/nawak")).toBe("autre")
  })

  it("« /u » sans pseudo n'est pas un profil public", () => {
    expect(sectionOf("/u")).toBe("autre")
  })
})
