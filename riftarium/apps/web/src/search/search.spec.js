import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", () => ({
  api: vi.fn(),
  cardThumb: (url, width) => `${url}?w=${width}`
}))
vi.mock("../rules/rulesStore.js", () => ({ loadRulesDocuments: vi.fn() }))

const { api } = await import("../api.js")
const { loadRulesDocuments } = await import("../rules/rulesStore.js")
const { buildRulesIndex, normalize, resetSearchCache, runSearch, searchPages, searchRules } =
  await import("./search.js")

const DOCUMENTS = {
  core: {
    title: "Règles du jeu",
    chapters: [
      {
        sections: [
          {
            id: "350",
            title: "Réactions",
            entries: [{ id: "351", number: "351.", text: "Une Réaction se joue pendant une chaîne." }]
          }
        ]
      }
    ]
  }
}
const TOPICS = [{ slug: "chaine", title: "La chaîne", summary: "Répondre à un sort adverse." }]

describe("normalize", () => {
  it("ignore accents, casse et espaces bordants", () => {
    expect(normalize("  Réaction ÉPÉE ")).toBe("reaction epee")
  })
})

describe("searchPages", () => {
  it("trouve une rubrique ou une sous-page par son libellé, accents ignorés", () => {
    expect(searchPages("regles").map((item) => item.to)).toContain("/regles")
    expect(searchPages("wish").map((item) => item.to)).toEqual(["/wishlist"])
  })
})

describe("règles", () => {
  const index = buildRulesIndex(DOCUMENTS, TOPICS)

  it("indexe les sujets d'aide puis les règles officielles, avec un lien vers la règle", () => {
    const hits = searchRules(index, "reaction chaine")
    expect(hits[0]).toMatchObject({ label: "351. Réactions", to: "/regles/officielles?doc=core&section=350&rule=351" })
  })

  it("trouve un sujet d'aide par son titre ou son résumé", () => {
    expect(searchRules(index, "repondre sort")[0]).toMatchObject({ to: "/regles/avancee/chaine" })
  })

  it("exige tous les mots de la requête", () => {
    expect(searchRules(index, "reaction dragon")).toEqual([])
  })
})

describe("runSearch", () => {
  beforeEach(() => {
    resetSearchCache()
    loadRulesDocuments.mockResolvedValue(DOCUMENTS)
  })
  afterEach(() => {
    vi.clearAllMocks()
  })

  it("ne lance rien sous deux caractères", async () => {
    expect(await runSearch(" a ")).toEqual([])
    expect(api).not.toHaveBeenCalled()
  })

  it("interroge cartes et decks en parallèle et regroupe les résultats", async () => {
    api.mockImplementation(async (path) =>
      path.startsWith("/api/cards")
        ? { items: [{ id: "ogn-1", name: "Ahri", riftbound_id: "ogn-001", image_url: "https://cdn/x.png" }] }
        : { items: [{ id: 7, name: "Ahri Contrôle", owner: "Kaelis" }] }
    )
    const groups = await runSearch("ahri")
    expect(api).toHaveBeenCalledWith("/api/cards?q=ahri&size=5", expect.any(Object))
    expect(api).toHaveBeenCalledWith("/api/community/decks?q=ahri&size=5", expect.any(Object))
    expect(groups.map((g) => g.key)).toEqual(["cards", "decks"])
    expect(groups[0].items[0]).toMatchObject({ label: "Ahri", hint: "OGN-001", to: "/cartes/ogn-1" })
    expect(groups[1].items[0]).toMatchObject({ label: "Ahri Contrôle", hint: "par Kaelis", to: "/decks/7" })
  })

  it("un groupe en échec est signalé sans masquer les autres", async () => {
    api.mockImplementation(async (path) => {
      if (path.startsWith("/api/community")) throw new Error("405")
      return { items: [] }
    })
    const groups = await runSearch("reaction")
    expect(groups.find((g) => g.key === "decks")).toMatchObject({ error: true, items: [] })
    expect(groups.find((g) => g.key === "rules").items.length).toBeGreaterThan(0)
  })

  it("encode la requête dans l'URL", async () => {
    api.mockResolvedValue({ items: [] })
    await runSearch("kai'sa & co")
    expect(api).toHaveBeenCalledWith("/api/cards?q=kai'sa%20%26%20co&size=5", expect.any(Object))
  })
})
