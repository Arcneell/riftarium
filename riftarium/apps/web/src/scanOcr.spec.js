import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

/* jsdom n'a ni canvas ni Worker : tesseract.js est mocké entièrement. Les fonctions
   pures (renforcement pixel, parsing, appariement) sont en revanche testées pour de vrai —
   c'est là que se joue la fiabilité de la lecture du code. */
const recognize = vi.fn()
const setParameters = vi.fn().mockResolvedValue({})
const terminate = vi.fn().mockResolvedValue({})
const createWorker = vi.fn()

vi.mock("tesseract.js", () => ({
  createWorker: (...args) => createWorker(...args),
  OEM: { LSTM_ONLY: 1 },
  PSM: { SINGLE_LINE: "7" }
}))

const {
  OVERNUMBER_MARGIN,
  OcrError,
  cancelOcr,
  collectorTotals,
  enhanceCodeBand,
  ensureOcrWorker,
  formatCode,
  isOcrBusy,
  matchByCode,
  parseCollectorCode,
  parseRiftboundId,
  readCodeText,
  terminateOcrWorker
} = await import("./scanOcr.js")

/* Index minimal : deux extensions aux totaux distincts, et les trois impressions du
   numéro 37 (base, art alternatif, étoile) qui sont le cas ambigu par excellence. */
const INDEX = [
  { id: "ogn-037", rid: "ogn-037-298", h: null },
  { id: "ogn-037a", rid: "ogn-037a-298", h: null },
  { id: "ogn-037s", rid: "ogn-037*-298", h: null },
  { id: "ogn-247", rid: "ogn-247-298", h: null },
  { id: "unl-229", rid: "unl-229-219", h: null },
  { id: "unl-229s", rid: "unl-229*-219", h: null },
  { id: "unl-270", rid: "unl-270-219", h: null }, // overnumbered : 270 > 219
  { id: "cassé", rid: "pas-un-code" }
]
const TOTALS = collectorTotals(INDEX)

function imageData(width, height, valueAt) {
  const data = new Uint8ClampedArray(width * height * 4)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const value = valueAt(x, y)
      const o = (y * width + x) * 4
      data[o] = value
      data[o + 1] = value
      data[o + 2] = value
      data[o + 3] = 255
    }
  }
  return { data, width, height }
}

describe("enhanceCodeBand", () => {
  it("inverse : le texte blanc de la carte devient sombre, le fond sombre devient clair", () => {
    /* Bande réaliste : fond très sombre (30), quelques pixels de texte clairs (220). */
    const pixels = imageData(10, 10, (x, y) => (y === 5 && x > 2 && x < 7 ? 220 : 30))
    enhanceCodeBand(pixels)
    const at = (x, y) => pixels.data[(y * 10 + x) * 4]
    expect(at(0, 0)).toBeGreaterThan(200) // fond → clair
    expect(at(4, 5)).toBeLessThan(60) // texte → sombre
    /* Gris neutre et opaque : tesseract n'a pas à trancher entre les canaux. */
    const o = (5 * 10 + 4) * 4
    expect(pixels.data[o]).toBe(pixels.data[o + 1])
    expect(pixels.data[o + 1]).toBe(pixels.data[o + 2])
    expect(pixels.data[o + 3]).toBe(255)
  })

  it("étire le contraste d'une bande peu contrastée (photo sous-exposée)", () => {
    const pixels = imageData(10, 10, (x, y) => (y === 5 ? 96 : 80))
    enhanceCodeBand(pixels)
    const fond = pixels.data[0]
    const texte = pixels.data[(5 * 10 + 4) * 4]
    /* 16 niveaux d'écart à l'entrée, largement plus à la sortie. */
    expect(fond - texte).toBeGreaterThan(100)
  })

  it("ne divise pas par zéro sur une bande uniforme (caméra bouchée)", () => {
    const pixels = imageData(4, 4, () => 120)
    enhanceCodeBand(pixels)
    expect([...pixels.data.slice(0, 4)]).toEqual([135, 135, 135, 255])
  })
})

describe("parseRiftboundId", () => {
  it("découpe set / numéro / suffixe / total", () => {
    expect(parseRiftboundId("unl-229*-219")).toEqual({
      set: "UNL",
      number: 229,
      suffix: "*",
      star: true,
      total: 219
    })
    expect(parseRiftboundId("ogn-037a-298")).toMatchObject({ set: "OGN", number: 37, suffix: "a", star: false })
    expect(parseRiftboundId("ogn-247-298")).toMatchObject({ number: 247, total: 298, star: false })
  })

  it("refuse ce qui n'est pas un riftbound_id", () => {
    expect(parseRiftboundId("pas-un-code")).toBeNull()
    expect(parseRiftboundId("")).toBeNull()
    expect(parseRiftboundId(null)).toBeNull()
    expect(parseRiftboundId(undefined)).toBeNull()
  })
})

describe("collectorTotals", () => {
  it("déduit les totaux d'impression de l'index et ignore les rid illisibles", () => {
    expect([...TOTALS].sort()).toEqual([219, 298])
  })

  it("tolère un index absent", () => {
    expect(collectorTotals(undefined).size).toBe(0)
  })
})

describe("parseCollectorCode", () => {
  it("lit le code propre d'une carte à étoile", () => {
    expect(parseCollectorCode("UNL 229*/219", TOTALS)).toEqual({ set: "UNL", number: 229, star: true, total: 219 })
  })

  it("lit un code sans étoile", () => {
    expect(parseCollectorCode("OGN 247/298", TOTALS)).toEqual({ set: "OGN", number: 247, star: false, total: 298 })
  })

  it("survit au bruit typique de l'OCR (point médian perdu, espaces parasites)", () => {
    expect(parseCollectorCode("  UNL   229 * / 219  ", TOTALS)).toMatchObject({ number: 229, star: true, total: 219 })
    expect(parseCollectorCode("UNL229/219", TOTALS)).toMatchObject({ set: "UNL", number: 229, total: 219 })
  })

  it("retrouve la coupure quand le séparateur a disparu (« 229219 »)", () => {
    /* Repli : l'étoile est alors indétectable, matchByCode proposera les deux variantes. */
    expect(parseCollectorCode("UNL 229219", TOTALS)).toEqual({ set: "UNL", number: 229, star: false, total: 219 })
  })

  it("rejette un total inconnu de l'index plutôt que de désigner une carte au hasard", () => {
    expect(parseCollectorCode("XXX 100/279", TOTALS)).toBeNull()
    expect(parseCollectorCode("UNL 229/2I9", TOTALS)).toBeNull() // le I n'est pas un chiffre
  })

  it("accepte un numéro « overnumbered » mais pas n'importe quel numéro", () => {
    expect(parseCollectorCode("UNL 270/219", TOTALS)).toMatchObject({ number: 270, total: 219 })
    expect(219 + OVERNUMBER_MARGIN).toBe(279)
    expect(parseCollectorCode("UNL 280/219", TOTALS)).toBeNull()
    expect(parseCollectorCode("UNL 0/219", TOTALS)).toBeNull()
  })

  it("ignore un parasite lu avant le code (reste du texte de la carte)", () => {
    expect(parseCollectorCode("3 OR MORE UNL 229/219", TOTALS)).toMatchObject({ number: 229, total: 219 })
  })

  it("se passe du set quand il n'a pas été lu", () => {
    expect(parseCollectorCode("229/219", TOTALS)).toEqual({ set: null, number: 229, star: false, total: 219 })
  })

  it("renvoie null sans texte, sans totaux connus, ou sur du vide", () => {
    expect(parseCollectorCode("", TOTALS)).toBeNull()
    expect(parseCollectorCode(null, TOTALS)).toBeNull()
    expect(parseCollectorCode("UNL 229/219", new Set())).toBeNull()
    expect(parseCollectorCode("UNL 229/219", undefined)).toBeNull()
  })

  it("accepte un tableau de totaux comme un Set", () => {
    expect(parseCollectorCode("UNL 229/219", [219])).toMatchObject({ number: 229 })
  })
})

describe("matchByCode", () => {
  it("un code sans ambiguïté ne désigne qu'un riftbound_id", () => {
    const found = matchByCode({ set: "OGN", number: 247, total: 298, star: false }, INDEX)
    expect(found.rids).toEqual(["ogn-247-298"])
    expect(found.items.map((item) => item.id)).toEqual(["ogn-247"])
  })

  it("rend TOUTES les variantes du numéro, étoile lue ou pas : au hash de trancher", () => {
    const sansEtoile = matchByCode({ set: "UNL", number: 229, total: 219, star: false }, INDEX)
    const avecEtoile = matchByCode({ set: "UNL", number: 229, total: 219, star: true }, INDEX)
    /* Même ensemble des deux côtés : l'étoile ne retire jamais une variante… */
    expect(new Set(sansEtoile.rids)).toEqual(new Set(avecEtoile.rids))
    /* …elle ne fait que placer devant celle qui correspond, pour le cas où aucune empreinte
       n'est disponible pour départager. */
    expect(sansEtoile.rids[0]).toBe("unl-229-219")
    expect(avecEtoile.rids[0]).toBe("unl-229*-219")
  })

  it("le suffixe de variante ne change pas le numéro : les trois impressions du 37 sortent", () => {
    const found = matchByCode({ set: "OGN", number: 37, total: 298, star: false }, INDEX)
    expect(found.rids).toEqual(["ogn-037-298", "ogn-037a-298", "ogn-037*-298"])
  })

  it("le set désambiguïse, mais un set mal lu ne fait pas perdre la lecture", () => {
    /* « OGN » lu à la place de « UNL » : le repli sur le numéro seul retrouve la carte. */
    const found = matchByCode({ set: "OGN", number: 229, total: 219, star: false }, INDEX)
    expect(found.rids).toEqual(["unl-229-219", "unl-229*-219"])
  })

  it("rend une liste vide sur un code inconnu ou absent", () => {
    expect(matchByCode({ set: "UNL", number: 999, total: 219 }, INDEX).items).toEqual([])
    expect(matchByCode(null, INDEX)).toEqual({ items: [], rids: [] })
  })
})

describe("formatCode", () => {
  it("écrit le code comme il est imprimé, numéro complété à la longueur du total", () => {
    expect(formatCode({ set: "UNL", number: 229, star: true, total: 219 })).toBe("UNL 229*/219")
    expect(formatCode({ set: null, number: 247, star: false, total: 298 })).toBe("247/298")
    /* La carte porte « OGN 002/298 », pas « OGN 2/298 » : sans padding l'utilisateur ne
       reconnaît pas ce qui est écrit sur sa carte. */
    expect(formatCode({ set: "OGN", number: 2, star: false, total: 298 })).toBe("OGN 002/298")
    expect(formatCode({ set: "UNL", number: 7, star: true, total: 219 })).toBe("UNL 007*/219")
    expect(formatCode(null)).toBe("")
  })
})

describe("worker OCR", () => {
  beforeEach(() => {
    createWorker.mockReset()
    recognize.mockReset()
    createWorker.mockResolvedValue({ setParameters, recognize, terminate })
  })

  afterEach(async () => {
    await terminateOcrWorker()
  })

  it("s'auto-héberge sous /ocr/ (la CSP interdit le CDN) et se configure pour une ligne de code", async () => {
    await ensureOcrWorker()
    const [langs, oem, options] = createWorker.mock.calls[0]
    expect(langs).toBe("eng")
    expect(oem).toBe(1) // OEM.LSTM_ONLY : le modèle 4.0.0_best_int n'a pas le moteur historique
    expect(options).toMatchObject({
      workerPath: "/ocr/worker.min.js",
      corePath: "/ocr/",
      langPath: "/ocr",
      workerBlobURL: false, // blob: est bloqué par la CSP
      gzip: true
    })
    expect(setParameters).toHaveBeenCalledWith(
      expect.objectContaining({
        tessedit_pageseg_mode: "7",
        preserve_interword_spaces: "1",
        user_defined_dpi: "300"
      })
    )
    /* Pas de whitelist : OEM.LSTM_ONLY l'ignore. La croire efficace donnerait une fausse
       confiance dans la lecture — le vrai filtre est parseCollectorCode + les totaux connus. */
    expect(setParameters.mock.calls.at(-1)[0]).not.toHaveProperty("tessedit_char_whitelist")
  })

  it("ne crée qu'un worker, même appelé plusieurs fois", async () => {
    await Promise.all([ensureOcrWorker(), ensureOcrWorker()])
    await ensureOcrWorker()
    expect(createWorker).toHaveBeenCalledTimes(1)
  })

  it("relaie la progression du chargement au HUD", async () => {
    const onProgress = vi.fn()
    createWorker.mockImplementation(async (_langs, _oem, options) => {
      options.logger({ status: "loading tesseract core", progress: 0.5 })
      return { setParameters, recognize, terminate }
    })
    await ensureOcrWorker(onProgress)
    expect(onProgress).toHaveBeenCalledWith({ status: "loading tesseract core", progress: 0.5 })
  })

  it("readCodeText rend le texte reconnu et n'accepte qu'un OCR à la fois", async () => {
    let release
    const pending = new Promise((resolve) => (release = resolve))
    recognize.mockReturnValue(pending)
    await ensureOcrWorker() // le worker est prêt : seule la reconnaissance reste en suspens
    const first = readCodeText({})
    /* Deuxième appel pendant le premier : refusé (null), sans jeter — la boucle saute son tour. */
    expect(isOcrBusy()).toBe(true)
    await expect(readCodeText({})).resolves.toBeNull()
    release({ data: { text: "UNL 229*/219" } })
    await expect(first).resolves.toBe("UNL 229*/219")
    expect(isOcrBusy()).toBe(false)
  })

  it("distingue un moteur qui ne charge pas d'une lecture ratée (étage de l'erreur)", async () => {
    createWorker.mockRejectedValueOnce(new Error("wasm refusé"))
    const loadFailure = await readCodeText({}).catch((e) => e)
    expect(loadFailure).toBeInstanceOf(OcrError)
    expect(loadFailure.stage).toBe("load")

    createWorker.mockResolvedValue({ setParameters, recognize, terminate })
    recognize.mockRejectedValueOnce(new Error("image illisible"))
    await expect(readCodeText({})).rejects.toMatchObject({ name: "OcrError", stage: "recognize" })
    /* Une lecture ratée ne condamne pas le moteur : la place est rendue. */
    expect(isOcrBusy()).toBe(false)
  })

  it("cancelOcr abandonne la lecture en vol et libère la place immédiatement", async () => {
    let release
    recognize.mockReturnValue(new Promise((resolve) => (release = resolve)))
    await ensureOcrWorker()
    const abandonnee = readCodeText({})
    expect(isOcrBusy()).toBe(true)

    cancelOcr()
    expect(isOcrBusy()).toBe(false) // la photo importée peut lancer sa propre lecture tout de suite
    release({ data: { text: "OGN 247/298" } })
    /* Le texte périmé n'est jamais rendu à l'appelant : il aurait verrouillé la carte
       précédente par-dessus le résultat de la photo. */
    await expect(abandonnee).rejects.toMatchObject({ name: "OcrError", stage: "recognize" })
  })

  it("terminate pendant une reconnaissance en vol : la promesse est rejetée, pas oubliée", async () => {
    let release
    recognize.mockReturnValue(new Promise((resolve) => (release = resolve)))
    await ensureOcrWorker()
    const enVol = readCodeText({})
    await terminateOcrWorker()
    expect(terminate).toHaveBeenCalled()
    release({ data: { text: "OGN 247/298" } })
    await expect(enVol).rejects.toMatchObject({ name: "OcrError" })
    expect(isOcrBusy()).toBe(false)
  })

  it("un worker relancé pendant un terminate lent n'est pas tué par ce terminate", async () => {
    /* Retour rapide sur /scan : shutdown() est encore en train d'arrêter l'ancien worker
       quand le montage en demande un nouveau. Chaque instance vit dans SA closure, donc
       l'arrêt ne peut porter que sur l'ancienne. */
    const premier = { setParameters, recognize, terminate: vi.fn().mockResolvedValue({}) }
    const second = { setParameters, recognize, terminate: vi.fn().mockResolvedValue({}) }
    createWorker.mockResolvedValueOnce(premier).mockResolvedValueOnce(second)

    await ensureOcrWorker()
    const arret = terminateOcrWorker()
    const relance = ensureOcrWorker()
    await arret
    await relance

    expect(premier.terminate).toHaveBeenCalled()
    expect(second.terminate).not.toHaveBeenCalled()
    /* Et le nouveau worker répond bien : la session n'est pas condamnée. */
    recognize.mockResolvedValue({ data: { text: "OGN 247/298" } })
    await expect(readCodeText({})).resolves.toBe("OGN 247/298")
  })

  it("un chargement en échec est réessayable (rien n'est mis en cache)", async () => {
    createWorker.mockRejectedValueOnce(new Error("wasm refusé"))
    await expect(ensureOcrWorker()).rejects.toThrow("wasm refusé")
    createWorker.mockResolvedValue({ setParameters, recognize, terminate })
    await expect(ensureOcrWorker()).resolves.toBeTruthy()
  })

  it("terminateOcrWorker arrête le worker et libère la place", async () => {
    await ensureOcrWorker()
    await terminateOcrWorker()
    expect(terminate).toHaveBeenCalled()
    await ensureOcrWorker()
    expect(createWorker).toHaveBeenCalledTimes(2)
  })
})
