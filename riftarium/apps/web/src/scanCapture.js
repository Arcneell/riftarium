/* Côté navigateur du scan : capture canvas → ImageData réduit → empreinte (scanHash.js).
   Isolé de ScanView pour être mocké dans les tests (Node/jsdom n'a pas de canvas 2D). */

import { dhashFromImageData } from "./scanHash.js"

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

/* Taille de travail de la région carte avant rotation/crop : assez fine pour le hash,
   bornée pour que les getImageData restent négligeables. */
const REGION_MAX = 560

/** Copie la région de carte dans un canvas de travail (dimensions bornées). */
function regionToCanvas(source, { sx, sy, sw, sh }) {
  const scale = Math.min(1, REGION_MAX / Math.max(sw, sh))
  const { canvas, ctx } = makeCanvas(sw * scale, sh * scale)
  ctx.drawImage(source, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height)
  return canvas
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

/** Empreinte d'un canvas contenant la carte entière : fenêtre d'illustration puis dHash. */
function hashCardCanvas(canvas) {
  const { sx, sy, sw, sh } = artCrop({ sx: 0, sy: 0, sw: canvas.width, sh: canvas.height })
  return dhashFromImageData(imageDataFromRegion(canvas, sx, sy, sw, sh))
}

/* Les champs de bataille sont imprimés en paysage (visuels de référence 1038×744) :
   cadrés dans le guide vertical, ils arrivent pivotés de ±90°. On calcule donc
   l'empreinte sous trois orientations et le matching garde la meilleure — toute
   carte devient reconnaissable quel que soit son sens dans le cadre. */
const ROTATIONS = [0, 1, 3]

/** Empreintes (3 orientations) de la carte cadrée dans la vidéo. */
export function hashesFromVideoFrame(video, cardRect) {
  const region = regionToCanvas(video, cardRect)
  return ROTATIONS.map((turns) => hashCardCanvas(rotateCanvas(region, turns)))
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

/** Empreintes (3 orientations) d'une photo importée : l'image entière est supposée
    être la carte entière, on n'en hashe que la fenêtre d'illustration. */
export async function hashesFromFile(file) {
  const image = await decodeFile(file)
  const width = image.naturalWidth || image.width
  const height = image.naturalHeight || image.height
  try {
    const region = regionToCanvas(image, { sx: 0, sy: 0, sw: width, sh: height })
    return ROTATIONS.map((turns) => hashCardCanvas(rotateCanvas(region, turns)))
  } finally {
    image.close?.()
  }
}
