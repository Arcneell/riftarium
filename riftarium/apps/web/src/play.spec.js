import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  abandonMatch,
  cancelRoom,
  confirmMatch,
  createRoom,
  disputeMatch,
  formatPlayedAt,
  formatWinRate,
  getCurrent,
  getHistory,
  getMatch,
  getRoom,
  getStats,
  joinRoom,
  leaveRoom,
  matchStatusLabel,
  modeLabel,
  outcomeLabel,
  outcomeTone,
  roomStatusLabel,
  startRoom,
  updateMe,
  winRatePercent
} from "./play.js"

/* Les appels sont vérifiés au niveau du réseau (chemin, méthode, corps) : c'est
   exactement ce que fige le contrat docs/suivi-des-matchs.md. */
let fetchMock

/* Intl insère une espace insécable étroite devant « % » : on la neutralise. */
const plain = (value) => value.replace(/[\u202f\u00a0]/g, " ")

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

describe("play — salons", () => {
  it("crée un salon avec le mode demandé", async () => {
    await createRoom("duel")
    expect(sent()).toEqual({ path: "/api/play/rooms", method: "POST", body: { mode: "duel" } })
  })

  it("lit un salon par son code", async () => {
    await getRoom("ABC234")
    expect(sent()).toMatchObject({ path: "/api/play/rooms/ABC234", method: "GET" })
  })

  it("encode le code du salon dans le chemin", async () => {
    await getRoom("A/B 2")
    expect(sent().path).toBe("/api/play/rooms/A%2FB%202")
  })

  it("rejoint un salon", async () => {
    await joinRoom("ABC234")
    expect(sent()).toMatchObject({ path: "/api/play/rooms/ABC234/join", method: "POST" })
  })

  it("met à jour ses propres choix en PUT", async () => {
    await updateMe("ABC234", { legend_card_id: "leg-1", deck_id: 7, ready: true })
    expect(sent()).toEqual({
      path: "/api/play/rooms/ABC234/me",
      method: "PUT",
      body: { legend_card_id: "leg-1", deck_id: 7, ready: true }
    })
  })

  it("quitte, annule et lance un salon", async () => {
    await leaveRoom("ABC234")
    await cancelRoom("ABC234")
    await startRoom("ABC234", 12)
    expect(sent(0)).toMatchObject({ path: "/api/play/rooms/ABC234/leave", method: "POST" })
    expect(sent(1)).toMatchObject({ path: "/api/play/rooms/ABC234", method: "DELETE" })
    expect(sent(2)).toEqual({
      path: "/api/play/rooms/ABC234/start",
      method: "POST",
      body: { first_player_id: 12 }
    })
  })
})

describe("play — matchs", () => {
  it("lit un match et pose les trois verdicts", async () => {
    await getMatch(31)
    await confirmMatch(31)
    await disputeMatch(31)
    await abandonMatch(31)
    expect(sent(0)).toMatchObject({ path: "/api/play/matches/31", method: "GET" })
    expect(sent(1)).toMatchObject({ path: "/api/play/matches/31/confirm", method: "POST" })
    expect(sent(2)).toMatchObject({ path: "/api/play/matches/31/dispute", method: "POST" })
    expect(sent(3)).toMatchObject({ path: "/api/play/matches/31/abandon", method: "POST" })
  })
})

describe("play — historique, statistiques, reprise", () => {
  it("pagine l'historique, page 1 et taille 20 par défaut", async () => {
    await getHistory()
    await getHistory(3, 50)
    expect(sent(0).path).toBe("/api/play/history?page=1&size=20")
    expect(sent(1).path).toBe("/api/play/history?page=3&size=50")
  })

  it("lit les statistiques et la partie en cours", async () => {
    await getStats()
    await getCurrent()
    expect(sent(0)).toMatchObject({ path: "/api/play/stats", method: "GET" })
    expect(sent(1)).toMatchObject({ path: "/api/play/current", method: "GET" })
  })
})

describe("play — mise en forme", () => {
  it("nomme les formats de la v1", () => {
    expect(modeLabel("duel")).toBe("Duel")
    expect(modeLabel("match")).toBe("Match")
    expect(modeLabel("libre")).toBe("—")
  })

  it("nomme les issues et leur donne un ton", () => {
    expect(outcomeLabel("win")).toBe("Victoire")
    expect(outcomeLabel("loss")).toBe("Défaite")
    expect(outcomeLabel("disputed")).toBe("Contesté")
    expect(outcomeTone("win")).toBe("calm")
    expect(outcomeTone("loss")).toBe("fury")
    expect(outcomeTone("disputed")).toBe("neutral")
  })

  it("nomme les statuts de salon et de match", () => {
    expect(roomStatusLabel("open")).toBe("En attente d'un adversaire")
    expect(roomStatusLabel("cancelled")).toBe("Salon annulé")
    expect(matchStatusLabel("awaiting_confirmation")).toBe("En attente de confirmation")
    expect(matchStatusLabel("abandoned")).toBe("Abandon")
  })

  it("formate le taux de victoire, qu'il arrive en ratio ou en pourcentage", () => {
    expect(plain(formatWinRate(0.62))).toBe("62 %")
    expect(plain(formatWinRate(62))).toBe("62 %")
    expect(plain(formatWinRate(1))).toBe("100 %")
    expect(formatWinRate(null)).toBe("—")
    expect(formatWinRate("nan")).toBe("—")
  })

  it("borne la largeur de barre entre 0 et 100", () => {
    expect(winRatePercent(0.62)).toBe(62)
    expect(winRatePercent(150)).toBe(100)
    expect(winRatePercent(null)).toBe(0)
  })

  it("ne rend rien pour une date absente ou illisible", () => {
    expect(formatPlayedAt(null)).toBe("")
    expect(formatPlayedAt("pas une date")).toBe("")
    expect(formatPlayedAt("2026-08-12T19:30:00Z")).toContain("2026")
  })
})
