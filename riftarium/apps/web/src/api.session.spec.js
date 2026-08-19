import { afterEach, describe, expect, it, vi } from "vitest"

describe("session", () => {
  afterEach(() => {
    localStorage.clear()
    vi.unstubAllGlobals()
    vi.resetModules()
  })

  it("ne persiste plus le JWT dans localStorage", async () => {
    const { setSession, session } = await import("./api.js")
    setSession("aaa.bbb.ccc", "nyra", "https://cmsassets.rgpub.io/x.png")
    expect(localStorage.getItem("riftarium_token")).toBeNull()
    expect(localStorage.getItem("riftarium_session")).toBe("1")
    expect(session.token).toBe("1")
    expect(session.handle).toBe("nyra")
  })

  it("envoie les cookies sans jamais ajouter de header Authorization", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      status: 200,
      ok: true,
      json: async () => ({ ok: true })
    })
    vi.stubGlobal("fetch", fetchMock)
    const { api, session } = await import("./api.js")
    session.token = "1"
    await api("/api/auth/me")
    expect(fetchMock.mock.calls[0][1].credentials).toBe("include")
    expect(fetchMock.mock.calls[0][1].headers.Authorization).toBeUndefined()
  })

  it("sur 401 : ferme la session locale et émet riftarium:session-expired", async () => {
    const fetchMock = vi.fn().mockResolvedValue({ status: 401, ok: false, json: async () => ({}) })
    vi.stubGlobal("fetch", fetchMock)
    const expired = vi.fn()
    window.addEventListener("riftarium:session-expired", expired)
    const { api, session } = await import("./api.js")
    session.token = "1"
    await expect(api("/api/auth/me")).rejects.toMatchObject({ status: 401, message: "Connexion requise" })
    expect(session.token).toBeNull()
    expect(expired).toHaveBeenCalledTimes(1)
    window.removeEventListener("riftarium:session-expired", expired)
  })

  it("rend lisible le detail des erreurs 422 de FastAPI", async () => {
    const detail = [{ loc: ["body", "email"], msg: "Adresse email invalide", type: "value_error" }]
    const fetchMock = vi.fn().mockResolvedValue({ status: 422, ok: false, json: async () => ({ detail }) })
    vi.stubGlobal("fetch", fetchMock)
    const { api } = await import("./api.js")
    await expect(api("/api/auth/register", { method: "POST", body: {} })).rejects.toMatchObject({
      status: 422,
      message: "Adresse email invalide"
    })
  })

  it("traduit un 405 HTML (BunkerWeb) au lieu de « Erreur inattendue »", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      status: 405,
      ok: false,
      json: async () => {
        throw new Error("HTML")
      }
    })
    vi.stubGlobal("fetch", fetchMock)
    const { api } = await import("./api.js")
    await expect(api("/api/auth/me", { method: "PATCH", body: {} })).rejects.toMatchObject({
      status: 405,
      message: "Action bloquée par le pare-feu du site"
    })
  })

  it("retombe sur « Requête invalide » quand le detail 422 est inexploitable", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      status: 422,
      ok: false,
      json: async () => ({ detail: [{ type: "value_error" }] })
    })
    vi.stubGlobal("fetch", fetchMock)
    const { api } = await import("./api.js")
    await expect(api("/api/x")).rejects.toMatchObject({ message: "Requête invalide" })
  })
})
