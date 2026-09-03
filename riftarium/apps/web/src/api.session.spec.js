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

  it("un mauvais mot de passe à la connexion ne vide pas la session", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      status: 401,
      ok: false,
      json: async () => ({ detail: "Identifiants invalides" })
    })
    vi.stubGlobal("fetch", fetchMock)
    const expired = vi.fn()
    window.addEventListener("riftarium:session-expired", expired)
    const { api, session } = await import("./api.js")
    session.token = "1"
    session.handle = "nyra"
    await expect(
      api("/api/auth/login", { method: "POST", body: { email: "n@r.re", password: "oups" } })
    ).rejects.toMatchObject({
      status: 401,
      message: "Identifiants invalides"
    })
    expect(session.token).toBe("1")
    expect(session.handle).toBe("nyra")
    expect(expired).not.toHaveBeenCalled()
    window.removeEventListener("riftarium:session-expired", expired)
  })

  it("un mot de passe actuel refusé (PATCH /me, POST /password) ne déconnecte pas non plus", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      status: 401,
      ok: false,
      json: async () => ({ detail: "Mot de passe actuel incorrect" })
    })
    vi.stubGlobal("fetch", fetchMock)
    const { api, session } = await import("./api.js")
    session.token = "1"
    for (const [path, method, body] of [
      ["/api/auth/me", "PATCH", { email: "n@r.re", current_password: "oups" }],
      ["/api/auth/me", "DELETE", { password: "oups" }],
      ["/api/auth/password", "POST", { current_password: "oups", new_password: "x" }],
      ["/api/auth/register", "POST", { handle: "n", email: "n@r.re", password: "oups" }]
    ]) {
      await expect(api(path, { method, body })).rejects.toMatchObject({
        status: 401,
        message: "Mot de passe actuel incorrect"
      })
    }
    expect(session.token).toBe("1")
  })

  it("un 401 sur PATCH /api/auth/me SANS mot de passe (portrait) est une session expirée", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      status: 401,
      ok: false,
      json: async () => ({ detail: "Jeton invalide ou expiré" })
    })
    vi.stubGlobal("fetch", fetchMock)
    const expired = vi.fn()
    window.addEventListener("riftarium:session-expired", expired)
    const { api, session } = await import("./api.js")
    session.token = "1"
    await expect(api("/api/auth/me", { method: "PATCH", body: { avatar_card_id: "OGN-001" } })).rejects.toMatchObject({
      status: 401,
      message: "Connexion requise"
    })
    expect(session.token).toBeNull()
    expect(expired).toHaveBeenCalled()
    window.removeEventListener("riftarium:session-expired", expired)
  })

  it("un 401 sur GET /api/auth/me ferme bien la session (route sans mot de passe)", async () => {
    const fetchMock = vi.fn().mockResolvedValue({ status: 401, ok: false, json: async () => ({}) })
    vi.stubGlobal("fetch", fetchMock)
    const { api, session } = await import("./api.js")
    session.token = "1"
    await expect(api("/api/auth/me")).rejects.toMatchObject({ status: 401, message: "Connexion requise" })
    expect(session.token).toBeNull()
  })

  it("émet riftarium:session-closed quand la session locale est fermée", async () => {
    const closed = vi.fn()
    window.addEventListener("riftarium:session-closed", closed)
    const { setSession } = await import("./api.js")
    setSession("aaa", "nyra")
    expect(closed).not.toHaveBeenCalled()
    setSession(null, null)
    expect(closed).toHaveBeenCalledTimes(1)
    window.removeEventListener("riftarium:session-closed", closed)
  })

  it("transmet le signal d'annulation à fetch", async () => {
    const fetchMock = vi.fn().mockResolvedValue({ status: 200, ok: true, json: async () => ({}) })
    vi.stubGlobal("fetch", fetchMock)
    const { api } = await import("./api.js")
    const controller = new AbortController()
    await api("/api/cards", { signal: controller.signal })
    expect(fetchMock.mock.calls[0][1].signal).toBe(controller.signal)
  })

  it("rend lisible un detail objet ({msg} ou {message})", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      status: 400,
      ok: false,
      json: async () => ({ detail: { msg: "Deck introuvable" } })
    })
    vi.stubGlobal("fetch", fetchMock)
    const { api } = await import("./api.js")
    await expect(api("/api/x")).rejects.toMatchObject({ message: "Deck introuvable" })
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
