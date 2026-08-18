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

  it("envoie les cookies et n'ajoute un Bearer que pour un JWT", async () => {
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

    session.token = "aaa.bbb.ccc"
    await api("/api/auth/me")
    expect(fetchMock.mock.calls[1][1].headers.Authorization).toBe("Bearer aaa.bbb.ccc")
  })
})
