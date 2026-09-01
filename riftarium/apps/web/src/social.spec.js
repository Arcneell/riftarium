import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  PRIVACY_TOGGLES,
  achievementGlyph,
  achievementPercent,
  achievementProgress,
  followUser,
  formatMemberSince,
  formatUnlockedAt,
  getFollows,
  getMyAchievements,
  getPublicProfile,
  getUserCollection,
  getUserHistory,
  groupAchievements,
  isUnlocked,
  profilePath,
  searchUsers,
  setPercent,
  tierLabel,
  unfollowUser,
  unlockedFirst,
  updatePrivacy
} from "./social.js"

/* Comme pour play.js, les appels sont vérifiés au niveau du réseau (chemin,
   méthode, corps) : c'est ce que fige docs/profils-et-hauts-faits.md. */
let fetchMock

function sent(index = 0) {
  const [path, options] = fetchMock.mock.calls[index]
  return { path, method: options.method, body: options.body ? JSON.parse(options.body) : undefined }
}

beforeEach(() => {
  fetchMock = vi.fn().mockResolvedValue({ status: 200, ok: true, json: async () => ({ ok: true }) })
  vi.stubGlobal("fetch", fetchMock)
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("social — profils publics", () => {
  it("lit un profil public par son pseudo", async () => {
    await getPublicProfile("nova")
    expect(sent()).toMatchObject({ path: "/api/users/nova", method: "GET" })
  })

  it("encode le pseudo dans le chemin", async () => {
    await getPublicProfile("a/b c")
    expect(sent().path).toBe("/api/users/a%2Fb%20c")
  })

  it("pagine la collection publique et borne la taille de page", async () => {
    await getUserCollection("nova", { page: 3, size: 500, q: "jinx", setId: "ogn" })
    const { path } = sent()
    expect(path.startsWith("/api/users/nova/collection?")).toBe(true)
    const params = new URLSearchParams(path.split("?")[1])
    expect(params.get("page")).toBe("3")
    expect(params.get("size")).toBe("60")
    expect(params.get("q")).toBe("jinx")
    expect(params.get("set_id")).toBe("ogn")
  })

  it("n'envoie ni q ni set_id quand ils sont vides", async () => {
    await getUserCollection("nova")
    const params = new URLSearchParams(sent().path.split("?")[1])
    expect(params.has("q")).toBe(false)
    expect(params.has("set_id")).toBe(false)
  })

  it("lit l'historique public page par page", async () => {
    await getUserHistory("nova", 2, 10)
    expect(sent().path).toBe("/api/users/nova/history?page=2&size=10")
  })

  it("cherche un joueur par pseudo", async () => {
    await searchUsers("no va")
    expect(sent().path).toBe("/api/users/search?q=no%20va")
  })

  it("construit l'adresse du profil public", () => {
    expect(profilePath("nova")).toBe("/u/nova")
    expect(profilePath("a b")).toBe("/u/a%20b")
  })
})

describe("social — amis", () => {
  it("lit les suivis et les abonnés", async () => {
    await getFollows()
    expect(sent()).toMatchObject({ path: "/api/me/follows", method: "GET" })
  })

  it("suit et cesse de suivre un joueur", async () => {
    fetchMock.mockResolvedValue({ status: 204, ok: true, json: async () => ({}) })
    await followUser("nova")
    expect(sent()).toMatchObject({ path: "/api/users/nova/follow", method: "PUT" })
    await unfollowUser("nova")
    expect(sent(1)).toMatchObject({ path: "/api/users/nova/follow", method: "DELETE" })
  })
})

describe("social — hauts faits et confidentialité", () => {
  it("lit le catalogue des hauts faits du compte", async () => {
    await getMyAchievements()
    expect(sent()).toMatchObject({ path: "/api/me/achievements", method: "GET" })
  })

  it("enregistre un réglage de confidentialité par PATCH /api/auth/me", async () => {
    await updatePrivacy({ show_stats: true })
    expect(sent()).toEqual({ path: "/api/auth/me", method: "PATCH", body: { show_stats: true } })
  })

  it("expose les quatre réglages du contrat", () => {
    expect(PRIVACY_TOGGLES.map((item) => item.key)).toEqual([
      "show_achievements",
      "show_stats",
      "show_collection",
      "show_decks"
    ])
    expect(PRIVACY_TOGGLES.every((item) => item.label && item.hint)).toBe(true)
  })
})

describe("social — libellés et progression", () => {
  it("nomme les paliers en français, avec repli sur le bronze", () => {
    expect(tierLabel("bronze")).toBe("Bronze")
    expect(tierLabel("silver")).toBe("Argent")
    expect(tierLabel("gold")).toBe("Or")
    expect(tierLabel("prism")).toBe("Prisme")
    expect(tierLabel("inconnu")).toBe("Bronze")
  })

  it("rend un glyphe sobre pour une icône Material, connue ou non", () => {
    expect(achievementGlyph("emoji_events")).toBe("✪")
    expect(achievementGlyph("une_icone_que_le_web_ne_connait_pas")).toBe("✪")
  })

  it("chiffre la progression et la borne au seuil", () => {
    expect(achievementPercent({ current: 3, threshold: 10 })).toBe(30)
    expect(achievementPercent({ current: 42, threshold: 10 })).toBe(100)
    expect(achievementPercent({ current: 0, threshold: 0 })).toBe(0)
    /* Débloqué : la barre est pleine même si la métrique a été recalculée depuis. */
    expect(achievementPercent({ current: 1, threshold: 10, unlocked_at: "2026-08-01T10:00:00Z" })).toBe(100)
    expect(achievementProgress({ current: 3, threshold: 10 })).toBe("3 / 10")
    expect(achievementProgress({ current: 99, threshold: 10 })).toBe("10 / 10")
  })

  it("reconnaît un haut fait débloqué à sa date", () => {
    expect(isUnlocked({ unlocked_at: "2026-08-01T10:00:00Z" })).toBe(true)
    expect(isUnlocked({ unlocked_at: null })).toBe(false)
  })

  it("groupe par famille dans l'ordre du contrat, débloqués en tête", () => {
    const groups = groupAchievements([
      { key: "architect_1", family: "decks", current: 1, threshold: 1, unlocked_at: null },
      { key: "veteran_10", family: "duels", current: 4, threshold: 10, unlocked_at: null },
      { key: "first_blood", family: "duels", current: 1, threshold: 1, unlocked_at: "2026-08-01T10:00:00Z" },
      { key: "streak_3", family: "duels", current: 1, threshold: 3, unlocked_at: null }
    ])
    expect(groups.map((group) => group.family)).toEqual(["duels", "decks"])
    expect(groups[0].label).toBe("Duels")
    expect(groups[0].unlocked).toBe(1)
    expect(groups[0].total).toBe(3)
    /* Débloqué d'abord, puis le plus proche de son seuil. */
    expect(groups[0].items.map((item) => item.key)).toEqual(["first_blood", "veteran_10", "streak_3"])
  })

  it("range les hauts faits publics du plus récent au plus ancien", () => {
    const list = unlockedFirst([
      { key: "a", unlocked_at: "2026-01-05T10:00:00Z" },
      { key: "b", unlocked_at: "2026-08-05T10:00:00Z" }
    ])
    expect(list.map((item) => item.key)).toEqual(["b", "a"])
  })

  it("met en forme les dates, et reste muet sur une date absente ou illisible", () => {
    expect(formatMemberSince("2026-01-15T10:00:00Z")).toBe("janvier 2026")
    expect(formatMemberSince("")).toBe("")
    expect(formatMemberSince("pas une date")).toBe("")
    expect(formatUnlockedAt("2026-08-12T19:30:00Z")).toContain("12")
    expect(formatUnlockedAt(null)).toBe("")
  })

  it("chiffre la part possédée d'un set", () => {
    expect(setPercent({ owned: 25, total: 100 })).toBe(25)
    expect(setPercent({ owned: 0, total: 0 })).toBe(0)
    expect(setPercent({ owned: 120, total: 100 })).toBe(100)
  })
})
