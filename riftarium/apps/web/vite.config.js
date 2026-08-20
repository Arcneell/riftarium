import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const here = path.dirname(fileURLToPath(import.meta.url))

// En production, nginx sert /data/rules-fr.json ; en dev et en preview, ce
// middleware s'en charge (preview inclus : le service worker le précache).
const rulesFile = process.env.RULES_DATA || path.resolve(here, "../../data/rules-fr.json")
const rulesMiddleware = (req, res) => {
  res.setHeader("Content-Type", "application/json; charset=utf-8")
  fs.createReadStream(rulesFile).pipe(res)
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

// Injecte dans dist/sw.js la liste des bundles fingerprintés émis, pour que le
// service worker les précache : les chunks des routes chargées à la demande
// (dont le lecteur de règles) restent disponibles hors ligne.
const injectSwPrecache = {
  name: "inject-sw-precache",
  apply: "build",
  closeBundle() {
    const dist = path.resolve(here, "dist")
    const assets = fs
      .readdirSync(path.join(dist, "assets"))
      .sort()
      .map((file) => `/assets/${file}`)
    const swFile = path.join(dist, "sw.js")
    const source = fs.readFileSync(swFile, "utf8")
    const marker = "const ASSETS = []"
    if (!source.includes(marker)) throw new Error("sw.js : marqueur de précache introuvable")
    fs.writeFileSync(swFile, source.replace(marker, `const ASSETS = ${JSON.stringify(assets)}`))
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
