import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  TRADE_ZONES,
  actOnRequest,
  getCardOffers,
  getOffered,
  getOffers,
  getRequests,
  getRequestsSummary,
  ensureTradeSettings,
  getWanted,
  sendRequest,
  setOffer,
  statusLabel,
  tradeSettings,
  updateTradeSettings,
  zoneLabel
} from "./trades.js"
import { session } from "./api.js"

/* Les appels sont vérifiés au niveau du réseau (chemin, méthode, corps) :
   c'est ce que fige docs/echanges.md. */
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

describe("trades — zones et libellés", () => {
  it("expose les quatre zones de La Réunion", () => {
    expect(TRADE_ZONES.map((zone) => zone.value)).toEqual(["nord", "sud", "est", "ouest"])
    expect(zoneLabel("sud")).toBe("Sud")
    expect(zoneLabel(null)).toBe("")
  })

  it("nomme chaque statut de demande", () => {
    expect(statusLabel("pending")).toBe("En attente")
    expect(statusLabel("accepted")).toBe("Acceptée")
    expect(statusLabel("done")).toBe("Échange fait")
  })
})

describe("trades — réglages et offres", () => {
  it("enregistre les réglages par PATCH /api/auth/me", async () => {
    await updateTradeSettings({ trade_enabled: true, trade_zone: "sud", trade_contact: "Discord : nova" })
    expect(sent()).toEqual({
      path: "/api/auth/me",
      method: "PATCH",
      body: { trade_enabled: true, trade_zone: "sud", trade_contact: "Discord : nova" }
    })
  })

  it("lit et règle les offres d'un lot", async () => {
    await getOffers()
    expect(sent()).toMatchObject({ path: "/api/trades/offers", method: "GET" })
    await setOffer(12, 2)
    expect(sent(1)).toEqual({ path: "/api/trades/offers/12", method: "PUT", body: { qty: 2 } })
  })
})

describe("trades — correspondances", () => {
  it("passe zone, recherche et page à « ils ont ce que je cherche »", async () => {
    await getWanted({ zone: "nord", q: "ahri", page: 2 })
    expect(sent().path).toBe("/api/trades/matches/wanted?page=2&size=24&zone=nord&q=ahri")
    await getWanted()
    expect(sent(1).path).toBe("/api/trades/matches/wanted?page=1&size=24")
  })

  it("lit « ils cherchent ce que j'ai » et les offres d'une carte", async () => {
    await getOffered({ zone: "sud" })
    expect(sent().path).toBe("/api/trades/matches/offered?page=1&size=24&zone=sud")
    await getCardOffers("ogn-037-298")
    expect(sent(1).path).toBe("/api/trades/cards/ogn-037-298/offers")
  })
})

describe("trades — demandes", () => {
  it("envoie une demande avec son message", async () => {
    await sendRequest(7, "  salut  ")
    expect(sent()).toEqual({ path: "/api/trades/requests", method: "POST", body: { offer_id: 7, message: "salut" } })
  })

  it("liste, résume et fait évoluer les demandes", async () => {
    await getRequests("out")
    expect(sent().path).toBe("/api/trades/requests?box=out&page=1&size=50")
    await getRequestsSummary()
    expect(sent(1).path).toBe("/api/trades/requests/summary")
    await actOnRequest(3, "accept")
    expect(sent(2)).toMatchObject({ path: "/api/trades/requests/3/accept", method: "POST" })
  })
})

describe("trades — réglages partagés", () => {
  it("charge les réglages une fois et les met à jour à l'enregistrement", async () => {
    session.token = "1"
    tradeSettings.loaded = false
    fetchMock.mockResolvedValue({
      status: 200,
      ok: true,
      json: async () => ({ trade_enabled: true, trade_zone: "est", trade_contact: "x" })
    })
    await ensureTradeSettings()
    await ensureTradeSettings()
    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(tradeSettings).toMatchObject({ loaded: true, enabled: true, zone: "est" })

    fetchMock.mockResolvedValue({
      status: 200,
      ok: true,
      json: async () => ({ trade_enabled: false, trade_zone: "est" })
    })
    await updateTradeSettings({ trade_enabled: false })
    expect(tradeSettings.enabled).toBe(false)
    session.token = null
  })
})
