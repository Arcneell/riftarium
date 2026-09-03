import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  AUTO_RELEASE_MS,
  AUTO_RESUME_DELAY,
  FRAME_INTERVAL,
  HINT_DELAY,
  LOCK_STREAK,
  OCR_MAX_FAILURES,
  useCardScanner
} from "./useCardScanner.js"
import { OcrError } from "../scanOcr.js"

/* Aucune vraie image ici : la capture et l'OCR sont injectés. Ce qui est testé, c'est la
   DÉCISION — quand verrouiller, sur quelle carte, et quand refuser de le faire. */

/** Empreinte à `nibbles` quartets de « f » : sa distance à H(0) vaut 4 × nibbles. */
const H = (nibbles) => "f".repeat(nibbles) + "0".repeat(128 - nibbles)
const ZERO = H(0)
const FAR = H(128)

/* Index : deux cartes bien distinctes (0 et 16 bits de ZERO), plus les deux impressions
   avec/sans étoile du même numéro, séparées de 12 bits entre elles — le cas où le code seul
   ne suffit pas et où l'écart de hash décide. */
const INDEX = [
  { id: "a", rid: "ogn-001-298", h: H(0) },
  { id: "b", rid: "ogn-002-298", h: H(4) },
  { id: "star", rid: "unl-229*-219", h: H(10) },
  { id: "plain", rid: "unl-229-219", h: H(13) }
]

function makeScanner(overrides = {}) {
  const loadCard = vi.fn(async (id) => ({ id, name: `Carte ${id}`, price_eur: 3.2 }))
  const addCard = vi.fn(async () => ({ qty: 1 }))
  const vibrate = vi.fn()
  const scanner = useCardScanner({
    loadCard,
    addCard,
    vibrate,
    grabHashes: () => [ZERO],
    grabCodeImage: () => ({}),
    readText: null,
    ...overrides
  })
  scanner.setIndex(INDEX)
  return { scanner, loadCard, addCard, vibrate }
}

/* Nombre d'images de boucle couvrant un intervalle d'OCR (1200 ms à 250 ms l'image). */
const OCR_INTERVAL_STEPS = 5

/** Démarre la boucle et laisse passer sa première image (elle part sans délai). */
async function startScan(scanner) {
  scanner.start()
  await vi.advanceTimersByTimeAsync(0)
}

/** Laisse passer `count` images supplémentaires. */
async function frames(count) {
  for (let i = 0; i < count; i++) await vi.advanceTimersByTimeAsync(FRAME_INTERVAL)
}

describe("useCardScanner", () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it("l'index compact ne retient que les cartes ayant une empreinte", () => {
    const { scanner } = makeScanner()
    scanner.setIndex([...INDEX, { id: "sans-hash", rid: "ogn-003-298", h: null }])
    expect(scanner.hashedCount.value).toBe(4)
  })

  describe("verrouillage par ressemblance", () => {
    it("exige trois images consécutives sur la même carte avant de verrouiller", async () => {
      const { scanner, loadCard, vibrate } = makeScanner()
      await startScan(scanner)
      await frames(LOCK_STREAK - 2)
      expect(scanner.state.value).toBe("scanning")
      expect(loadCard).not.toHaveBeenCalled()

      await frames(1)
      expect(scanner.state.value).toBe("locked")
      expect(scanner.result.value.id).toBe("a")
      expect(scanner.result.value.method).toBe("hash")
      expect(scanner.result.value.distance).toBe(0)
      expect(scanner.result.value.card.name).toBe("Carte a")
      /* Une seule requête réseau au verrouillage, jamais dans la boucle. */
      expect(loadCard).toHaveBeenCalledTimes(1)
      expect(vibrate).toHaveBeenCalledWith(30)
      scanner.stop()
    })

    it("propose les alternatives sans les charger (ce sont des ids, pas des cartes)", async () => {
      const { scanner, loadCard } = makeScanner()
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      expect(scanner.result.value.alternatives.map((alt) => alt.id)).toEqual(["b", "star", "plain"])
      expect(loadCard).toHaveBeenCalledTimes(1)
      scanner.stop()
    })

    it("ne verrouille pas quand la deuxième carte est trop proche (écart < 12 bits)", async () => {
      /* Index resserré : 8 bits séparent les deux meilleures, verrouiller serait un tirage. */
      const { scanner } = makeScanner()
      scanner.setIndex([
        { id: "a", rid: "ogn-001-298", h: ZERO },
        { id: "b", rid: "ogn-002-298", h: H(2) }
      ])
      await startScan(scanner)
      await frames(6)
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("index dégradé (un seul groupe alors qu'il y a plusieurs cartes) : pas de verrouillage", async () => {
      /* Cas réel : un vieux payload sans `rid` regroupe tout sous la même clé. Il n'y a alors
         plus de deuxième candidat, donc plus de marge vérifiable — verrouiller reviendrait à
         désigner une carte au hasard. */
      const { scanner } = makeScanner()
      scanner.setIndex([
        { id: "a", rid: undefined, h: H(0) },
        { id: "b", rid: undefined, h: H(4) },
        { id: "c", rid: undefined, h: H(10) }
      ])
      await startScan(scanner)
      await frames(6)
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("index à une seule carte : le verrouillage reste possible (aucune ambiguïté à lever)", async () => {
      const { scanner } = makeScanner()
      scanner.setIndex([{ id: "seule", rid: "ogn-001-298", h: H(0) }])
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      expect(scanner.state.value).toBe("locked")
      expect(scanner.result.value.id).toBe("seule")
      scanner.stop()
    })

    it("ne verrouille pas au-delà de 120/512, même stable et sans concurrence", async () => {
      const { scanner } = makeScanner({ grabHashes: () => [FAR] })
      scanner.setIndex([{ id: "a", rid: "ogn-001-298", h: ZERO }])
      await startScan(scanner)
      await frames(6)
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("remet le compteur à zéro quand la meilleure carte change (main qui bouge)", async () => {
      let hex = ZERO
      const { scanner } = makeScanner({ grabHashes: () => [hex] })
      await startScan(scanner)
      await frames(1)
      hex = H(4) // la carte « b » passe devant
      await frames(2)
      hex = ZERO
      await frames(2)
      /* Aucune série de 3 n'a été atteinte sur une même carte : toujours en recherche. */
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("affiche un conseil après 8 s sans verrouillage, sans arrêter la boucle", async () => {
      const { scanner } = makeScanner({ grabHashes: () => [FAR] })
      scanner.setIndex([{ id: "a", rid: "ogn-001-298", h: ZERO }])
      await startScan(scanner)
      await vi.advanceTimersByTimeAsync(HINT_DELAY - FRAME_INTERVAL)
      expect(scanner.hint.value).toBe(false)
      await vi.advanceTimersByTimeAsync(FRAME_INTERVAL * 2)
      expect(scanner.hint.value).toBe(true)
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })
  })

  describe("verrouillage par code lu", () => {
    it("un code sans ambiguïté verrouille dès la première lecture, sans attendre la série", async () => {
      const readText = vi.fn(async () => "OGN 001/298")
      const { scanner } = makeScanner({ readText, grabHashes: () => [FAR] })
      await startScan(scanner)
      expect(readText).toHaveBeenCalled()
      expect(scanner.state.value).toBe("locked")
      expect(scanner.result.value).toMatchObject({ id: "a", method: "code", ambiguous: false })
      expect(scanner.result.value.code).toMatchObject({ number: 1, total: 298 })
      scanner.stop()
    })

    it("étoile illisible : le hash tranche entre les variantes quand l'écart est net", async () => {
      /* Le hash courant est à 0 de « star » et à 12 de « plain » : 12 ≥ CODE_MARGIN. */
      const readText = vi.fn(async () => "UNL 229/219")
      const { scanner } = makeScanner({ readText, grabHashes: () => [H(10)] })
      await startScan(scanner)
      expect(scanner.result.value).toMatchObject({ id: "star", method: "code", ambiguous: false })
      scanner.stop()
    })

    it("étoile illisible et hash indécis : on propose le choix au lieu de deviner", async () => {
      const readText = vi.fn(async () => "UNL 229/219")
      /* À 4 bits de « star » et 8 de « plain » : 4 bits d'écart seulement, on ne tranche pas. */
      const { scanner } = makeScanner({ readText, grabHashes: () => [H(11)] })
      await startScan(scanner)
      expect(scanner.result.value.ambiguous).toBe(true)
      expect(scanner.result.value.method).toBe("code")
      /* Les alternatives sont les AUTRES impressions du même numéro, pas le top hash global. */
      expect(scanner.result.value.alternatives.map((alt) => alt.id)).toEqual(["plain"])
      scanner.stop()
    })

    it("un code dont le total est inconnu de l'index ne verrouille rien", async () => {
      const readText = vi.fn(async () => "XXX 42/777")
      const { scanner } = makeScanner({ readText, grabHashes: () => [FAR] })
      await startScan(scanner)
      await frames(2)
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("moteur qui ne charge pas : dégradation douce immédiate, l'empreinte verrouille quand même", async () => {
      const readText = vi.fn(async () => {
        throw new OcrError("load", "wasm refusé")
      })
      const { scanner } = makeScanner({ readText })
      await startScan(scanner)
      await frames(LOCK_STREAK)
      expect(scanner.ocrAvailable.value).toBe(false)
      expect(scanner.state.value).toBe("locked")
      expect(scanner.result.value.method).toBe("hash")
      /* On n'insiste pas : une seule tentative, pas une par image. */
      expect(readText).toHaveBeenCalledTimes(1)
      scanner.stop()
    })

    it("lecture ratée : on retente, l'OCR n'est abandonné qu'après trois échecs d'affilée", async () => {
      /* Une image floue ou une main devant le code n'est pas une panne du moteur : couper
         l'OCR au premier raté condamnait la voie la plus fiable pour toute la session. */
      const readText = vi.fn(async () => {
        throw new OcrError("recognize", "image illisible")
      })
      const { scanner } = makeScanner({ readText, grabHashes: () => [FAR] })
      await startScan(scanner)
      expect(scanner.ocrAvailable.value).toBe(true)

      await vi.advanceTimersByTimeAsync(OCR_INTERVAL_STEPS * FRAME_INTERVAL)
      expect(readText.mock.calls.length).toBeGreaterThanOrEqual(2)
      expect(scanner.ocrAvailable.value).toBe(true)

      await vi.advanceTimersByTimeAsync(OCR_INTERVAL_STEPS * FRAME_INTERVAL * 2)
      expect(readText).toHaveBeenCalledTimes(OCR_MAX_FAILURES)
      expect(scanner.ocrAvailable.value).toBe(false)
      scanner.stop()
    })

    it("une lecture qui revient après un nouveau scan est ignorée (elle parle de la carte d'avant)", async () => {
      let release
      const readText = vi.fn(() => new Promise((resolve) => (release = resolve)))
      const { scanner, loadCard } = makeScanner({ readText, grabHashes: () => [FAR] })
      await startScan(scanner)
      expect(readText).toHaveBeenCalledTimes(1)

      /* L'utilisateur relance : la lecture en vol porte sur l'image précédente. */
      scanner.start()
      release("OGN 001/298")
      await vi.advanceTimersByTimeAsync(0)
      expect(loadCard).not.toHaveBeenCalled()
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("une lecture périmée n'écrase pas le résultat d'une photo importée", async () => {
      let release
      const readText = vi.fn(() => new Promise((resolve) => (release = resolve)))
      const { scanner } = makeScanner({ readText, grabHashes: () => [FAR] })
      await startScan(scanner)

      /* scanOnce ouvre une nouvelle époque : la lecture caméra qui revient est caduque. */
      await scanner.scanOnce({ hexes: [ZERO] })
      expect(scanner.result.value.id).toBe("a")
      release("OGN 002/298")
      await vi.advanceTimersByTimeAsync(0)
      expect(scanner.result.value.id).toBe("a")
      scanner.stop()
    })
  })

  describe("pause et reprise", () => {
    it("pause suspend la boucle sans perdre l'état, resume la relance", async () => {
      const { scanner } = makeScanner()
      await startScan(scanner)
      scanner.pause()
      expect(scanner.state.value).toBe("paused")
      await frames(10)
      expect(scanner.state.value).toBe("paused") // rien ne tourne
      scanner.resume()
      await vi.advanceTimersByTimeAsync(0)
      await frames(LOCK_STREAK)
      expect(scanner.state.value).toBe("locked")
      scanner.stop()
    })

    it("resume ne redémarre pas une boucle arrêtée ni un résultat affiché", async () => {
      const { scanner } = makeScanner()
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      expect(scanner.state.value).toBe("locked")
      scanner.resume()
      expect(scanner.state.value).toBe("locked")
      scanner.stop()
    })

    it("sans caméra : ni la reprise différée ni resume ne relancent une boucle à vide", async () => {
      /* Desktop (ou photo importée caméra coupée) : grabHashes ne rendra jamais rien.
         Relancer la boucle la ferait tourner toutes les 250 ms jusqu'à la navigation. */
      const grabHashes = vi.fn(() => null)
      const { scanner, addCard } = makeScanner({ canLoop: () => false, grabHashes })
      scanner.autoAdd.value = true
      await scanner.scanOnce({ hexes: [ZERO] })
      expect(addCard).toHaveBeenCalledTimes(1)
      expect(scanner.state.value).toBe("locked")

      /* Aucune reprise n'est armée : le résultat et le toast restent à l'écran. */
      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY * 3)
      expect(scanner.state.value).toBe("locked")
      expect(grabHashes).not.toHaveBeenCalled()

      scanner.pause()
      scanner.resume()
      await frames(10)
      expect(grabHashes).not.toHaveBeenCalled()
    })
  })

  describe("mode ajout automatique", () => {
    it("ajoute au verrouillage, affiche un toast et reprend le scan", async () => {
      const { scanner, addCard } = makeScanner()
      scanner.autoAdd.value = true
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      expect(addCard).toHaveBeenCalledTimes(1)
      expect(scanner.toast.value).toMatchObject({ qty: 1 })
      expect(scanner.toast.value.card.name).toBe("Carte a")
      expect(scanner.state.value).toBe("locked")

      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY)
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("anti-doublon : la carte restée dans le champ n'est pas ré-ajoutée", async () => {
      const { scanner, addCard } = makeScanner()
      scanner.autoAdd.value = true
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY)

      /* La carte est toujours posée sous l'objectif : dix images de plus, aucun ajout. */
      await frames(10)
      expect(addCard).toHaveBeenCalledTimes(1)
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("anti-doublon : la lecture du code ne contourne pas le blocage", async () => {
      /* La voie du code verrouille sans attendre de série : sans garde-fou, la carte posée
         sur la table serait ré-identifiée — donc ré-ajoutée — à chaque cycle d'OCR. */
      const readText = vi.fn(async () => "OGN 001/298")
      const { scanner, addCard } = makeScanner({ readText, grabHashes: () => [ZERO] })
      scanner.autoAdd.value = true
      await startScan(scanner)
      expect(addCard).toHaveBeenCalledTimes(1)
      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY)

      await frames(20) // 5 s de plus : plusieurs cycles d'OCR, la carte n'a pas bougé
      expect(readText.mock.calls.length).toBeGreaterThan(1)
      expect(addCard).toHaveBeenCalledTimes(1)
      scanner.stop()
    })

    it("blocage levé si l'ajout automatique est coupé pendant que la carte est encore là", async () => {
      const { scanner, addCard } = makeScanner()
      scanner.autoAdd.value = true
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY)
      expect(addCard).toHaveBeenCalledTimes(1)

      /* Sans lever le blocage, la carte resterait à jamais inidentifiable en mode manuel. */
      scanner.autoAdd.value = false
      await frames(LOCK_STREAK + 1)
      expect(scanner.state.value).toBe("locked")
      expect(addCard).toHaveBeenCalledTimes(1)
      scanner.stop()
    })

    it("anti-doublon : la même carte redevient ajoutable après être sortie du champ 1 s", async () => {
      let hex = ZERO
      const { scanner, addCard } = makeScanner({ grabHashes: () => [hex] })
      scanner.autoAdd.value = true
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY)
      expect(addCard).toHaveBeenCalledTimes(1)

      /* Champ vide (rien ne ressemble à quoi que ce soit) pendant plus d'une seconde. */
      hex = FAR
      await vi.advanceTimersByTimeAsync(AUTO_RELEASE_MS + FRAME_INTERVAL * 2)
      expect(addCard).toHaveBeenCalledTimes(1)

      /* La même carte revient : elle a disparu entre-temps, elle compte pour un exemplaire de plus. */
      hex = ZERO
      await frames(LOCK_STREAK)
      expect(addCard).toHaveBeenCalledTimes(2)
      scanner.stop()
    })
  })

  describe("abandon en cours de route", () => {
    it("stop() pendant le chargement de la carte annule l'ajout automatique", async () => {
      /* Navigation ou démontage pendant le GET : sans jeton d'époque, le POST d'ajout
         partait après avoir quitté la page et un minuteur de reprise restait orphelin. */
      let release
      const loadCard = vi.fn(() => new Promise((resolve) => (release = resolve)))
      const { scanner, addCard } = makeScanner({ loadCard })
      scanner.autoAdd.value = true
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      expect(loadCard).toHaveBeenCalledTimes(1)

      scanner.stop()
      release({ id: "a", name: "Carte a" })
      await vi.advanceTimersByTimeAsync(0)
      expect(addCard).not.toHaveBeenCalled()

      /* Et aucun minuteur de reprise ne relance la boucle après coup. */
      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY * 2)
      expect(scanner.state.value).toBe("idle")
    })

    it("carte introuvable : l'écran reste utilisable au lieu de rester bloqué sur « locked »", async () => {
      const loadCard = vi.fn(async () => {
        throw new Error("Carte introuvable")
      })
      const { scanner } = makeScanner({ loadCard })
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      /* Les boutons de reprise vivent dans le panneau résultat : le garder ouvert et vide
         figerait la page. */
      expect(scanner.result.value).toBeNull()
      expect(scanner.state.value).toBe("idle")
      expect(scanner.error.value).toBe("Carte introuvable")
    })

    it("onglet caché pendant le toast : la reprise automatique est différée, pas perdue", async () => {
      const { scanner, addCard } = makeScanner()
      scanner.autoAdd.value = true
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      expect(addCard).toHaveBeenCalledTimes(1)
      expect(scanner.state.value).toBe("locked")

      scanner.pause() // onglet caché avant la fin des 1,5 s
      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY * 3)
      expect(scanner.state.value).toBe("locked") // rien ne tourne, mais rien n'est perdu

      scanner.resume()
      expect(scanner.state.value).toBe("scanning")
      scanner.stop()
    })

    it("ajout automatique en échec : la boucle repart quand même et la carte reste bloquée", async () => {
      const addCard = vi.fn(async () => {
        throw new Error("Serveur indisponible")
      })
      const { scanner } = makeScanner({ addCard })
      scanner.autoAdd.value = true
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      expect(scanner.error.value).toBe("Serveur indisponible")

      await vi.advanceTimersByTimeAsync(AUTO_RESUME_DELAY)
      expect(scanner.state.value).toBe("scanning")
      /* La carte est toujours devant l'objectif : on ne réessaie pas en boucle le même échec. */
      await frames(10)
      expect(addCard).toHaveBeenCalledTimes(1)
      scanner.stop()
    })

    it("une pause longue ne déclenche pas le conseil dès la reprise", async () => {
      const { scanner } = makeScanner({ grabHashes: () => [FAR] })
      scanner.setIndex([{ id: "a", rid: "ogn-001-298", h: ZERO }])
      await startScan(scanner)
      scanner.pause()
      await vi.advanceTimersByTimeAsync(HINT_DELAY * 2) // onglet laissé de côté longtemps
      scanner.resume()
      await vi.advanceTimersByTimeAsync(0)
      expect(scanner.hint.value).toBe(false)
      scanner.stop()
    })
  })

  describe("alternatives et passe unique", () => {
    it("choisir une alternative la promeut en résultat et rétrograde la précédente", async () => {
      const { scanner, loadCard } = makeScanner()
      await startScan(scanner)
      await frames(LOCK_STREAK - 1)
      const alternative = scanner.result.value.alternatives[0]

      await scanner.pickAlternative(alternative)
      expect(scanner.result.value.id).toBe(alternative.id)
      expect(scanner.result.value.method).toBe("manual")
      expect(scanner.result.value.card.id).toBe(alternative.id)
      expect(scanner.result.value.alternatives[0].id).toBe("a")
      expect(loadCard).toHaveBeenCalledTimes(2)
      scanner.stop()
    })

    it("photo importée : un seul cliché suffit, pas de série à confirmer", async () => {
      const { scanner } = makeScanner()
      await scanner.scanOnce({ hexes: [ZERO] })
      expect(scanner.state.value).toBe("locked")
      expect(scanner.result.value).toMatchObject({ id: "a", method: "hash" })
    })

    it("photo importée : le code lu prime sur la ressemblance", async () => {
      const readText = vi.fn(async () => "OGN 002/298")
      const { scanner } = makeScanner({ readText })
      await scanner.scanOnce({ hexes: [ZERO], codeImage: {} })
      expect(scanner.result.value).toMatchObject({ id: "b", method: "code" })
    })

    it("photo importée trop éloignée de tout : aucun résultat plausible", async () => {
      const { scanner } = makeScanner()
      await scanner.scanOnce({ hexes: [FAR] })
      expect(scanner.noMatch.value).toBe(true)
      expect(scanner.result.value).toBeNull()
    })

    it("reset vide le résultat sans relancer de boucle", async () => {
      const { scanner } = makeScanner()
      await scanner.scanOnce({ hexes: [ZERO] })
      scanner.reset()
      expect(scanner.result.value).toBeNull()
      expect(scanner.state.value).toBe("idle")
      await frames(5)
      expect(scanner.state.value).toBe("idle")
    })
  })
})
