import { readFileSync } from "node:fs"
import { describe, expect, it, vi } from "vitest"

/* public/sw.js n'est pas un module : il s'exécute dans un contexte `ServiceWorkerGlobalScope`
   (self, caches, clients…) qu'aucun import ne peut fournir. On l'évalue donc dans une
   fonction dont les paramètres masquent exactement ces globales — c'est la seule façon de
   tester les stratégies de cache sans navigateur, et elles valent trop cher pour rester
   non testées : une erreur y rend le site inutilisable hors ligne (voire en ligne).

   Chemin relatif au dossier de l'application : vitest s'y exécute (racine de la config),
   et `import.meta.url` est réécrit en URL http par la transformation de Vite. */
const SOURCE = readFileSync("public/sw.js", "utf8")

const ORIGIN = "https://riftarium.re"

/** Réponse minimale : seul `ok` compte pour les stratégies, `clone` doit exister. */
function fakeResponse(body, { ok = true, status = 200 } = {}) {
  const response = { body, ok, status }
  response.clone = () => ({ ...response, clone: response.clone })
  return response
}

/** Cache minimal, mais fidèle sur ce qui est testé : clé = URL absolue. */
function fakeCache(entries = {}) {
  const store = new Map(Object.entries(entries).map(([key, value]) => [new URL(key, ORIGIN).href, value]))
  const cache = {
    store,
    match: vi.fn(async (request) => store.get(urlOf(request))),
    put: vi.fn(async (request, response) => {
      store.set(urlOf(request), response)
    }),
    add: vi.fn(async (request) => {
      store.set(urlOf(request), fakeResponse("ajouté"))
    }),
    addAll: vi.fn(async (requests) => {
      for (const request of requests) await cache.add(request)
    }),
    keys: vi.fn(async () => [...store.keys()].map((url) => ({ url }))),
    delete: vi.fn(async (request) => store.delete(urlOf(request)))
  }
  return cache
}

function urlOf(request) {
  return new URL(typeof request === "string" ? request : request.url, ORIGIN).href
}

/** Requête minimale telle que la voit le handler `fetch`. */
function fakeRequest(path, { method = "GET", mode = "no-cors" } = {}) {
  return { url: new URL(path, ORIGIN).href, method, mode }
}

/** Évalue le service worker et rend ses handlers, plus les doublures observables.
    `assets` remplace la liste vide de la source par ce que le build injecterait. */
function loadSw({ cache = fakeCache(), fetchImpl = vi.fn(), assets = [] } = {}) {
  const listeners = {}
  const networkError = fakeResponse("erreur réseau", { ok: false, status: 0 })
  const self = {
    addEventListener: (type, handler) => {
      listeners[type] = handler
    },
    location: { origin: ORIGIN },
    skipWaiting: vi.fn(),
    clients: { claim: vi.fn() }
  }
  const caches = {
    open: vi.fn(async () => cache),
    keys: vi.fn(async () => ["riftarium-v1"]),
    delete: vi.fn(async () => true),
    match: vi.fn(async (request) => cache.match(request))
  }
  const Response = { error: () => networkError }
  const source = SOURCE.replace("const ASSETS = []", `const ASSETS = ${JSON.stringify(assets)}`)
  new Function("self", "caches", "fetch", "Response", source)(self, caches, fetchImpl, Response)
  return { listeners, cache, caches, fetchImpl, self, networkError }
}

/** Déclenche le handler `fetch` et rend ce qui a été passé à respondWith (undefined si rien). */
function handleFetch(sw, request) {
  let responded
  sw.listeners.fetch({ request, respondWith: (value) => (responded = value) })
  return responded
}

describe("service worker", () => {
  it("l'API n'est jamais interceptée (ni cache, ni respondWith)", () => {
    const sw = loadSw()
    expect(handleFetch(sw, fakeRequest("/api/cards?q=ashe"))).toBeUndefined()
    expect(handleFetch(sw, fakeRequest("/api/auth/me"))).toBeUndefined()
    expect(sw.fetchImpl).not.toHaveBeenCalled()
  })

  it("laisse passer les écritures et les origines tierces sans y toucher", () => {
    const sw = loadSw()
    expect(handleFetch(sw, fakeRequest("/assets/index-abc.js", { method: "POST" }))).toBeUndefined()
    expect(handleFetch(sw, { url: "https://cmsassets.rgpub.io/x.png", method: "GET", mode: "no-cors" })).toBeUndefined()
  })

  it("cache-first : une réponse non-200 n'est pas mise en cache", async () => {
    const sw = loadSw({ fetchImpl: vi.fn(async () => fakeResponse("404", { ok: false, status: 404 })) })
    const response = await handleFetch(sw, fakeRequest("/assets/RulesView-abc.js"))
    expect(response.status).toBe(404)
    /* Mettre un 404 en cache-first le figerait pour toujours : le fichier resterait
       introuvable même après le déploiement qui le corrige. */
    expect(sw.cache.put).not.toHaveBeenCalled()
  })

  it("cache-first : la réponse 200 est servie puis mémorisée, le cache court-circuite le réseau", async () => {
    const sw = loadSw({ fetchImpl: vi.fn(async () => fakeResponse("moteur ocr")) })
    await handleFetch(sw, fakeRequest("/ocr/7.0.0/worker.min.js"))
    expect(sw.cache.put).toHaveBeenCalled()

    const again = await handleFetch(sw, fakeRequest("/ocr/7.0.0/worker.min.js"))
    expect(again.body).toBe("moteur ocr")
    expect(sw.fetchImpl).toHaveBeenCalledTimes(1) // le second passage ne va plus au réseau
  })

  it("stale-while-revalidate hors ligne et sans cache : une vraie erreur, pas `undefined`", async () => {
    const sw = loadSw({ fetchImpl: vi.fn(async () => Promise.reject(new Error("hors ligne"))) })
    const response = await handleFetch(sw, fakeRequest("/data/rules-fr.json"))
    /* respondWith(undefined) est une erreur de programmation (le navigateur casse la
       requête sans rien dire) : le premier passage hors ligne doit rendre Response.error(). */
    expect(response).toBe(sw.networkError)
    expect(response).toBeDefined()
  })

  it("stale-while-revalidate : le cache est servi tout de suite, même réseau en panne", async () => {
    const cache = fakeCache({ "/data/rules-fr.json": fakeResponse("règles en cache") })
    const sw = loadSw({ cache, fetchImpl: vi.fn(async () => Promise.reject(new Error("hors ligne"))) })
    const response = await handleFetch(sw, fakeRequest("/data/rules-fr.json"))
    expect(response.body).toBe("règles en cache")
  })

  it("navigation hors ligne : le shell en cache prend le relais", async () => {
    const cache = fakeCache({ "/": fakeResponse("index.html") })
    const sw = loadSw({ cache, fetchImpl: vi.fn(async () => Promise.reject(new Error("hors ligne"))) })
    const response = await handleFetch(sw, fakeRequest("/regles/1-2", { mode: "navigate" }))
    expect(response.body).toBe("index.html")
  })

  it("installation : le shell est atomique, le reste tolère les manquants", async () => {
    const cache = fakeCache()
    /* Un bundle optionnel en 404 ne doit pas faire échouer l'installation. */
    cache.add.mockImplementation(async (request) => {
      if (String(request).includes("RulesView")) throw new Error("404")
      cache.store.set(urlOf(request), fakeResponse("ajouté"))
    })
    const assets = [
      "/assets/index-abc.js",
      "/assets/index-abc.css",
      "/assets/RulesView-def.js",
      "/assets/topics-ghi.js"
    ]
    const sw = loadSw({ cache, assets })
    let installed
    sw.listeners.install({ waitUntil: (value) => (installed = value) })
    await installed
    /* Le shell passe par addAll (tout ou rien) ; les autres bundles par add un à un,
       pour qu'un seul 404 ne fasse pas échouer tout le précache. */
    expect(cache.addAll).toHaveBeenCalledWith([
      "/",
      "/data/rules-fr.json",
      "/assets/index-abc.js",
      "/assets/index-abc.css"
    ])
    expect(cache.add).toHaveBeenCalledWith("/assets/topics-ghi.js")
    expect(cache.store.has(urlOf("/assets/topics-ghi.js"))).toBe(true)
    expect(cache.store.has(urlOf("/assets/RulesView-def.js"))).toBe(false)
    expect(sw.self.skipWaiting).toHaveBeenCalled()
  })
})
