/* Empreinte perceptuelle dHash (variante horizontale + verticale), identique au serveur (Pillow).
   Tout est en JS pur — aucun canvas — pour rester testable sous Node. Les fonctions sont découpées :
   niveaux de gris, rééchantillonnage, bits, hexadécimal, distance et classement. */

const HASH_W = 16 // grille de comparaison : 16 bits par ligne / colonne
const HASH_H = 16

/** ImageData (RGBA) → niveaux de gris luma ITU-R 601 : { data: Float64Array, width, height }. */
export function grayscale(imageData) {
  const { data, width, height } = imageData
  const out = new Float64Array(width * height)
  for (let i = 0; i < out.length; i++) {
    const o = i * 4
    out[i] = 0.299 * data[o] + 0.587 * data[o + 1] + 0.114 * data[o + 2]
  }
  return { data: out, width, height }
}

/** Rééchantillonnage par moyenne de surface (box filter à recouvrement fractionnaire).
    Proche du BOX de Pillow : suffisant, le matching est un classement, pas une identité exacte.
    La sortie est arrondie à l'entier, comme l'uint8 de Pillow : sans cela, le bruit flottant
    (~1e-13) inverserait des bits sur les zones parfaitement uniformes. */
export function resizeGray(gray, targetW, targetH) {
  if (gray.width === targetW && gray.height === targetH) return gray
  const out = new Float64Array(targetW * targetH)
  const xRatio = gray.width / targetW
  const yRatio = gray.height / targetH
  for (let ty = 0; ty < targetH; ty++) {
    const y0 = ty * yRatio
    const y1 = y0 + yRatio
    for (let tx = 0; tx < targetW; tx++) {
      const x0 = tx * xRatio
      const x1 = x0 + xRatio
      let sum = 0
      let area = 0
      for (let y = Math.floor(y0); y < y1 && y < gray.height; y++) {
        const coverY = Math.min(y1, y + 1) - Math.max(y0, y)
        if (coverY <= 0) continue
        for (let x = Math.floor(x0); x < x1 && x < gray.width; x++) {
          const coverX = Math.min(x1, x + 1) - Math.max(x0, x)
          if (coverX <= 0) continue
          sum += gray.data[y * gray.width + x] * coverX * coverY
          area += coverX * coverY
        }
      }
      out[ty * targetW + tx] = area > 0 ? Math.round(sum / area) : 0
    }
  }
  return { data: out, width: targetW, height: targetH }
}

/** Bits du dHash sur une grille déjà à la bonne taille.
    Horizontal : 17×16, bit = 1 si px[y][x] > px[y][x+1]. Vertical : 16×17, bit = 1 si px[y][x] > px[y+1][x].
    Ligne par ligne, 256 bits chacun. */
export function hashBits(gray, direction) {
  const bits = new Uint8Array(HASH_W * HASH_H)
  let i = 0
  for (let y = 0; y < HASH_H; y++) {
    for (let x = 0; x < HASH_W; x++) {
      const left = gray.data[y * gray.width + x]
      const right = direction === "vertical" ? gray.data[(y + 1) * gray.width + x] : gray.data[y * gray.width + x + 1]
      bits[i++] = left > right ? 1 : 0
    }
  }
  return bits
}

/** Bits → hexadécimal, MSB en premier dans chaque octet. */
export function bitsToHex(bits) {
  let hex = ""
  for (let i = 0; i < bits.length; i += 8) {
    let byte = 0
    for (let j = 0; j < 8; j++) byte = (byte << 1) | bits[i + j]
    hex += byte.toString(16).padStart(2, "0")
  }
  return hex
}

/** Empreinte complète (H puis V, 128 hex) depuis un ImageData de taille quelconque. */
export function dhashFromImageData(imageData) {
  const gray = grayscale(imageData)
  const horizontal = hashBits(resizeGray(gray, HASH_W + 1, HASH_H), "horizontal")
  const vertical = hashBits(resizeGray(gray, HASH_W, HASH_H + 1), "vertical")
  return bitsToHex(horizontal) + bitsToHex(vertical)
}

/* Popcount des 16 valeurs d'un quartet : la distance se calcule chiffre hexa par chiffre hexa. */
const NIBBLE_ONES = [0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4]

/** Distance de Hamming entre deux empreintes hexadécimales de même longueur. */
export function hamming(hexA, hexB) {
  if (hexA.length !== hexB.length) throw new Error("Empreintes de longueurs différentes")
  let distance = 0
  for (let i = 0; i < hexA.length; i++) {
    distance += NIBBLE_ONES[parseInt(hexA[i], 16) ^ parseInt(hexB[i], 16)]
  }
  return distance
}

/** Les n entrées de l'index les plus proches de `hex` : [{ id, h, distance }], distance croissante.
    Les entrées d'un autre format (longueur différente) sont ignorées. */
export function bestMatches(hex, index, n = 3) {
  const scored = []
  for (const item of index || []) {
    if (!item?.h || item.h.length !== hex.length) continue
    scored.push({ ...item, distance: hamming(hex, item.h) })
  }
  scored.sort((a, b) => a.distance - b.distance)
  return scored.slice(0, n)
}

/** Comme bestMatches, mais avec plusieurs empreintes candidates (la carte a pu être
    cadrée pivotée — champs de bataille en paysage) : chaque entrée de l'index est
    scorée sur sa MEILLEURE distance parmi les empreintes fournies. */
export function bestMatchesMulti(hexes, index, n = 3) {
  const scored = []
  for (const item of index || []) {
    if (!item?.h) continue
    let best = Infinity
    for (const hex of hexes) {
      if (item.h.length !== hex.length) continue
      const distance = hamming(hex, item.h)
      if (distance < best) best = distance
    }
    if (best !== Infinity) scored.push({ ...item, distance: best })
  }
  scored.sort((a, b) => a.distance - b.distance)
  return scored.slice(0, n)
}

/* ------------------------------------------------------------------
   Index compact (boucle de scan temps réel)
   ------------------------------------------------------------------
   La boucle caméra compare ~17 empreintes par image à tout l'index
   (~1 500 cartes) quatre fois par seconde. `hamming()` lit 128 chiffres
   hexadécimaux un par un (parseInt + table) : ~200 000 parseInt par image,
   hors budget sur un mobile milieu de gamme. On pré-emballe donc l'index
   UNE fois en mots de 32 bits et la distance devient 16 XOR + 16 popcount.
   ------------------------------------------------------------------ */

/* 512 bits d'empreinte = 16 mots de 32 bits. */
export const HASH_WORDS = 16
const HASH_HEX_LENGTH = HASH_WORDS * 8

/** Empreinte hexadécimale (128 chiffres) → 16 mots de 32 bits, ou null si le format ne colle pas. */
export function packHash(hex) {
  if (typeof hex !== "string" || hex.length !== HASH_HEX_LENGTH) return null
  const words = new Uint32Array(HASH_WORDS)
  for (let w = 0; w < HASH_WORDS; w++) {
    const value = Number.parseInt(hex.slice(w * 8, w * 8 + 8), 16)
    if (Number.isNaN(value)) return null
    words[w] = value
  }
  return words
}

/** Popcount 32 bits sans table (SWAR) : moins de cache-miss qu'une table de 65 536 entrées. */
export function popcount32(value) {
  let v = value - ((value >>> 1) & 0x55555555)
  v = (v & 0x33333333) + ((v >>> 2) & 0x33333333)
  v = (v + (v >>> 4)) & 0x0f0f0f0f
  return Math.imul(v, 0x01010101) >>> 24
}

/** Emballe l'index une fois pour toutes. `entries` garde les items d'origine (id, rid…)
    dans l'ordre des blocs de `words` ; les entrées sans empreinte exploitable sont écartées
    (elles restent identifiables par leur code imprimé, pas par ressemblance). */
export function packIndex(index) {
  const entries = []
  const packed = []
  for (const item of index || []) {
    const words = packHash(item?.h)
    if (!words) continue
    entries.push(item)
    packed.push(words)
  }
  const words = new Uint32Array(packed.length * HASH_WORDS)
  for (let i = 0; i < packed.length; i++) words.set(packed[i], i * HASH_WORDS)
  return { entries, words, count: entries.length }
}

/** Distance de Hamming entre deux empreintes emballées (l'index est lu à plat, avec un décalage). */
function hammingPacked(query, words, offset) {
  let distance = 0
  for (let w = 0; w < HASH_WORDS; w++) distance += popcount32(query[w] ^ words[offset + w])
  return distance
}

/** Comme bestMatchesMulti, mais sur un index emballé par packIndex().

    `groupBy` (ex. "rid") ne garde que la meilleure carte par groupe : la décision de
    verrouillage compare la meilleure carte à la meilleure d'un AUTRE riftbound_id — sinon
    les variantes d'une même carte (étoile, art alternatif) se voleraient mutuellement l'écart. */
export function bestMatchesPacked(hexes, packed, n = 3, { groupBy = null } = {}) {
  if (!packed?.count) return []
  const queries = []
  for (const hex of hexes || []) {
    const words = packHash(hex)
    if (words) queries.push(words)
  }
  if (!queries.length) return []

  const scored = []
  const bestByGroup = groupBy ? new Map() : null
  for (let i = 0; i < packed.count; i++) {
    const offset = i * HASH_WORDS
    let best = Infinity
    for (const query of queries) {
      const distance = hammingPacked(query, packed.words, offset)
      if (distance < best) best = distance
    }
    const match = { ...packed.entries[i], distance: best }
    if (!bestByGroup) {
      scored.push(match)
      continue
    }
    const key = match[groupBy]
    const previous = bestByGroup.get(key)
    if (!previous || best < previous.distance) bestByGroup.set(key, match)
  }
  const result = bestByGroup ? [...bestByGroup.values()] : scored
  result.sort((a, b) => a.distance - b.distance)
  return result.slice(0, n)
}
