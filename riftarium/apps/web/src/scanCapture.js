/* Côté navigateur du scan : capture canvas → ImageData réduit → empreinte (scanHash.js),
   et bande du code collector préparée pour l'OCR (scanOcr.js).
   Isolé de ScanView pour être mocké dans les tests (Node/jsdom n'a pas de canvas 2D).
   Seule la géométrie (artCrop, sweepSteps, stepRect, codeBandRect) est testable sous Node. */

import { dhashFromImageData } from "./scanHash.js"
import { enhanceCodeBand } from "./scanOcr.js"

/* Assez grand pour que le box filter JS finisse proprement en 17×16 / 16×17,
   assez petit pour que getImageData reste négligeable. */
const TARGET_W = 68
const TARGET_H = 64

function makeCanvas(width, height) {
  const canvas = document.createElement("canvas")
  canvas.width = Math.max(1, Math.round(width))
  canvas.height = Math.max(1, Math.round(height))
  const ctx = canvas.getContext("2d")
  ctx.imageSmoothingEnabled = true
  ctx.imageSmoothingQuality = "high"
  return { canvas, ctx }
}

/** Découpe (sx, sy, sw, sh) de `source`, réduite en étapes successives (÷2 jusqu'à proche de la
    cible, puis taille finale) pour se rapprocher d'un rééchantillonnage propre type Pillow. */
export function imageDataFromRegion(source, sx, sy, sw, sh) {
  let { canvas, ctx } = makeCanvas(sw, sh)
  ctx.drawImage(source, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height)

  while (canvas.width >= TARGET_W * 2 && canvas.height >= TARGET_H * 2) {
    const step = makeCanvas(canvas.width / 2, canvas.height / 2)
    step.ctx.drawImage(canvas, 0, 0, step.canvas.width, step.canvas.height)
    canvas = step.canvas
  }

  const final = makeCanvas(TARGET_W, TARGET_H)
  final.ctx.drawImage(canvas, 0, 0, TARGET_W, TARGET_H)
  return final.ctx.getImageData(0, 0, TARGET_W, TARGET_H)
}

/* Fenêtre d'illustration dans la carte : x de 6 % à 94 % de la largeur, y de 6 % à 54 %
   de la hauteur. Le serveur hashe cette zone (indépendante de la langue : FR et EN
   partagent le même visuel), pas la carte entière. */
export const ART_WINDOW = { x0: 0.06, x1: 0.94, y0: 0.06, y1: 0.54 }

/** Sous-rectangle « illustration » d'un rectangle de carte (cadre caméra ou photo entière). */
export function artCrop({ sx, sy, sw, sh }) {
  const left = Math.round(ART_WINDOW.x0 * sw)
  const right = Math.round(ART_WINDOW.x1 * sw)
  const top = Math.round(ART_WINDOW.y0 * sh)
  const bottom = Math.round(ART_WINDOW.y1 * sh)
  return { sx: sx + left, sy: sy + top, sw: right - left, sh: bottom - top }
}

/* Bande du code collector, en fractions de la carte : « UNL • 229* / 219 » est imprimé en bas
   à gauche, en blanc sur fond sombre. Repères mesurés sur les visuels de référence
   (744×1039) : le texte tient dans x 5→24 %, y 96→98 %. On prend large (x 4→48 %) pour
   encaisser un cadrage approximatif et les codes plus longs (numéros à 3 chiffres + étoile). */
export const CODE_BAND = { x0: 0.04, x1: 0.48, y0: 0.925, y1: 0.998 }

/** Sous-rectangle « code collector » d'un rectangle de carte. */
export function codeBandRect({ sx, sy, sw, sh }) {
  const left = Math.round(CODE_BAND.x0 * sw)
  const right = Math.round(CODE_BAND.x1 * sw)
  const top = Math.round(CODE_BAND.y0 * sh)
  const bottom = Math.round(CODE_BAND.y1 * sh)
  return { sx: sx + left, sy: sy + top, sw: right - left, sh: bottom - top }
}

/* Hauteur de rendu de la bande avant OCR. Le texte fait ~1,8 % de la hauteur de la carte,
   soit ~27 % de la hauteur de la bande : 240 px de bande → ~65 px de texte, la fourchette
   où tesseract LSTM est le plus fiable (en dessous de 30 px il décroche). */
const CODE_BAND_PIXELS = 240

/** Canvas de la bande du code, agrandi et renforcé (gris → contraste étiré → inversé),
    prêt à passer à tesseract. Le rendu est mesuré en pixels, pas en fractions : c'est la
    hauteur du TEXTE qui compte pour l'OCR, pas la résolution de la caméra. */
export function codeBandImage(source, cardRect) {
  const band = codeBandRect(cardRect)
  const height = CODE_BAND_PIXELS
  const width = Math.max(1, Math.round((band.sw / band.sh) * height))
  const { canvas, ctx } = makeCanvas(width, height)
  ctx.drawImage(source, band.sx, band.sy, band.sw, band.sh, 0, 0, width, height)
  const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height)
  enhanceCodeBand(pixels)
  ctx.putImageData(pixels, 0, 0)
  return canvas
}

/* ------------------------------------------------------------------
   Balayage multi-cadrage
   ------------------------------------------------------------------
   Exiger un cadrage exact était le principal défaut de l'ancien scan.
   On essaie donc plusieurs rectangles autour du guide et on garde la
   meilleure distance par carte : la carte peut dépasser, être un peu
   petite ou décalée sans faire échouer la reconnaissance.
   ------------------------------------------------------------------ */

/* Échelles essayées : ±15 % couvre « carte trop petite dans le guide » et « carte qui déborde ». */
export const SWEEP_SCALES = [0.85, 1, 1.15]

/* Décalage latéral : 6 % de la carte, soit ~4 mm sur une carte réelle — au-delà, la fenêtre
   d'illustration mordrait sur le cadre imprimé et l'empreinte se dégraderait plus qu'elle
   ne gagnerait. Uniquement en diagonale : une carte tenue à la main rate le guide sur les
   deux axes à la fois, presque jamais sur un seul. */
export const SWEEP_SHIFT = 0.06
const S = SWEEP_SHIFT
export const CENTER_ONLY = [[0, 0]]
export const DIAGONAL_SHIFTS = [
  [0, 0],
  [-S, -S],
  [S, -S],
  [-S, S],
  [S, S]
]

/** Produit cartésien (rotations × échelles × décalages) → liste plate d'étapes
    { scale, dx, dy, turns } ; dx/dy sont des fractions de la taille du guide. */
export function sweepSteps({ scales, shifts, rotations }) {
  const steps = []
  for (const turns of rotations) {
    for (const scale of scales) {
      for (const [dx, dy] of shifts) steps.push({ scale, dx, dy, turns })
    }
  }
  return steps
}

/* Boucle caméra : 17 empreintes par image (3 échelles × 5 positions à l'endroit, plus le
   centre à ±90°). Le balayage complet en ferait 45, hors du budget de ~60 ms par image sur
   un mobile milieu de gamme. Les rotations ne servent qu'aux champs de bataille (imprimés
   en paysage) : eux sont posés à plat dans le guide, un décalage n'apporte rien. */
export const LIVE_SWEEP = [
  ...sweepSteps({ scales: SWEEP_SCALES, shifts: DIAGONAL_SHIFTS, rotations: [0] }),
  ...sweepSteps({ scales: [1], shifts: CENTER_ONLY, rotations: [1, 3] })
]

/* Photo importée : le rectangle de départ est l'image ENTIÈRE, il n'y a donc pas de pixels
   au-delà. Une échelle > 1 ou un décalage à échelle 1 échantillonneraient hors image : les
   bords transparents deviennent noirs, l'empreinte s'effondre vers une valeur artificielle
   et `bestMatchesPacked`, qui garde le minimum, retiendrait ce faux positif. On n'essaie
   donc que des cadrages STRICTEMENT INTÉRIEURS : plus la carte est petite dans la photo,
   plus elle peut être décalée — le décalage maximal est exactement la marge disponible. */
const PHOTO_SCALES = [0.8, 0.9, 1]
function insetSteps(rotations) {
  const steps = []
  for (const scale of PHOTO_SCALES) {
    const margin = (1 - scale) / 2 // fraction libre de chaque côté à cette échelle
    const shifts =
      margin > 0 ? DIAGONAL_SHIFTS.map(([dx, dy]) => [Math.sign(dx) * margin, Math.sign(dy) * margin]) : CENTER_ONLY
    steps.push(...sweepSteps({ scales: [scale], shifts, rotations }))
  }
  return steps
}
export const PHOTO_SWEEP = insetSteps([0, 1, 3])

/** Rectangle de carte d'une étape du balayage (autour du même centre que le guide). */
export function stepRect({ sx, sy, sw, sh }, { scale, dx, dy }) {
  const w = sw * scale
  const h = sh * scale
  return {
    sx: sx + (sw - w) / 2 + dx * sw,
    sy: sy + (sh - h) / 2 + dy * sh,
    sw: w,
    sh: h
  }
}

/** Rectangle englobant toutes les étapes : c'est la zone qu'il faut capturer une fois
    dans le canvas de travail pour que chaque étape y trouve ses pixels. */
export function sweepBounds(rect, steps) {
  let x0 = Infinity
  let y0 = Infinity
  let x1 = -Infinity
  let y1 = -Infinity
  for (const step of steps) {
    const r = stepRect(rect, step)
    x0 = Math.min(x0, r.sx)
    y0 = Math.min(y0, r.sy)
    x1 = Math.max(x1, r.sx + r.sw)
    y1 = Math.max(y1, r.sy + r.sh)
  }
  return { sx: x0, sy: y0, sw: x1 - x0, sh: y1 - y0 }
}

/* Taille de travail de la région carte avant rotation/crop : assez fine pour le hash,
   bornée pour que les getImageData restent négligeables. */
const REGION_MAX = 560

/** Copie la région dans un canvas de travail (dimensions bornées) + facteur d'échelle appliqué. */
function regionToCanvas(source, { sx, sy, sw, sh }) {
  const scale = Math.min(1, REGION_MAX / Math.max(sw, sh))
  const { canvas, ctx } = makeCanvas(sw * scale, sh * scale)
  ctx.drawImage(source, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height)
  return { canvas, scale: canvas.width / sw }
}

/** Rotation d'un canvas par quarts de tour (1 = 90° horaire, 3 = 270°). */
function rotateCanvas(source, quarterTurns) {
  if (quarterTurns % 4 === 0) return source
  const swap = quarterTurns % 2 === 1
  const { canvas, ctx } = makeCanvas(swap ? source.height : source.width, swap ? source.width : source.height)
  ctx.translate(canvas.width / 2, canvas.height / 2)
  ctx.rotate((quarterTurns * Math.PI) / 2)
  ctx.drawImage(source, -source.width / 2, -source.height / 2)
  return canvas
}

/** Sous-canvas d'une région (utilisé seulement avant rotation : la fenêtre d'illustration
    n'est calculable qu'une fois la carte remise à l'endroit). */
function cropCanvas(source, { sx, sy, sw, sh }) {
  const { canvas, ctx } = makeCanvas(sw, sh)
  ctx.drawImage(source, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height)
  return canvas
}

/** Empreintes du balayage : une par étape, dans l'ordre de `steps`.
    `rect` est le rectangle de carte (cadre du guide, ou image entière pour une photo). */
export function hashesFromRegion(source, rect, steps) {
  const bounds = sweepBounds(rect, steps)
  const { canvas, scale } = regionToCanvas(source, bounds)
  const hexes = []
  for (const step of steps) {
    const r = stepRect(rect, step)
    const local = {
      sx: (r.sx - bounds.sx) * scale,
      sy: (r.sy - bounds.sy) * scale,
      sw: r.sw * scale,
      sh: r.sh * scale
    }
    if (step.turns === 0) {
      /* À l'endroit : la fenêtre d'illustration se calcule directement dans le canvas de
         travail, sans canvas intermédiaire — c'est le cas de loin le plus fréquent. */
      const art = artCrop(local)
      hexes.push(dhashFromImageData(imageDataFromRegion(canvas, art.sx, art.sy, art.sw, art.sh)))
    } else {
      const oriented = rotateCanvas(cropCanvas(canvas, local), step.turns)
      const art = artCrop({ sx: 0, sy: 0, sw: oriented.width, sh: oriented.height })
      hexes.push(dhashFromImageData(imageDataFromRegion(oriented, art.sx, art.sy, art.sw, art.sh)))
    }
  }
  return hexes
}

/** Empreintes de la carte cadrée dans la vidéo (balayage de la boucle par défaut). */
export function hashesFromVideoFrame(video, cardRect, steps = LIVE_SWEEP) {
  return hashesFromRegion(video, cardRect, steps)
}

/** Bande du code collector de la carte cadrée dans la vidéo, prête pour l'OCR. */
export function codeImageFromVideoFrame(video, cardRect) {
  return codeBandImage(video, cardRect)
}

async function decodeFile(file) {
  if (typeof createImageBitmap === "function") return await createImageBitmap(file)
  /* Vieux navigateurs : <img> + URL objet. */
  const url = URL.createObjectURL(file)
  try {
    const image = new Image()
    await new Promise((resolve, reject) => {
      image.onload = resolve
      image.onerror = () => reject(new Error("Image illisible"))
      image.src = url
    })
    return image
  } finally {
    URL.revokeObjectURL(url)
  }
}

/** Photo importée : l'image entière est supposée être la carte. On en tire d'un coup le
    balayage complet d'empreintes ET la bande du code — la photo n'est décodée qu'une fois. */
export async function scanFile(file) {
  const image = await decodeFile(file)
  const rect = { sx: 0, sy: 0, sw: image.naturalWidth || image.width, sh: image.naturalHeight || image.height }
  try {
    return { hexes: hashesFromRegion(image, rect, PHOTO_SWEEP), codeImage: codeBandImage(image, rect) }
  } finally {
    image.close?.()
  }
}
