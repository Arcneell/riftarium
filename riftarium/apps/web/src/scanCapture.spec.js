import { describe, expect, it } from "vitest"
import { ART_WINDOW, artCrop } from "./scanCapture.js"

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
