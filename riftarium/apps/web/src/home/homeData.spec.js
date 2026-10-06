import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", () => ({ api: vi.fn() }))

const { api } = await import("../api.js")
const { BANNERS } = await import("../banners.js")
const { completion, latestSet, loadMemberSummary, outcomeLabel, pickSplash, SPLASH_KEYS, wallCards } =
  await import("./homeData.js")

afterEach(() => vi.clearAllMocks())

describe("pickSplash", () => {
  it("choisit un visuel parmi les clés retenues", () => {
    expect(pickSplash(() => 0)).toBe(BANNERS[SPLASH_KEYS[0]])
    expect(pickSplash(() => 0.999)).toBe(BANNERS[SPLASH_KEYS[SPLASH_KEYS.length - 1]])
  })
})

describe("latestSet", () => {
  it("prend la date de publication la plus récente", () => {
    const sets = [
      { set_id: "ogn", published_on: "2025-10-31" },
      { set_id: "sfd", published_on: "2026-02-13" },
      { set_id: "x", published_on: null }
    ]
    expect(latestSet(sets).set_id).toBe("sfd")
  })
  it("un petit set promo plus récent ne masque pas le dernier vrai set", () => {
    const sets = [
      { set_id: "sfd", card_count: 250, published_on: "2026-02-13" },
      { set_id: "promo", card_count: 12, published_on: "2026-06-01" }
    ]
    expect(latestSet(sets).set_id).toBe("sfd")
  })
  it("sans set assez grand, garde le comportement actuel", () => {
    const sets = [
      { set_id: "a", card_count: 10, published_on: "2026-01-01" },
      { set_id: "b", card_count: 12, published_on: "2026-06-01" }
    ]
    expect(latestSet(sets).set_id).toBe("b")
  })
  it("renvoie null pour une liste vide ou absente", () => {
    expect(latestSet([])).toBeNull()
    expect(latestSet(undefined)).toBeNull()
  })
  it("sans aucune date, prend le dernier de la liste", () => {
    expect(latestSet([{ set_id: "a" }, { set_id: "b" }]).set_id).toBe("b")
  })
})

describe("wallCards", () => {
  it("écarte les cartes sans visuel et les cartes paysage, et plafonne", () => {
    const items = [
      { id: 1, image_url: "a" },
      { id: 2, image_url: null },
      { id: 3, image_url: "c", orientation: "landscape" },
      { id: 4, image_url: "d" }
    ]
    expect(wallCards(items).map((c) => c.id)).toEqual([1, 4])
    expect(wallCards(items, 1).map((c) => c.id)).toEqual([1])
    expect(wallCards(undefined)).toEqual([])
  })
})

describe("completion", () => {
  it("calcule le pourcentage arrondi", () => {
    expect(completion({ owned: 1, total: 3 })).toEqual({ owned: 1, total: 3, percent: 33 })
  })
  it("renvoie null sans total", () => {
    expect(completion({ owned: 0, total: 0 })).toBeNull()
    expect(completion(null)).toBeNull()
  })
  it("renvoie null sans aucune carte possédée", () => {
    expect(completion({ owned: 0, total: 300 })).toBeNull()
    expect(completion({ total: 300 })).toBeNull()
  })
})

describe("outcomeLabel", () => {
  it.each([
    ["win", "Victoire"],
    ["loss", "Défaite"],
    ["disputed", "Contesté"],
    [null, "Partie"]
  ])("%s → %s", (outcome, label) => {
    expect(outcomeLabel(outcome)).toBe(label)
  })
})

describe("loadMemberSummary", () => {
  it("rassemble collection, dernier deck et dernier match", async () => {
    api.mockImplementation(async (path) => {
      if (path === "/api/collection/sets") return { sets: [], overall: { owned: 120, total: 300 } }
      if (path === "/api/decks/mine")
        return [
          { id: 9, name: "Lee Sin Tempo" },
          { id: 3, name: "Ancien" }
        ]
      if (path === "/api/play/history?size=1") return { items: [{ match_id: 4, outcome: "win" }] }
      throw new Error(path)
    })
    const summary = await loadMemberSummary()
    expect(summary.collection).toEqual({ owned: 120, total: 300, percent: 40 })
    expect(summary.deck).toMatchObject({ id: 9, name: "Lee Sin Tempo" })
    expect(summary.match).toMatchObject({ match_id: 4 })
  })

  it("un appel en échec ou vide donne null sans masquer les autres", async () => {
    api.mockImplementation(async (path) => {
      if (path === "/api/collection/sets") return { sets: [], overall: { owned: 0, total: 0 } }
      if (path === "/api/decks/mine") return []
      throw new Error("500")
    })
    expect(await loadMemberSummary()).toEqual({ collection: null, deck: null, match: null })
  })

  it("transmet le signal d'annulation", async () => {
    api.mockResolvedValue({})
    const controller = new AbortController()
    await loadMemberSummary({ signal: controller.signal })
    for (const call of api.mock.calls) expect(call[1]).toEqual({ signal: controller.signal })
  })
})
