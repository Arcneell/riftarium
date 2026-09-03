/* Lecture du code collector imprimé sur la carte (« UNL • 229* / 219 ») : préparation de
   l'image, parsing robuste, rapprochement avec l'index, et gestion du worker tesseract.js.

   Pourquoi lire le code plutôt que se contenter de l'empreinte : le code identifie la carte
   de façon exacte (set + numéro + total), là où la ressemblance visuelle confond les
   variantes et les illustrations proches. L'empreinte reste la voie de secours — et la
   seule pour les cartes tenues de travers, floues ou en paysage.

   Tout ce qui est pur (renforcement pixel, parsing, appariement) vit ici et est testé ;
   tesseract.js est chargé dynamiquement pour ne peser que sur la route /scan. */

/* ------------------------------------------------------------------
   Préparation de l'image (fonction pure sur ImageData)
   ------------------------------------------------------------------ */

/* Percentiles d'écrêtage du contraste. Le fond de la bande est sombre mais jamais noir
   (illustration qui déborde, reflets) : couper les 2 % extrêmes évite qu'un seul pixel
   spéculaire écrase tout l'étirement. */
const CLIP_LOW = 0.02
const CLIP_HIGH = 0.98

/** Passe l'ImageData en niveaux de gris, étire son contraste sur les percentiles utiles,
    puis l'INVERSE : tesseract est entraîné sur du texte sombre sur fond clair, alors que
    le code de la carte est blanc sur fond sombre. Modifie l'ImageData sur place. */
export function enhanceCodeBand(imageData) {
  const { data } = imageData
  const pixels = data.length / 4
  const histogram = new Uint32Array(256)
  const gray = new Uint8Array(pixels)
  for (let i = 0; i < pixels; i++) {
    const o = i * 4
    const value = (0.299 * data[o] + 0.587 * data[o + 1] + 0.114 * data[o + 2]) | 0
    gray[i] = value
    histogram[value]++
  }

  const lowTarget = pixels * CLIP_LOW
  const highTarget = pixels * CLIP_HIGH
  let low = 0
  let high = 255
  let seen = 0
  for (let v = 0; v < 256; v++) {
    seen += histogram[v]
    if (seen >= lowTarget) {
      low = v
      break
    }
  }
  seen = 0
  for (let v = 0; v < 256; v++) {
    seen += histogram[v]
    if (seen >= highTarget) {
      high = v
      break
    }
  }
  /* Bande uniforme (carte hors cadre, caméra bouchée) : rien à étirer, on inverse seulement
     pour ne pas diviser par zéro. */
  const span = high - low >= 8 ? high - low : 255
  const base = high - low >= 8 ? low : 0

  for (let i = 0; i < pixels; i++) {
    const stretched = ((gray[i] - base) * 255) / span
    const value = 255 - Math.max(0, Math.min(255, stretched))
    const o = i * 4
    data[o] = value
    data[o + 1] = value
    data[o + 2] = value
    data[o + 3] = 255
  }
  return imageData
}

/* ------------------------------------------------------------------
   Parsing du code
   ------------------------------------------------------------------ */

/* Marge « overnumbered » : certaines cartes portent un numéro supérieur au total imprimé
   (impressions hors set numéroté). Riot n'a jamais dépassé quelques dizaines au-delà ;
   60 laisse de la marge sans accepter n'importe quoi. */
export const OVERNUMBER_MARGIN = 60

/** « unl-229*-219 » → { set: "UNL", number: 229, suffix: "*", star: true, total: 219 }, ou null. */
export function parseRiftboundId(rid) {
  const match = /^([a-z0-9]{2,6})-(\d{1,4})([a-z*]{0,3})-(\d{1,4})$/i.exec(String(rid ?? "").trim())
  if (!match) return null
  const suffix = match[3].toLowerCase()
  return {
    set: match[1].toUpperCase(),
    number: Number(match[2]),
    suffix,
    star: suffix.includes("*"),
    total: Number(match[4])
  }
}

/** Totaux d'impression présents dans l'index (219 pour UNL, 298 pour OGN…).
    Ce filtre est ce qui rend l'OCR utilisable : un total inventé par la reconnaissance
    (« 279 », « 2I9 » relu 219…) est rejeté au lieu de désigner une carte au hasard. */
export function collectorTotals(index) {
  const totals = new Set()
  for (const item of index || []) {
    const parsed = parseRiftboundId(item?.rid)
    if (parsed) totals.add(parsed.total)
  }
  return totals
}

function toTotalSet(knownTotals) {
  if (knownTotals instanceof Set) return knownTotals
  return new Set(knownTotals || [])
}

/** Groupes de chiffres du texte nettoyé, avec leurs positions. */
function digitRuns(text) {
  const runs = []
  const pattern = /\d+/g
  let match
  while ((match = pattern.exec(text)))
    runs.push({ text: match[0], start: match.index, end: match.index + match[0].length })
  return runs
}

/** Texte brut de l'OCR → { set, number, star, total }, ou null si rien de crédible.

    On ne cherche pas à valider la forme « SET • N/T » : l'OCR perd le point médian, colle
    ou double les espaces, et confond « / » avec « 1 » ou « 7 ». On extrait donc tous les
    groupes de chiffres et on ne retient qu'un couple (numéro, total) dont le TOTAL existe
    vraiment dans l'index et dont le numéro est plausible. Le set (3 lettres) et l'étoile
    sont des bonus : jamais exigés, jamais décisifs (voir matchByCode). */
export function parseCollectorCode(text, knownTotals) {
  const totals = toTotalSet(knownTotals)
  if (!totals.size) return null
  const cleaned = String(text ?? "")
    .toUpperCase()
    .replace(/[^A-Z0-9/*]+/g, " ")
  const set = cleaned.match(/(?:^|[^A-Z])([A-Z]{3})(?![A-Z])/)?.[1] || null
  const runs = digitRuns(cleaned)

  const accept = (number, total, star) =>
    totals.has(total) && number >= 1 && number <= total + OVERNUMBER_MARGIN ? { set, number, star, total } : null

  /* Cas normal : deux groupes distincts. Parcours à l'envers, le code est en fin de ligne
     (un parasite lu au début — reste du texte de la carte — ne doit pas primer). */
  for (let i = runs.length - 2; i >= 0; i--) {
    const between = cleaned.slice(runs[i].end, runs[i + 1].start)
    const hit = accept(Number(runs[i].text), Number(runs[i + 1].text), between.includes("*"))
    if (hit) return hit
  }

  /* Repli : le séparateur a disparu et les deux nombres sont collés (« 229219 ») — les
     totaux connus donnent le point de coupure. L'étoile est alors indétectable. */
  for (let i = runs.length - 1; i >= 0; i--) {
    const digits = runs[i].text
    for (let cut = 1; cut < digits.length; cut++) {
      const hit = accept(Number(digits.slice(0, cut)), Number(digits.slice(cut)), false)
      if (hit) return hit
    }
  }
  return null
}

/** Cartes de l'index compatibles avec un code lu → { items, rids }.

    L'étoile imprimée fait 2 px de large sur la photo : la lire est un coup de dé. Toutes
    les variantes du même numéro (avec et sans étoile, art alternatif) sont donc retournées
    ensemble — c'est à l'empreinte, ou à l'utilisateur, de trancher, jamais à l'OCR.
    L'étoile lue sert quand même d'ordre de PRÉFÉRENCE (jamais de filtre) : quand aucune
    empreinte n'est disponible pour départager, la variante dont l'étoile correspond passe
    devant, ce qui vaut mieux que l'ordre arbitraire de l'index. */
export function matchByCode(code, index) {
  if (!code) return { items: [], rids: [] }
  const collect = (useSet) => {
    const found = []
    for (const item of index || []) {
      const parsed = parseRiftboundId(item?.rid)
      if (!parsed) continue
      if (parsed.number !== code.number || parsed.total !== code.total) continue
      if (useSet && parsed.set !== code.set) continue
      found.push(item)
    }
    return found
  }
  /* Le set filtre les collisions entre extensions ; s'il a été mal lu, on retombe sur le
     numéro seul plutôt que de perdre une lecture par ailleurs valide. */
  let items = code.set ? collect(true) : []
  if (!items.length) items = collect(false)
  /* Tri stable : les variantes dont l'étoile correspond d'abord, l'ordre de l'index ensuite. */
  const wanted = Boolean(code.star)
  items = items
    .map((item, rank) => ({ item, rank, matches: parseRiftboundId(item.rid)?.star === wanted }))
    .sort((a, b) => (a.matches === b.matches ? a.rank - b.rank : a.matches ? -1 : 1))
    .map((entry) => entry.item)
  return { items, rids: [...new Set(items.map((item) => item.rid))] }
}

/** Le code tel qu'il est imprimé, numéro complété à la longueur du total comme sur la
    carte (« OGN 002/298 », jamais « OGN 2/298 »). */
export function formatCode(code) {
  if (!code) return ""
  const number = String(code.number).padStart(String(code.total).length, "0")
  return `${code.set ? `${code.set} ` : ""}${number}${code.star ? "*" : ""}/${code.total}`
}

/* ------------------------------------------------------------------
   Worker tesseract.js (auto-hébergé sous /ocr/)
   ------------------------------------------------------------------ */

/* Auto-hébergement obligatoire : la CSP du site interdit tout script tiers, et
   workerBlobURL créerait une URL blob: elle aussi bloquée. Les fichiers sont copiés
   dans dist/ocr/<version de tesseract.js>/ au build (plugin copyOcrAssets de
   vite.config.js), qui injecte ce chemin dans __OCR_BASE__.

   Pourquoi une version dans le chemin : ces fichiers ne sont pas fingerprintés, or
   nginx les sert en `expires 30d` et le service worker les met en cache-first (donc
   sans expiration). Sans version, une mise à jour de tesseract.js laisserait des
   navigateurs mélanger un worker neuf et un cœur wasm périmé pendant un mois.

   __OCR_BASE__ n'est défini qu'au build : en dev, en preview et sous vitest on retombe
   sur /ocr, que le middleware serveOcrAssets sert quelle que soit la forme du chemin. */
/* global __OCR_BASE__ */
const OCR_BASE = typeof __OCR_BASE__ !== "undefined" ? __OCR_BASE__ : "/ocr"

/** Erreur d'OCR portant son étage : un moteur qui ne charge pas est définitif (on bascule
    sur l'empreinte pour la session), une reconnaissance ratée est transitoire (image floue,
    on retentera à l'image suivante). Confondre les deux coupait l'OCR au premier flou. */
export class OcrError extends Error {
  constructor(stage, message) {
    super(message)
    this.name = "OcrError"
    this.stage = stage // "load" | "recognize"
  }
}

/* Époque du moteur, incrémentée par cancelOcr et terminateOcrWorker. Chaque opération
   capture l'époque à son début et se saborde si elle a changé : c'est ce qui empêche un
   chargement ou une lecture abandonnés de revenir piloter l'application — et un terminate
   obsolète de tuer le worker d'un chargement plus récent. */
let epoch = 0
let workerPromise = null
let busy = false

/** Charge (une seule fois) le worker OCR. `onProgress({ status, progress })` suit le
    téléchargement du moteur et du modèle — plusieurs Mo au premier scan, puis cache. */
export function ensureOcrWorker(onProgress) {
  if (workerPromise) return workerPromise
  const mine = epoch
  /* L'instance vit dans la closure de SA promesse, et non dans une variable de module :
     un terminate concurrent ne peut plus tuer le worker d'un chargement ultérieur. */
  const promise = (async () => {
    /* Import dynamique : tesseract.js part dans son propre chunk, la page d'accueil n'en
       paie rien. */
    const { createWorker, OEM, PSM } = await import("tesseract.js")
    const created = await createWorker("eng", OEM.LSTM_ONLY, {
      workerPath: `${OCR_BASE}/worker.min.js`,
      /* Répertoire, pas fichier : tesseract.js choisit lui-même la variante wasm
         (relaxedsimd / simd / scalaire) selon ce que sait faire l'appareil. */
      corePath: `${OCR_BASE}/`,
      langPath: OCR_BASE,
      workerBlobURL: false,
      gzip: true,
      logger: (message) => onProgress?.(message)
    })
    await created.setParameters({
      /* Une seule ligne de texte : pas d'analyse de mise en page, et surtout pas de
         segmentation qui découperait le code en blocs.
         Pas de tessedit_char_whitelist ici : le moteur LSTM (OEM.LSTM_ONLY) l'ignore — le
         tri entre lectures crédibles et fantaisistes se fait en aval dans
         parseCollectorCode, qui n'accepte un couple numéro/total que si le total existe
         réellement dans l'index. */
      tessedit_pageseg_mode: PSM.SINGLE_LINE,
      /* L'espace entre le set et le numéro est notre repère de découpe : à préserver. */
      preserve_interword_spaces: "1",
      /* La bande est un agrandissement, pas un scan : sans DPI déclaré tesseract suppose
         70 dpi et rejette le texte comme trop gros. */
      user_defined_dpi: "300"
    })
    if (mine !== epoch) {
      /* Abandonné pendant le chargement (navigation) : pas de worker orphelin. */
      await created.terminate().catch(() => {})
      throw new OcrError("load", "Chargement du moteur OCR abandonné")
    }
    return created
  })()
  workerPromise = promise
  /* Un échec de chargement (réseau, wasm refusé) ne doit pas condamner la session :
     on repart de zéro au prochain appel, et le scan par empreinte continue seul. */
  promise.catch(() => {
    if (workerPromise === promise) workerPromise = null
  })
  return promise
}

/** true si une reconnaissance est déjà en cours : l'appelant saute son tour.
    Un seul OCR à la fois — deux en parallèle se voleraient le CPU de la boucle de hash. */
export function isOcrBusy() {
  return busy
}

/** Abandonne la lecture en cours sans jeter le worker (import de photo, nouveau scan) :
    la reconnaissance en vol sera ignorée et la place est libérée immédiatement. */
export function cancelOcr() {
  epoch += 1
  busy = false
}

/** Lit le code sur une image déjà préparée (codeBandImage). Renvoie le texte brut, ou
    null si un OCR est déjà en cours. Jette une OcrError qui dit quel étage a lâché. */
export async function readCodeText(image) {
  if (busy) return null
  busy = true
  const mine = epoch
  try {
    let active
    try {
      active = await ensureOcrWorker()
    } catch (loadError) {
      if (loadError instanceof OcrError) throw loadError
      throw new OcrError("load", loadError?.message || "Moteur OCR indisponible")
    }
    if (mine !== epoch) throw new OcrError("recognize", "Lecture abandonnée")
    let result
    try {
      result = await active.recognize(image)
    } catch (recognizeError) {
      throw new OcrError("recognize", recognizeError?.message || "Lecture impossible")
    }
    if (mine !== epoch) throw new OcrError("recognize", "Lecture abandonnée")
    return result?.data?.text ?? ""
  } finally {
    /* Époque changée : cancelOcr a déjà rendu la place et un autre OCR a pu démarrer —
       ne pas la libérer une seconde fois sous les pieds du nouveau. */
    if (mine === epoch) busy = false
  }
}

/** Arrête le worker (navigation, onglet quitté) : un worker wasm oublié garde des dizaines
    de Mo et continue de tourner. À ATTENDRE avant de relancer un scan. */
export async function terminateOcrWorker() {
  const pending = workerPromise
  workerPromise = null
  cancelOcr() // invalide le chargement et la reconnaissance en vol
  if (!pending) return
  let active
  try {
    active = await pending
  } catch {
    return // chargement déjà en échec ou abandonné : rien à arrêter
  }
  /* Un terminate qui jette (worker déjà mort, contexte détruit par la navigation) ne doit
     pas remonter : l'appelant n'a rien à en faire et le rejet ferait échouer shutdown(). */
  await active.terminate().catch(() => {})
}
