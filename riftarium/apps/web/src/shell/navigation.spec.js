import { describe, expect, it } from "vitest"
import { activeChild, activeSection, breadcrumbOf, NAV, TABBAR_KEYS } from "./navigation.js"

describe("activeSection", () => {
  it.each([
    ["/", "home"],
    ["/cartes", "cards"],
    ["/cartes/ogn-001", "cards"],
    ["/decks/42", "decks"],
    ["/communaute", "decks"],
    ["/wishlist", "collection"],
    ["/regles/officielles", "rules"],
    ["/salon/ABCD", "play"],
    ["/historique", "play"]
  ])("%s → %s", (path, key) => {
    expect(activeSection(path)?.key).toBe(key)
  })

  it("ne confond pas un préfixe partiel ni une page hors rubrique", () => {
    expect(activeSection("/cartesX")).toBeNull()
    expect(activeSection("/profil")).toBeNull()
    expect(activeSection("/mentions-legales")).toBeNull()
  })
})

describe("activeChild", () => {
  const rules = NAV.find((s) => s.key === "rules")
  it("préfère le plus long préfixe", () => {
    expect(activeChild(rules, "/regles/debutant/plateau")?.label).toBe("Plateau animé")
    expect(activeChild(rules, "/regles/debutant/victoire")?.label).toBe("Apprendre")
  })
  it("renvoie null sur la page d'accueil de la rubrique ou sans enfants", () => {
    expect(activeChild(rules, "/regles")).toBeNull()
    expect(
      activeChild(
        NAV.find((s) => s.key === "cards"),
        "/cartes"
      )
    ).toBeNull()
  })
})

describe("breadcrumbOf", () => {
  it("rubrique puis sous-page, sans doublon de libellé", () => {
    expect(breadcrumbOf("/wishlist")).toEqual([
      { label: "Collection", to: "/collection" },
      { label: "Wishlist", to: "/wishlist" }
    ])
    expect(breadcrumbOf("/collection")).toEqual([{ label: "Collection", to: "/collection" }])
  })
  it("ajoute le maillon fourni par la page", () => {
    expect(breadcrumbOf("/cartes/ogn-001", "Ahri")).toEqual([{ label: "Cartes", to: "/cartes" }, { label: "Ahri" }])
  })
  it("accueil et pages hors rubrique", () => {
    expect(breadcrumbOf("/")).toEqual([{ label: "Accueil", to: "/" }])
    expect(breadcrumbOf("/profil", "Mon profil")).toEqual([{ label: "Mon profil" }])
  })
})

it("la barre d'onglets mobile garde Accueil et ne contient pas Jouer", () => {
  expect(TABBAR_KEYS).toEqual(["home", "cards", "decks", "collection", "rules"])
})
