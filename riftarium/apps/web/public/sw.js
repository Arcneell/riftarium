/* Service worker Riftarium — règles consultables hors ligne.

   Stratégies, volontairement simples et sans dépendance :
   - Précache à l'installation : le shell de l'application (/), les règles
     officielles (/data/rules-fr.json) et les seuls bundles utiles hors ligne
     (liste injectée au build), pour pouvoir consulter une règle en pleine
     partie même sans réseau — y compris sans avoir jamais ouvert la page.
   - /assets/*   : cache-first — les bundles Vite sont fingerprintés, donc
     immuables ; une fois en cache, plus besoin du réseau.
   - /ocr/*      : cache-first — moteur OCR du scanner (worker, wasm, modèle),
     chargé à la demande depuis la page Scan, jamais précaché (plusieurs Mo).
   - /data/rules-fr.json : stale-while-revalidate — on sert le cache tout de
     suite (rapide, fonctionne hors ligne) et on rafraîchit derrière.
   - Navigations : network-first — la version fraîche si possible, sinon le
     shell en cache (le routeur SPA affiche ensuite la bonne page).
   - /api/*      : JAMAIS mis en cache — réseau direct, les erreurs remontent
     au front qui les gère déjà.

   Incrémenter VERSION à chaque changement de stratégie ou de précache :
   l'activation supprime les caches des versions précédentes. Aussi quand
   tesseract.js change de version — moins critique depuis que /ocr/ porte la
   version du moteur dans son chemin, mais un cache d'un ancien moteur reste
   du poids mort dans le quota du navigateur. */

const VERSION = 3
const CACHE = `riftarium-v${VERSION}`

/* Rempli au build par le plugin `inject-sw-precache` (vite.config.js) avec les
   bundles fingerprintés nécessaires hors ligne : le shell (chunk d'entrée + ses
   imports statiques + la feuille de style + les polices latines) et les routes
   des règles : une vingtaine de fichiers, ~560 Ko, là où tout /assets/ en
   comptait 66 pour ~900 Ko — la cartothèque, les decks, le scan et les
   statistiques n'ont aucun sens sans réseau. Sans ce précache, les chunks des
   routes jamais visitées (chargés à la demande par le routeur) manqueraient
   hors ligne. Liste vide en dev. */
const ASSETS = []

/* Shell critique : sans lui il n'y a rien à afficher hors ligne. Le chunk et la
   feuille de style d'entrée en font partie (index-*.js / index-*.css). */
const isCritical = (asset) => /^\/assets\/index-[^/]+\.(?:js|css)$/.test(asset)
const CRITICAL = ["/", "/data/rules-fr.json", ...ASSETS.filter(isCritical)]
const OPTIONAL = ASSETS.filter((asset) => !isCritical(asset))

async function precache() {
  const cache = await caches.open(CACHE)
  /* Le shell en tout ou rien : mieux vaut échouer l'installation que laisser un
     service worker actif incapable de servir la moindre page hors ligne. */
  await cache.addAll(CRITICAL)
  /* Le reste fichier par fichier : `addAll` est atomique, un seul 404 (chunk
     retiré, déploiement en cours de bascule) faisait échouer le précache des
     dizaines d'autres — et donc tout le mode hors ligne. */
  await Promise.allSettled(OPTIONAL.map((asset) => cache.add(asset)))
  /* Le nouveau SW prend la main sans attendre la fermeture des onglets. */
  await self.skipWaiting()
}

self.addEventListener("install", (event) => {
  event.waitUntil(precache())
})

/* Purge les bundles d'un déploiement précédent : le nom du cache ne change
   qu'avec VERSION, mais chaque build émet de nouveaux fichiers fingerprintés.
   Tout /assets/* absent du précache courant est soit obsolète, soit un chunk
   mis en cache à la volée par une visite en ligne (ASSETS n'est qu'un
   sous-ensemble) : dans les deux cas, le jeter à l'activation est sans risque —
   il sera refetché au prochain besoin. */
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
    /* Hors ligne au premier passage : sans repli explicite, la promesse rendue à
       respondWith valait `undefined` — ce que le navigateur traite comme une
       erreur réseau opaque, sans rien remonter à la page. */
    .catch(() => cached ?? Response.error())
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

  /* /ocr/* : moteur OCR du scanner (worker, wasm, modèle — plusieurs Mo, non
     précachés) : cache-first dès le premier scan, comme les bundles. */
  if (url.pathname.startsWith("/assets/") || url.pathname.startsWith("/ocr/")) {
    event.respondWith(cacheFirst(request))
    return
  }

  if (url.pathname === "/data/rules-fr.json") {
    event.respondWith(staleWhileRevalidate(request))
  }
})
