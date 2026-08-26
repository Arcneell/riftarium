import { describe, expect, it } from "vitest"
import {
  bestMatches,
  bestMatchesMulti,
  bestMatchesPacked,
  bitsToHex,
  dhashFromImageData,
  grayscale,
  hamming,
  hashBits,
  packHash,
  packIndex,
  popcount32,
  resizeGray
} from "./scanHash.js"

/* Node n'a pas de canvas : on fabrique les ImageData à la main ({ data, width, height }). */
function makeImageData(width, height, valueAt) {
  const data = new Uint8ClampedArray(width * height * 4)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const value = valueAt(x, y)
      const [r, g, b] = Array.isArray(value) ? value : [value, value, value]
      const o = (y * width + x) * 4
      data[o] = r
      data[o + 1] = g
      data[o + 2] = b
      data[o + 3] = 255
    }
  }
  return { data, width, height }
}

describe("grayscale", () => {
  it("applique le luma ITU-R 601 (0.299R + 0.587G + 0.114B)", () => {
    const image = makeImageData(
      3,
      1,
      (x) =>
        [
          [255, 0, 0],
          [0, 255, 0],
          [0, 0, 255]
        ][x]
    )
    const gray = grayscale(image)
    expect(gray.width).toBe(3)
    expect(gray.height).toBe(1)
    expect(gray.data[0]).toBeCloseTo(76.245, 3)
    expect(gray.data[1]).toBeCloseTo(149.685, 3)
    expect(gray.data[2]).toBeCloseTo(29.07, 3)
  })
})

describe("resizeGray", () => {
  it("rend la même grille si la taille est déjà bonne", () => {
    const gray = grayscale(makeImageData(17, 16, (x) => x))
    expect(resizeGray(gray, 17, 16)).toBe(gray)
  })

  it("moyenne par surface : une image uniforme reste uniforme, une moitié claire garde sa moyenne", () => {
    const uniform = resizeGray(grayscale(makeImageData(34, 32, () => 100)), 17, 16)
    for (const value of uniform.data) expect(value).toBeCloseTo(100, 6)

    /* 2×1 (0 et 200) réduit en 1×1 : moyenne exacte. */
    const half = resizeGray(grayscale(makeImageData(2, 1, (x) => (x === 0 ? 0 : 200))), 1, 1)
    expect(half.data[0]).toBeCloseTo(100, 6)
  })

  it("préserve la monotonie d'un dégradé (17 colonnes → 16)", () => {
    const gray = resizeGray(grayscale(makeImageData(17, 16, (x) => x * 15)), 16, 17)
    for (let x = 0; x < 15; x++) {
      expect(gray.data[x]).toBeLessThan(gray.data[x + 1])
    }
  })
})

describe("dhashFromImageData", () => {
  it("est déterministe et produit 128 hexadécimaux", () => {
    const image = makeImageData(17, 16, (x, y) => (x * 31 + y * 57) % 256)
    const hex = dhashFromImageData(image)
    expect(hex).toMatch(/^[0-9a-f]{128}$/)
    expect(dhashFromImageData(makeImageData(17, 16, (x, y) => (x * 31 + y * 57) % 256))).toBe(hex)
  })

  it("dégradé horizontal décroissant : moitié H à 1 (ffff…), moitié V à 0", () => {
    const hex = dhashFromImageData(makeImageData(17, 16, (x) => 255 - x * 15))
    expect(hex.slice(0, 64)).toBe("f".repeat(64))
    expect(hex.slice(64)).toBe("0".repeat(64))
  })

  it("dégradé horizontal croissant : tous les bits à 0", () => {
    const hex = dhashFromImageData(makeImageData(17, 16, (x) => x * 15))
    expect(hex).toBe("0".repeat(128))
  })

  it("dégradé vertical décroissant : moitié H à 0, moitié V à 1", () => {
    const hex = dhashFromImageData(makeImageData(16, 17, (x, y) => 255 - y * 15))
    expect(hex.slice(0, 64)).toBe("0".repeat(64))
    expect(hex.slice(64)).toBe("f".repeat(64))
  })

  it("damier de colonnes : motif alterné 10101010 (0xaa) sur la partie H, MSB en premier", () => {
    const hex = dhashFromImageData(makeImageData(17, 16, (x) => (x % 2 === 0 ? 255 : 0)))
    expect(hex.slice(0, 64)).toBe("aa".repeat(32))
  })

  it("réduit une image plus grande vers la grille : le dégradé donne le même hash qu'en 17×16", () => {
    const small = dhashFromImageData(makeImageData(17, 16, (x) => 255 - x * 15))
    const large = dhashFromImageData(makeImageData(170, 160, (x) => 255 - Math.floor(x * 1.5)))
    expect(large).toBe(small)
  })
})

describe("hashBits / bitsToHex", () => {
  it("compare verticalement sur une grille 16×17", () => {
    const gray = grayscale(makeImageData(16, 17, (x, y) => 255 - y * 15))
    const bits = hashBits(gray, "vertical")
    expect(bits.length).toBe(256)
    expect([...bits].every((bit) => bit === 1)).toBe(true)
  })

  it("emballe les bits MSB en premier par octet", () => {
    expect(bitsToHex([1, 0, 0, 0, 0, 0, 0, 0])).toBe("80")
    expect(bitsToHex([0, 0, 0, 0, 0, 0, 0, 1])).toBe("01")
    expect(bitsToHex([1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1])).toBe("aaff")
  })
})

describe("hamming", () => {
  it("0 pour deux empreintes identiques, 512 pour deux opposées de 128 hex", () => {
    const zeros = "0".repeat(128)
    expect(hamming(zeros, zeros)).toBe(0)
    expect(hamming(zeros, "f".repeat(128))).toBe(512)
  })

  it("compte les bits différents", () => {
    expect(hamming("00", "01")).toBe(1)
    expect(hamming("0f", "f0")).toBe(8)
    expect(hamming("ab", "ab")).toBe(0)
  })

  it("refuse des longueurs différentes", () => {
    expect(() => hamming("00", "000")).toThrow()
  })
})

describe("bestMatches", () => {
  const zeros = "0".repeat(128)
  const index = [
    { id: "loin", h: "f".repeat(128) }, // 512
    { id: "proche", h: zeros.slice(0, 127) + "1" }, // 1
    { id: "exact", h: zeros }, // 0
    { id: "moyen", h: "0f" + zeros.slice(2) } // 4
  ]

  it("retourne les n plus proches, triés par distance croissante", () => {
    const matches = bestMatches(zeros, index)
    expect(matches.map((m) => m.id)).toEqual(["exact", "proche", "moyen"])
    expect(matches.map((m) => m.distance)).toEqual([0, 1, 4])
  })

  it("respecte n et tolère un index vide ou absent", () => {
    expect(bestMatches(zeros, index, 1).map((m) => m.id)).toEqual(["exact"])
    expect(bestMatches(zeros, [])).toEqual([])
    expect(bestMatches(zeros, undefined)).toEqual([])
  })

  it("ignore les entrées malformées (empreinte absente ou d'une autre longueur)", () => {
    const matches = bestMatches(zeros, [{ id: "cassé" }, { id: "court", h: "00" }, ...index])
    expect(matches.map((m) => m.id)).toEqual(["exact", "proche", "moyen"])
  })
})

describe("bestMatchesMulti", () => {
  const zeros = "0".repeat(128)
  const ones = "f".repeat(128)
  const index = [
    { id: "portrait", h: zeros }, // exact pour l'empreinte 0°
    { id: "paysage", h: ones }, // exact pour l'empreinte pivotée
    { id: "loin", h: "0f" + ones.slice(2) }
  ]

  it("score chaque carte sur sa meilleure distance parmi les orientations", () => {
    const matches = bestMatchesMulti([zeros, ones], index)
    expect(matches[0].distance).toBe(0)
    expect(matches[1].distance).toBe(0)
    expect(new Set(matches.slice(0, 2).map((m) => m.id))).toEqual(new Set(["portrait", "paysage"]))
  })

  it("équivaut à bestMatches avec une seule empreinte", () => {
    expect(bestMatchesMulti([zeros], index)).toEqual(bestMatches(zeros, index))
  })
})

describe("index compact (packIndex / bestMatchesPacked)", () => {
  const zeros = "0".repeat(128)
  const ones = "f".repeat(128)

  /* Empreinte pseudo-aléatoire déterministe : de vraies empreintes, pas des cas dégénérés. */
  function fakeHash(seed) {
    let state = seed * 2654435761 + 1
    let hex = ""
    for (let i = 0; i < 128; i++) {
      state = (state * 1103515245 + 12345) & 0x7fffffff
      hex += (state >>> 7).toString(16).slice(-1)
    }
    return hex
  }

  it("popcount32 compte les bits à 1, y compris sur le bit de signe", () => {
    expect(popcount32(0)).toBe(0)
    expect(popcount32(1)).toBe(1)
    expect(popcount32(0xffffffff)).toBe(32)
    expect(popcount32(0x80000000)).toBe(1)
    expect(popcount32(0xdeadbeef)).toBe(24)
  })

  it("packHash refuse ce qui n'est pas une empreinte de 128 hexadécimaux", () => {
    expect(packHash(zeros)).toBeInstanceOf(Uint32Array)
    expect(packHash(zeros).length).toBe(16)
    expect(packHash("00")).toBeNull()
    expect(packHash(null)).toBeNull()
    expect(packHash("z".repeat(128))).toBeNull()
    /* Mot de poids fort au-delà de 2^31 : l'emballage doit rester non signé. */
    expect(packHash(ones)[0]).toBe(0xffffffff)
  })

  it("packIndex écarte les entrées inexploitables et conserve les items d'origine", () => {
    const packed = packIndex([
      { id: "a", rid: "ogn-001-298", h: zeros },
      { id: "cassé", rid: "ogn-002-298" },
      { id: "court", rid: "ogn-003-298", h: "00" },
      { id: "b", rid: "ogn-004-298", h: ones }
    ])
    expect(packed.count).toBe(2)
    expect(packed.entries.map((e) => e.id)).toEqual(["a", "b"])
    expect(packed.words.length).toBe(32)
  })

  it("donne exactement les mêmes distances que hamming() sur 40 empreintes aléatoires", () => {
    const index = Array.from({ length: 40 }, (_, i) => ({ id: `c${i}`, rid: `ogn-${i}-298`, h: fakeHash(i + 1) }))
    const query = fakeHash(999)
    const packed = packIndex(index)
    const fast = bestMatchesPacked([query], packed, 40)
    const slow = bestMatches(query, index, 40)
    expect(fast.map((m) => [m.id, m.distance])).toEqual(slow.map((m) => [m.id, m.distance]))
    /* Contrôle direct : aucune distance ne dévie de la référence hexadécimale. */
    for (const match of fast) expect(match.distance).toBe(hamming(query, match.h))
  })

  it("garde la meilleure distance parmi plusieurs orientations, comme bestMatchesMulti", () => {
    const index = [
      { id: "portrait", rid: "ogn-001-298", h: zeros },
      { id: "paysage", rid: "ogn-002-298", h: ones },
      { id: "loin", rid: "ogn-003-298", h: "0f" + ones.slice(2) }
    ]
    const packed = packIndex(index)
    expect(bestMatchesPacked([zeros, ones], packed, 3).map((m) => [m.id, m.distance])).toEqual(
      bestMatchesMulti([zeros, ones], index, 3).map((m) => [m.id, m.distance])
    )
  })

  it("groupBy: 'rid' ne garde que la meilleure variante par carte", () => {
    const packed = packIndex([
      { id: "base", rid: "ogn-037-298", h: zeros },
      { id: "etoile", rid: "ogn-037-298", h: zeros.slice(0, 127) + "1" }, // même rid, un bit d'écart
      { id: "autre", rid: "ogn-040-298", h: zeros.slice(0, 126) + "ff" }
    ])
    const grouped = bestMatchesPacked([zeros], packed, 3, { groupBy: "rid" })
    expect(grouped.map((m) => m.id)).toEqual(["base", "autre"])
    /* Sans regroupement, les deux variantes occupent les deux premières places. */
    expect(bestMatchesPacked([zeros], packed, 3).map((m) => m.id)).toEqual(["base", "etoile", "autre"])
  })

  it("tolère un index vide et une requête inexploitable", () => {
    expect(bestMatchesPacked([zeros], packIndex([]), 3)).toEqual([])
    expect(bestMatchesPacked(["00"], packIndex([{ id: "a", h: zeros }]), 3)).toEqual([])
    expect(bestMatchesPacked([], packIndex([{ id: "a", h: zeros }]), 3)).toEqual([])
  })
})
