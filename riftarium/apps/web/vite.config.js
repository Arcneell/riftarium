import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const here = path.dirname(fileURLToPath(import.meta.url))

// En production, nginx sert /data/rules-fr.json ; en dev et en preview, ce
// middleware s'en charge (preview inclus : le service worker le précache).
const rulesFile = process.env.RULES_DATA || path.resolve(here, "../../data/rules-fr.json")
// `next(error)` sur erreur de lecture : sans ce garde-fou, un fichier absent fait remonter
// un 'error' non géré sur le flux et tue le serveur de dev au lieu de rendre une 500.
const rulesMiddleware = (req, res, next) => {
  res.setHeader("Content-Type", "application/json; charset=utf-8")
  fs.createReadStream(rulesFile).on("error", next).pipe(res)
}
const serveRulesData = {
  name: "serve-rules-data",
  configureServer(server) {
    server.middlewares.use("/data/rules-fr.json", rulesMiddleware)
  },
  configurePreviewServer(server) {
    server.middlewares.use("/data/rules-fr.json", rulesMiddleware)
  }
}

// Injecte dans dist/sw.js la liste des bundles à précacher, pour que les routes des
// règles restent consultables hors ligne (chargées à la demande par le routeur, elles
// manqueraient sinon dès la première coupure).
//
// On ne précache PAS tout /assets/ : la cartothèque, les decks et les statistiques
// n'ont aucun sens sans réseau, et leurs chunks coûtaient l'essentiel du précache. La liste
// est le sous-graphe RÉEL — chunk d'entrée + chunks des routes ci-dessous + leurs imports
// statiques transitifs — et non une liste de noms à maintenir à la main.
const OFFLINE_ROUTES = [
  "views/RulesView.vue", // texte officiel des règles
  "views/RulesHubView.vue",
  "views/LearnGuideView.vue",
  "views/BeginnerGuideView.vue",
  "views/AdvancedHelpView.vue",
  "views/AdvancedTopicView.vue"
]
// Polices : seul le sous-ensemble « latin » est précaché. Le « latin-ext » ne couvre que
// quelques glyphes (œ, caractères d'Europe centrale) : hors ligne, ils retombent sur la
// police système plutôt que de doubler le poids embarqué.
const OFFLINE_FONT = /-latin-(?!ext)[^/]*\.woff2$/

/* Variable de closure et non propriété du plugin : `this` diffère d'un hook à l'autre
   (contexte de plugin recréé), la liste calculée en generateBundle s'y perdrait. */
let swPrecache = []
const injectSwPrecache = {
  name: "inject-sw-precache",
  apply: "build",
  generateBundle(_options, bundle) {
    const outputs = Object.values(bundle)
    const chunks = new Map(outputs.filter((out) => out.type === "chunk").map((chunk) => [chunk.fileName, chunk]))
    const isRoute = (chunk) => {
      const id = chunk.facadeModuleId?.replaceAll("\\", "/")
      return Boolean(id) && OFFLINE_ROUTES.some((route) => id.endsWith(route))
    }
    const keep = new Set()
    // Seuls les imports STATIQUES sont suivis : les imports dynamiques sont justement les
    // autres routes, qu'on ne veut pas embarquer.
    const walk = (chunk) => {
      if (!chunk || keep.has(chunk.fileName)) return
      keep.add(chunk.fileName)
      for (const css of chunk.viteMetadata?.importedCss || []) keep.add(css)
      for (const imported of chunk.imports || []) walk(chunks.get(imported))
    }
    for (const chunk of chunks.values()) {
      if (chunk.isEntry || isRoute(chunk)) walk(chunk)
    }
    for (const output of outputs) {
      // La feuille de style est indispensable au shell ; les polices ne sont référencées
      // que depuis le CSS, donc absentes du graphe des imports.
      /* Feuille du shell (index-*.css) et polices latines : le CSS d'une future route
         hors règles n'a rien à faire dans le précache. */
      if (/^assets\/index-[^/]*\.css$/.test(output.fileName) || OFFLINE_FONT.test(output.fileName)) {
        keep.add(output.fileName)
      }
    }
    if (!keep.size) throw new Error("sw.js : aucun bundle à précacher (graphe de sortie vide ?)")
    swPrecache = [...keep].sort().map((file) => `/${file}`)
  },
  closeBundle() {
    const swFile = path.resolve(here, "dist/sw.js")
    const source = fs.readFileSync(swFile, "utf8")
    const marker = "const ASSETS = []"
    if (!source.includes(marker)) throw new Error("sw.js : marqueur de précache introuvable")
    if (!swPrecache.length) throw new Error("sw.js : liste de précache vide (generateBundle non exécuté ?)")
    fs.writeFileSync(swFile, source.replace(marker, `const ASSETS = ${JSON.stringify(swPrecache)}`))
  }
}

export default defineConfig({
  plugins: [vue(), serveRulesData, injectSwPrecache],
  server: {
    host: true,
    // Les bind mounts Windows/Docker ne propagent pas les événements de fichiers : polling.
    watch: process.env.VITE_POLLING ? { usePolling: true, interval: 300 } : undefined,
    proxy: {
      // agent: false — pas de keep-alive : si le conteneur api est recréé (nouvelle IP),
      // chaque requête re-résout le DNS au lieu de servir des 502 sur des sockets mortes.
      // changeOrigin: false — l'API compare l'Origin du navigateur au Host reçu
      // (anti-CSRF) : il faut lui transmettre le Host d'origine (localhost), pas api:8000.
      "/api": { target: process.env.API_PROXY || "http://localhost:8000", changeOrigin: false, agent: false }
    }
  },
  test: {
    environment: "jsdom",
    setupFiles: "src/test/setup.js"
  }
})
