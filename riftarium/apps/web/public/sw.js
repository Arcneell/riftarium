/* Service worker Riftarium — règles consultables hors ligne.

   Stratégies, volontairement simples et sans dépendance :
   - Précache à l'installation : le shell de l'application (/), les règles
     officielles (/data/rules-fr.json) et les bundles émis par Vite (liste
     injectée au build), pour pouvoir consulter une règle en pleine partie
     même sans réseau — y compris sans avoir jamais ouvert la page.
   - /assets/*   : cache-first — les bundles Vite sont fingerprintés, donc
     immuables ; une fois en cache, plus besoin du réseau.
   - /data/rules-fr.json : stale-while-revalidate — on sert le cache tout de
     suite (rapide, fonctionne hors ligne) et on rafraîchit derrière.
   - Navigations : network-first — la version fraîche si possible, sinon le
     shell en cache (le routeur SPA affiche ensuite la bonne page).
   - /api/*      : JAMAIS mis en cache — réseau direct, les erreurs remontent
     au front qui les gère déjà.

   Incrémenter VERSION à chaque changement de stratégie ou de précache :
   l'activation supprime les caches des versions précédentes. */

const VERSION = 1
const CACHE = `riftarium-v${VERSION}`

/* Rempli au build par le plugin `inject-sw-precache` (vite.config.js) avec la
   liste des bundles fingerprintés émis dans /assets/ (~800 Ko au total). Sans
   ce précache, les chunks des routes jamais visitées (chargés à la demande
   par le routeur) manqueraient hors ligne. Liste vide en dev. */
const ASSETS = []

/* Le shell ("/" sert index.html) + les règles + les bundles. */
const PRECACHE = ["/", "/data/rules-fr.json", ...ASSETS]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(PRECACHE))
      /* Le nouveau SW prend la main sans attendre la fermeture des onglets. */
      .then(() => self.skipWaiting())
  )
})

/* Purge les bundles d'un déploiement précédent : le nom du cache ne change
   qu'avec VERSION, mais chaque build émet de nouveaux fichiers fingerprintés —
   tout /assets/* absent du précache courant est obsolète. */
async function dropStaleAssets() {
  const cache = await caches.open(CACHE)
  const keep = new Set(ASSETS.map((asset) => new URL(asset, self.location.origin).href))
  for (const request of await cache.keys()) {
    if (new URL(request.url).pathname.startsWith("/assets/") && !keep.has(request.url)) {
      await cache.delete(request)
    }
  }
}

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(dropStaleAssets)
      /* Contrôle immédiat des pages déjà ouvertes. */
      .then(() => self.clients.claim())
  )
})

/* ignoreVary : certains serveurs (ex. vite preview) répondent `Vary: Origin`,
   or les requêtes de modules `crossorigin` portent un en-tête Origin absent
   lors du précache — sans cette option, le cache ne matcherait pas. Sans
   risque ici : tout ce qui est mis en cache est same-origin et statique. */
const MATCH = { ignoreVary: true }

/* Cache-first : sert le cache, sinon va au réseau et mémorise la réponse. */
async function cacheFirst(request) {
  const cached = await caches.match(request, MATCH)
  if (cached) return cached
  const response = await fetch(request)
  if (response.ok) {
    const cache = await caches.open(CACHE)
    cache.put(request, response.clone())
  }
  return response
}

/* Stale-while-revalidate : sert le cache immédiatement et rafraîchit derrière.
   Sans cache (premier passage), on attend simplement le réseau. */
async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE)
  const cached = await cache.match(request, MATCH)
  const refresh = fetch(request)
    .then((response) => {
      if (response.ok) cache.put(request, response.clone())
      return response
    })
    .catch(() => cached)
  return cached ?? refresh
}

/* Network-first (navigations) : le réseau si possible, sinon le shell en cache. */
async function navigationNetworkFirst(request) {
  try {
    const response = await fetch(request)
    if (response.ok) {
      /* Toutes les navigations servent index.html : on rafraîchit le shell. */
      const cache = await caches.open(CACHE)
      cache.put("/", response.clone())
    }
    return response
  } catch {
    return (await caches.match("/", MATCH)) ?? Response.error()
  }
}

self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET") return

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  /* L'API n'est jamais mise en cache : réseau direct (pas de respondWith). */
  if (url.pathname.startsWith("/api/")) return

  if (request.mode === "navigate") {
    event.respondWith(navigationNetworkFirst(request))
    return
  }

  if (url.pathname.startsWith("/assets/")) {
    event.respondWith(cacheFirst(request))
    return
  }

  if (url.pathname === "/data/rules-fr.json") {
    event.respondWith(staleWhileRevalidate(request))
  }
})
