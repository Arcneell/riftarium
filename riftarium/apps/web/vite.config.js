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

// Moteur OCR du scanner (tesseract.js), auto-hébergé sous /ocr/ : la CSP du site
// interdit tout script tiers, donc le CDN par défaut de tesseract.js est inutilisable.
// Un seul inventaire sert au build (copie dans dist/ocr/) et au dev/preview
// (middleware qui lit node_modules) : aucun risque de divergence entre les deux.
//
// Les trois variantes « lstm » du cœur wasm sont nécessaires : le worker choisit à
// l'exécution relaxedsimd, simd ou scalaire selon ce que sait faire l'appareil
// (node_modules/tesseract.js/src/worker-script/browser/getCore.js). Seuls les
// `.wasm.js` sont copiés : ce sont des builds Emscripten « single-file » (wasm
// embarqué en base64, aucune référence au `.wasm` voisin — vérifié par grep), les
// `.wasm` séparés pèseraient 8,5 Mo d'image Docker pour rien. Le modèle de langue
// vient de 4.0.0_best_int (2,9 Mo) et non de 4.0.0 (10,9 Mo) : ce dernier embarque en plus
// le moteur historique, inutile en OEM.LSTM_ONLY.
const ocrCoreVariants = ["tesseract-core-lstm", "tesseract-core-simd-lstm", "tesseract-core-relaxedsimd-lstm"]
const ocrFiles = {
  "worker.min.js": "tesseract.js/dist/worker.min.js",
  "eng.traineddata.gz": "@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz",
  ...Object.fromEntries(ocrCoreVariants.map((name) => [`${name}.wasm.js`, `tesseract.js-core/${name}.wasm.js`]))
}
const ocrSourcePath = (name) => path.resolve(here, "node_modules", ocrFiles[name])
// Le modèle est servi tel quel (.gz) : tesseract.js le décompresse lui-même côté worker.
// Un Content-Encoding: gzip ferait décompresser le navigateur et le worker recevrait des
// octets déjà clairs qu'il tenterait de dégunziper.
const ocrContentType = (name) => {
  if (name.endsWith(".gz")) return "application/gzip"
  return "text/javascript; charset=utf-8"
}
const ocrMiddleware = (req, res, next) => {
  const name = path.basename(req.url.split("?")[0])
  if (!ocrFiles[name]) return next()
  res.setHeader("Content-Type", ocrContentType(name))
  fs.createReadStream(ocrSourcePath(name)).on("error", next).pipe(res)
}
const serveOcrAssets = {
  name: "serve-ocr-assets",
  configureServer(server) {
    server.middlewares.use("/ocr", ocrMiddleware)
  },
  configurePreviewServer(server) {
    server.middlewares.use("/ocr", ocrMiddleware)
  }
}
const copyOcrAssets = {
  name: "copy-ocr-assets",
  apply: "build",
  closeBundle() {
    const target = path.resolve(here, "dist/ocr")
    fs.mkdirSync(target, { recursive: true })
    for (const name of Object.keys(ocrFiles)) {
      const source = ocrSourcePath(name)
      // Échouer bruyamment : un dist/ocr incomplet ne se voit qu'au premier scan
      // sur mobile, longtemps après le déploiement.
      if (!fs.existsSync(source)) throw new Error(`Moteur OCR : ${ocrFiles[name]} introuvable dans node_modules`)
      fs.copyFileSync(source, path.join(target, name))
    }
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
  plugins: [vue(), serveRulesData, serveOcrAssets, copyOcrAssets, injectSwPrecache],
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
