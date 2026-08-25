import { describe, expect, it } from "vitest"
import {
  ART_WINDOW,
  CODE_BAND,
  DIAGONAL_SHIFTS,
  PHOTO_SWEEP,
  LIVE_SWEEP,
  SWEEP_SCALES,
  artCrop,
  codeBandRect,
  stepRect,
  sweepBounds,
  sweepSteps
} from "./scanCapture.js"

/* Seule la géométrie du sous-crop est testable sous Node (le reste dépend du canvas 2D,
   mocké dans ScanView.spec.js). C'est elle qui doit coller au serveur : la fenêtre
   d'illustration (x 6→94 %, y 6→54 %), commune aux impressions FR et EN. */
describe("artCrop", () => {
  it("découpe la fenêtre d'illustration d'une carte pleine image (photo importée)", () => {
    const crop = artCrop({ sx: 0, sy: 0, sw: 1000, sh: 1400 })
    expect(crop).toEqual({ sx: 60, sy: 84, sw: 880, sh: 672 })
  })

  it("reste relatif au rectangle du cadre caméra (offset conservé)", () => {
    const crop = artCrop({ sx: 100, sy: 200, sw: 500, sh: 700 })
    expect(crop).toEqual({ sx: 130, sy: 242, sw: 440, sh: 336 })
  })

  it("arrondit chaque bord (Math.round), comme le serveur", () => {
    /* 333 px de large : bords à round(19.98)=20 et round(313.02)=313. */
    const crop = artCrop({ sx: 0, sy: 0, sw: 333, sh: 471 })
    expect(crop.sx).toBe(20)
    expect(crop.sw).toBe(293)
    /* 471 px de haut : round(28.26)=28, round(254.34)=254. */
    expect(crop.sy).toBe(28)
    expect(crop.sh).toBe(226)
  })

  it("expose la fenêtre attendue par le contrat (6→94 % en x, 6→54 % en y)", () => {
    expect(ART_WINDOW).toEqual({ x0: 0.06, x1: 0.94, y0: 0.06, y1: 0.54 })
  })
})

/* La bande du code doit tomber sur « UNL • 229* / 219 », imprimé en bas à gauche : c'est la
   seule zone que l'OCR regarde, une erreur ici et il ne lit jamais rien. */
describe("codeBandRect", () => {
  it("découpe le bas gauche de la carte (visuel de référence 744×1039)", () => {
    const band = codeBandRect({ sx: 0, sy: 0, sw: 744, sh: 1039 })
    expect(band).toEqual({ sx: 30, sy: 961, sw: 327, sh: 76 })
    /* Le texte du visuel de référence tient à x ≈ 35→175, y ≈ 995→1015 : dans la bande. */
    expect(band.sx).toBeLessThan(35)
    expect(band.sx + band.sw).toBeGreaterThan(175)
    expect(band.sy).toBeLessThan(995)
    expect(band.sy + band.sh).toBeGreaterThan(1015)
  })

  it("reste relatif au rectangle du cadre caméra (offset conservé)", () => {
    const band = codeBandRect({ sx: 100, sy: 200, sw: 500, sh: 700 })
    expect(band.sx).toBe(120)
    expect(band.sy).toBe(200 + Math.round(0.925 * 700))
  })

  it("expose la fenêtre attendue (x 4→48 %, y 92,5→99,8 %)", () => {
    expect(CODE_BAND).toEqual({ x0: 0.04, x1: 0.48, y0: 0.925, y1: 0.998 })
  })
})

describe("balayage multi-cadrage", () => {
  it("sweepSteps fait le produit rotations × échelles × décalages", () => {
    const steps = sweepSteps({
      scales: [1, 2],
      shifts: [
        [0, 0],
        [0.1, 0.1]
      ],
      rotations: [0, 1]
    })
    expect(steps).toHaveLength(8)
    expect(steps[0]).toEqual({ scale: 1, dx: 0, dy: 0, turns: 0 })
    expect(steps.filter((step) => step.turns === 1)).toHaveLength(4)
  })

  it("le plan de la boucle reste dans le budget (17 empreintes)", () => {
    expect(LIVE_SWEEP).toHaveLength(SWEEP_SCALES.length * DIAGONAL_SHIFTS.length + 2)
    expect(LIVE_SWEEP).toHaveLength(17)
    /* Les rotations de la boucle ne servent qu'aux champs de bataille : centre, échelle 1. */
    for (const step of LIVE_SWEEP.filter((s) => s.turns !== 0)) {
      expect(step).toMatchObject({ scale: 1, dx: 0, dy: 0 })
    }
  })

  it("le plan photo ne sort JAMAIS de l'image (sinon les bords noirs créent de faux positifs)", () => {
    const rect = { sx: 0, sy: 0, sw: 1000, sh: 1400 }
    for (const step of PHOTO_SWEEP) {
      const r = stepRect(rect, step)
      expect(r.sx).toBeGreaterThanOrEqual(-1e-9)
      expect(r.sy).toBeGreaterThanOrEqual(-1e-9)
      expect(r.sx + r.sw).toBeLessThanOrEqual(rect.sw + 1e-9)
      expect(r.sy + r.sh).toBeLessThanOrEqual(rect.sh + 1e-9)
    }
    /* L'englobant coïncide donc exactement avec la photo : rien n'est échantillonné dehors. */
    const bounds = sweepBounds(rect, PHOTO_SWEEP)
    expect(bounds.sx).toBeCloseTo(0, 6)
    expect(bounds.sy).toBeCloseTo(0, 6)
    expect(bounds.sw).toBeCloseTo(rect.sw, 6)
    expect(bounds.sh).toBeCloseTo(rect.sh, 6)
    /* 2 échelles décalables × 5 positions + 1 centre, sur 3 rotations. */
    expect(PHOTO_SWEEP).toHaveLength(33)
  })

  it("stepRect garde le centre du guide et applique échelle puis décalage", () => {
    const rect = { sx: 0, sy: 0, sw: 100, sh: 200 }
    expect(stepRect(rect, { scale: 1, dx: 0, dy: 0 })).toEqual(rect)
    /* 0,8 × : la carte cherchée est plus petite, centrée → 10 px de marge de chaque côté. */
    expect(stepRect(rect, { scale: 0.8, dx: 0, dy: 0 })).toEqual({ sx: 10, sy: 20, sw: 80, sh: 160 })
    /* Décalage exprimé en fraction du GUIDE, pas de la carte redimensionnée. */
    expect(stepRect(rect, { scale: 1, dx: 0.06, dy: -0.06 })).toEqual({ sx: 6, sy: -12, sw: 100, sh: 200 })
  })

  it("sweepBounds englobe toutes les étapes (zone à capturer une seule fois)", () => {
    const rect = { sx: 0, sy: 0, sw: 100, sh: 100 }
    const bounds = sweepBounds(rect, LIVE_SWEEP)
    /* Échelle max 1,15 (bord à -7,5) plus décalage 6 % : le bord le plus extérieur est à -13,5. */
    expect(bounds.sx).toBeCloseTo(-13.5, 6)
    expect(bounds.sy).toBeCloseTo(-13.5, 6)
    expect(bounds.sw).toBeCloseTo(127, 6)
    expect(bounds.sh).toBeCloseTo(127, 6)
    /* Le guide seul reste toujours inclus. */
    expect(bounds.sx).toBeLessThanOrEqual(rect.sx)
    expect(bounds.sx + bounds.sw).toBeGreaterThanOrEqual(rect.sx + rect.sw)
  })
})
