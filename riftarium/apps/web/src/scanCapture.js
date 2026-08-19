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

/** Empreinte de la carte cadrée dans la vidéo : zone du cadre, puis fenêtre d'illustration. */
export function hashFromVideoFrame(video, cardRect) {
  const { sx, sy, sw, sh } = artCrop(cardRect)
  return dhashFromImageData(imageDataFromRegion(video, sx, sy, sw, sh))
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

/** Empreinte d'une photo importée : l'image entière est supposée être la carte entière,
    on n'en hashe que la fenêtre d'illustration. */
export async function hashFromFile(file) {
  const image = await decodeFile(file)
  const width = image.naturalWidth || image.width
  const height = image.naturalHeight || image.height
  const { sx, sy, sw, sh } = artCrop({ sx: 0, sy: 0, sw: width, sh: height })
  try {
    return dhashFromImageData(imageDataFromRegion(image, sx, sy, sw, sh))
  } finally {
    image.close?.()
  }
}
