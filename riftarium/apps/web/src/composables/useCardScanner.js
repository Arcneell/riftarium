/* Machine à états du scanner de cartes : idle → scanning → locked, plus « paused »
   (onglet caché, navigation). Aucune dépendance au DOM : la capture d'image, la lecture
   OCR, le chargement de carte et l'ajout à la collection sont injectés — c'est ce qui rend
   la logique de verrouillage testable sans caméra ni canvas.

   Deux voies d'identification tournent en parallèle :
   - le hash perceptuel, à chaque image (~4 fois/s), qui exige une confirmation dans le temps ;
   - la lecture du code imprimé, plus lente mais exacte, qui verrouille immédiatement.
   La première dit « ça ressemble à », la seconde dit « c'est ». */

import { computed, ref } from "vue"
import { bestMatchesPacked, packIndex } from "../scanHash.js"
import { collectorTotals, isOcrBusy, matchByCode, parseCollectorCode } from "../scanOcr.js"

/* Cadence de la boucle de hash : 250 ms laisse au navigateur le temps de composer l'image
   suivante entre deux analyses, et 3 images consécutives (le critère de verrouillage) ne
   coûtent que 0,75 s — assez rapide pour ne pas se sentir comme un déclencheur. */
export const FRAME_INTERVAL = 250

/* L'OCR coûte 200 à 600 ms de worker : plus souvent qu'à 1,2 s d'intervalle, il monopolise
   un cœur et fait chuter la cadence de la boucle de hash sans rien identifier de plus. */
export const OCR_INTERVAL = 1200

/* Trois images de suite sur la même carte : un reflet ou un flou de bougé n'affecte qu'une
   image, la stabilité dans le temps est le seul signal fiable qu'on tient vraiment la carte. */
export const LOCK_STREAK = 3

/* 120/512 bits d'écart : au-delà, l'expérience de l'ancien scan montre que le classement
   n'est plus qu'un ordre entre inconnues (l'ancien seuil « pas de résultat » était à 200,
   mais lui n'engageait rien puisque l'utilisateur confirmait ensuite). */
export const LOCK_MAX_DISTANCE = 120

/* Écart minimal avec la meilleure carte d'un AUTRE riftbound_id : 12 bits sur 512, soit
   ~2,3 %. En dessous, les deux cartes se valent et verrouiller serait un tirage au sort.
   Le regroupement par riftbound_id est essentiel : deux variantes d'une même carte ont des
   empreintes très proches et se voleraient l'écart. */
export const LOCK_MARGIN = 12

/* Même idée quand le code lu désigne plusieurs variantes (étoile illisible) : le seuil est
   plus bas car on sait déjà QUELLE carte c'est, il ne reste qu'à choisir l'impression. */
export const CODE_MARGIN = 10

/* Photo importée : un seul cliché, pas de confirmation possible dans le temps. On accepte
   donc plus large (l'utilisateur voit le résultat et peut le corriger) — c'est l'ancien
   seuil « aucun résultat plausible ». */
export const NO_MATCH_DISTANCE = 200

/* Sans verrouillage au bout de 8 s, le problème n'est plus la patience : c'est la lumière,
   la distance ou le flou. On conseille, sans arrêter la boucle. */
export const HINT_DELAY = 8000

/* Mode automatique : 1,5 s d'affichage du toast avant de reprendre, le temps de lire le nom
   et le prix et de glisser la carte suivante. */
export const AUTO_RESUME_DELAY = 1500

/* Anti-doublon : une carte posée sur la table reste dans le champ et serait ajoutée à
   chaque tour. On la bloque jusqu'à ce qu'elle ait quitté le cadre, c'est-à-dire 1 s sans
   être la meilleure correspondance — plus court, un simple flou de bougé la débloquerait. */
export const AUTO_RELEASE_MS = 1000

/* Nombre d'alternatives proposées derrière « Ce n'est pas la bonne carte ? ». */
export const ALTERNATIVES = 3

/* Une reconnaissance ratée n'est pas une panne : image floue, carte de travers, main devant
   le code. On ne bascule en « OCR indisponible » qu'après 3 échecs d'affilée — un échec de
   CHARGEMENT du moteur, lui, est définitif tout de suite (rien ne le fera marcher). */
export const OCR_MAX_FAILURES = 3

export function useCardScanner({
  loadCard,
  addCard = null,
  grabHashes,
  grabCodeImage,
  readText = null,
  vibrate = null,
  /* Y a-t-il une source d'images continue ? Sur desktop (ou après un import de photo,
     caméra coupée), grabHashes ne rendra jamais rien : relancer la boucle ferait tourner un
     tick toutes les 250 ms indéfiniment, sans jamais pouvoir verrouiller. La vue répond
     « caméra allumée ? ». */
  canLoop = () => true,
  now = () => Date.now()
} = {}) {
  /* idle : rien ne tourne. scanning : boucle active. locked : résultat affiché.
     paused : boucle suspendue (onglet caché) mais reprise possible sans reset. */
  const state = ref("idle")
  const result = ref(null)
  const noMatch = ref(false)
  const hint = ref(false)
  const error = ref("")
  const autoAdd = ref(false)
  const toast = ref(null)
  /* Progression du moteur OCR (0→1) tant qu'il se charge ; null une fois prêt ou abandonné. */
  const ocrProgress = ref(null)
  const ocrAvailable = ref(Boolean(readText))
  const lastCode = ref(null)

  let items = []
  let packed = packIndex([])
  let totals = new Set()

  let timer = null
  let resumeTimer = null
  let lastHexes = null
  let lastMatches = []
  let streakRid = ""
  let streak = 0
  /* -Infinity : la première lecture de code part dès la première image, sans attendre 1,2 s
     (c'est la voie la plus sûre, autant la tenter tout de suite). */
  let lastOcrAt = -Infinity
  let scanStartedAt = 0
  let blockedRid = ""
  let blockedSeenAt = 0
  /* Jeton d'époque : incrémenté par start / stop / reset / scanOnce. Toute suite asynchrone
     (chargement de carte, résultat d'OCR) capture l'époque en entrant et abandonne si elle a
     changé — sans quoi un stop() pendant un await laisserait passer un POST d'ajout après la
     navigation, ou une lecture lancée sur la carte précédente verrouillerait la suivante. */
  let epoch = 0
  /* Reprise automatique mise en attente parce que l'onglet a été caché pendant le toast :
     sans cela, pause() tuait le minuteur et l'état restait « locked » à jamais. */
  let autoResumePending = false
  let ocrFailures = 0

  /** Alimente le scanner avec l'index /api/cards/hashes (une fois, au montage). */
  function setIndex(nextItems) {
    items = nextItems || []
    packed = packIndex(items)
    totals = collectorTotals(items)
  }

  const hashedCount = computed(() => packed.count)

  function clearLoopTimer() {
    if (timer) clearTimeout(timer)
    timer = null
  }

  function clearTimers() {
    clearLoopTimer()
    if (resumeTimer) clearTimeout(resumeTimer)
    resumeTimer = null
    autoResumePending = false
  }

  function resetTracking() {
    /* Nouvelle époque : tout ce qui était en vol devient périmé. */
    epoch += 1
    lastHexes = null
    lastMatches = []
    streakRid = ""
    streak = 0
    lastOcrAt = -Infinity
    lastCode.value = null
  }

  /** Vide le résultat affiché sans rien relancer (utile quand il n'y a pas de caméra). */
  function reset() {
    clearTimers()
    resetTracking()
    result.value = null
    noMatch.value = false
    hint.value = false
    error.value = ""
    toast.value = null
    state.value = "idle"
  }

  /** Démarre (ou relance) la boucle : c'est le seul point d'entrée du scan continu. */
  function start() {
    reset()
    state.value = "scanning"
    scanStartedAt = now()
    schedule(0)
  }

  function schedule(delay) {
    timer = setTimeout(tick, delay)
  }

  /** Suspend sans perdre le résultat courant (onglet caché). N'incrémente PAS l'époque :
      une pause n'invalide rien, elle diffère. */
  function pause() {
    clearLoopTimer()
    if (resumeTimer) {
      /* Onglet caché pendant le toast du mode automatique : on mémorise la reprise au lieu
         de la perdre, sinon l'état resterait « locked » indéfiniment. */
      clearTimeout(resumeTimer)
      resumeTimer = null
      autoResumePending = true
    }
    if (state.value === "scanning") state.value = "paused"
  }

  /** Reprend après une pause : relance la boucle, ou honore la reprise automatique différée. */
  function resume() {
    if (autoResumePending) {
      autoResumePending = false
      /* Sans source d'images, il n'y a pas de boucle à reprendre : le résultat reste
         affiché et l'utilisateur repart par un nouvel import. */
      if (canLoop()) start()
      return
    }
    if (state.value !== "paused") return
    if (!canLoop()) {
      /* Pause tombée pendant une passe unique alors qu'aucune caméra ne tourne : reprendre
         la boucle l'aurait fait tourner à vide jusqu'à la navigation. */
      state.value = "idle"
      return
    }
    state.value = "scanning"
    /* Le compte à rebours du conseil repart de zéro : une pause longue ne doit pas faire
       apparaître « rapprochez-vous » dès la première image. */
    scanStartedAt = now()
    schedule(0)
  }

  /** Arrêt complet (démontage, navigation) : tout ce qui est en vol devient périmé. */
  function stop() {
    clearTimers()
    epoch += 1
    state.value = "idle"
  }

  /* ---------------- Boucle de hash ---------------- */

  function tick() {
    if (state.value !== "scanning") return
    const startedAt = now()
    let hexes = null
    try {
      hexes = grabHashes?.()
    } catch {
      /* Image pas encore disponible (vidéo sans dimensions au premier tour) : on repassera. */
    }
    if (hexes?.length) evaluateHashes(hexes)
    if (state.value === "scanning") {
      if (!hint.value && now() - scanStartedAt >= HINT_DELAY) hint.value = true
      runOcr()
      schedule(Math.max(0, FRAME_INTERVAL - (now() - startedAt)))
    }
  }

  function evaluateHashes(hexes) {
    lastHexes = hexes
    lastMatches = bestMatchesPacked(hexes, packed, ALTERNATIVES + 1, { groupBy: "rid" })
    const top = lastMatches[0]
    if (!top) return

    if (blockedRid) {
      if (!autoAdd.value) {
        blockedRid = "" // mode automatique coupé entre-temps : plus rien à bloquer
      } else if (top.rid === blockedRid) {
        /* La carte déjà ajoutée est toujours dans le cadre : on la garde bloquée. */
        blockedSeenAt = now()
        streak = 0
        streakRid = ""
        return
      } else if (now() - blockedSeenAt >= AUTO_RELEASE_MS) {
        blockedRid = "" // elle a quitté le champ : elle redevient un exemplaire à part entière
      }
    }

    if (top.rid === streakRid) streak += 1
    else {
      streakRid = top.rid
      streak = 1
    }
    if (streak < LOCK_STREAK || top.distance > LOCK_MAX_DISTANCE) return
    const second = lastMatches[1]
    if (second) {
      if (second.distance - top.distance < LOCK_MARGIN) return
    } else if (packed.count > 1) {
      /* Pas de deuxième groupe alors que l'index en contient plusieurs : le classement est
         incomplet (index dégradé, rid manquants → tout regroupé sous une seule clé). Sans
         second candidat, la marge n'est pas vérifiable : on refuse plutôt que de verrouiller
         à l'aveugle sur ce qui pourrait être n'importe quelle carte. */
      return
    }
    lock({ item: top, method: "hash", distance: top.distance })
  }

  /* ---------------- Lecture du code ---------------- */

  /** Distances de hash des cartes fournies, meilleure d'abord ; distance null si la carte
      n'a pas encore d'empreinte côté serveur (elle reste un candidat valable via son code). */
  function rankByHash(candidates) {
    if (!lastHexes) return candidates.map((item) => ({ ...item, distance: null }))
    const ranked = bestMatchesPacked(lastHexes, packIndex(candidates), candidates.length)
    const seen = new Set(ranked.map((match) => match.id))
    return [...ranked, ...candidates.filter((item) => !seen.has(item.id)).map((item) => ({ ...item, distance: null }))]
  }

  /** Verrouille sur un code lu. Renvoie false si le code ne désigne aucune carte connue. */
  function lockFromCode(code) {
    const { items: candidates, rids } = matchByCode(code, items)
    if (!candidates.length) return false
    const ranked = rankByHash(candidates)
    const best = ranked[0]
    if (rids.length === 1) {
      /* Un seul riftbound_id : le code suffit, c'est une certitude. */
      lock({ item: best, method: "code", code, distance: best.distance })
      return true
    }
    /* Plusieurs impressions pour ce numéro (étoile illisible, art alternatif) : l'empreinte
       tranche si elle est franche, sinon on affiche le choix plutôt que de deviner. */
    const runnerUp = ranked.find((match) => match.rid !== best.rid)
    const decided =
      best.distance !== null &&
      (!runnerUp || runnerUp.distance === null || runnerUp.distance - best.distance >= CODE_MARGIN)
    lock({
      item: best,
      method: "code",
      code,
      distance: best.distance,
      ambiguous: !decided,
      variants: decided ? null : ranked
    })
    return true
  }

  /** Trie un échec d'OCR : moteur mort (définitif) vs lecture ratée (on retente). */
  function noteOcrFailure(ocrError) {
    if (ocrError?.stage === "load") {
      /* Moteur indisponible (wasm refusé, réseau) : dégradation douce, le scan par
         empreinte suffit. On n'y revient pas pour ne pas boucler sur l'erreur. */
      ocrAvailable.value = false
      ocrProgress.value = null
      return
    }
    ocrFailures += 1
    if (ocrFailures >= OCR_MAX_FAILURES) {
      ocrAvailable.value = false
      ocrProgress.value = null
    }
  }

  function runOcr() {
    if (!readText || !ocrAvailable.value || isOcrBusy() || now() - lastOcrAt < OCR_INTERVAL) return
    lastOcrAt = now()
    let image
    try {
      image = grabCodeImage?.()
    } catch {
      return
    }
    if (!image) return
    const mine = epoch
    /* Volontairement non attendu : la boucle de hash continue pendant la reconnaissance.
       D'où l'époque : au retour, l'utilisateur a pu importer une photo ou relancer un scan,
       et ce texte-là parle d'une carte qui n'est plus devant l'objectif. */
    readText(image)
      .then((text) => {
        if (mine !== epoch || text === null || state.value !== "scanning") return
        ocrFailures = 0
        const code = parseCollectorCode(text, totals)
        if (!code) return
        lastCode.value = code
        lockFromCode(code)
      })
      .catch((ocrError) => {
        if (mine !== epoch) return // abandon volontaire : ce n'est pas une panne
        noteOcrFailure(ocrError)
      })
  }

  /** Branchée sur le logger de tesseract.js : alimente le HUD pendant le téléchargement. */
  function trackOcrProgress(message) {
    if (!message?.status) return
    if (message.status === "recognizing text") return // pas la peine d'afficher chaque image
    ocrProgress.value = message.progress >= 1 ? null : message.progress
  }

  /* ---------------- Verrouillage ---------------- */

  async function lock({ item, method, code = null, distance = null, ambiguous = false, variants = null }) {
    /* Point de passage unique des deux voies : le blocage anti-doublon vaut aussi pour la
       lecture du code, qui identifierait sinon la carte posée sur la table toutes les 1,2 s. */
    if (blockedRid && item.rid === blockedRid) return
    clearLoopTimer()
    state.value = "locked"
    hint.value = false
    noMatch.value = false
    vibrate?.(30)

    /* Les alternatives viennent des variantes du code quand il y a doute, sinon du
       classement par ressemblance. Aucune carte n'est chargée ici : la vue ne les demande
       que si l'utilisateur déplie « Ce n'est pas la bonne carte ? ». */
    const pool = variants || lastMatches
    const alternatives = pool.filter((match) => match.id !== item.id).slice(0, ALTERNATIVES)
    result.value = { id: item.id, rid: item.rid, method, code, distance, ambiguous, alternatives, card: null }

    const mine = epoch
    let card
    try {
      card = await loadCard(item.id)
    } catch (loadError) {
      if (mine !== epoch) return
      /* Sans résultat exploitable, garder l'état « locked » figerait l'écran : le panneau
         n'a rien à montrer et ses boutons de reprise vivent dedans. On revient donc en
         « idle » avec l'erreur affichée, l'import et le bouton de reprise restent atteignables. */
      result.value = null
      state.value = "idle"
      error.value = loadError?.message || "Carte indisponible."
      return
    }
    /* stop() / start() / scanOnce() pendant le chargement : ce résultat est périmé, et
       surtout il ne doit pas déclencher un ajout automatique après la navigation. */
    if (mine !== epoch) return
    if (result.value?.id === item.id) result.value = { ...result.value, card }
    if (autoAdd.value && addCard) await runAutoAdd(mine)
  }

  async function runAutoAdd(mine) {
    const locked = result.value
    if (!locked?.card) return
    /* Le blocage est posé AVANT l'appel : même si l'ajout échoue, la carte est toujours sous
       l'objectif et re-tenter à chaque image enchaînerait les erreurs identiques. */
    blockedRid = locked.rid
    blockedSeenAt = now()
    try {
      const added = await addCard(locked.card)
      if (mine !== epoch) return // parti ailleurs pendant le POST : ne pas toucher à l'UI
      toast.value = { card: locked.card, qty: added?.qty ?? 1, at: now() }
    } catch (addError) {
      if (mine !== epoch) return
      error.value = addError?.message || "Ajout impossible."
    }
    /* Reprise armée dans les deux cas : un ajout raté ne doit pas figer le mode automatique.
       Mais seulement s'il y a une boucle à reprendre : sans caméra (import de photo), on
       laisse le résultat et le toast à l'écran. */
    if (!canLoop()) return
    resumeTimer = setTimeout(() => {
      resumeTimer = null
      if (state.value === "locked") start()
    }, AUTO_RESUME_DELAY)
  }

  /** L'utilisateur choisit une alternative : elle devient le résultat, sans relancer le scan. */
  async function pickAlternative(match) {
    const previous = result.value
    result.value = {
      id: match.id,
      rid: match.rid,
      method: "manual",
      code: previous?.code || null,
      distance: match.distance,
      ambiguous: false,
      alternatives: [
        ...(previous ? [{ id: previous.id, rid: previous.rid, distance: previous.distance }] : []),
        ...(previous?.alternatives || []).filter((alt) => alt.id !== match.id)
      ].slice(0, ALTERNATIVES),
      card: null
    }
    const mine = epoch
    try {
      const card = await loadCard(match.id)
      if (mine === epoch && result.value?.id === match.id) result.value = { ...result.value, card }
    } catch (loadError) {
      if (mine !== epoch) return
      error.value = loadError?.message || "Carte indisponible."
    }
  }

  /* ---------------- Passe unique (photo importée) ---------------- */

  /** Analyse une capture unique : même pipeline, mais sans exigence de stabilité — le
      cliché est volontaire et l'utilisateur voit tout de suite ce qui a été reconnu. */
  async function scanOnce({ hexes, codeImage }) {
    clearTimers()
    resetTracking()
    /* Import volontaire d'une photo : l'intention est explicite, le blocage anti-doublon
       hérité du mode automatique n'a pas à s'y appliquer. */
    blockedRid = ""
    error.value = ""
    noMatch.value = false
    result.value = null
    state.value = "scanning"

    if (hexes?.length) {
      lastHexes = hexes
      lastMatches = bestMatchesPacked(hexes, packed, ALTERNATIVES + 1, { groupBy: "rid" })
    }

    const mine = epoch
    if (readText && ocrAvailable.value && codeImage) {
      try {
        const text = await readText(codeImage)
        if (mine !== epoch) return // un autre scan a démarré pendant la lecture
        const code = text === null ? null : parseCollectorCode(text, totals)
        if (code) {
          ocrFailures = 0
          lastCode.value = code
          if (lockFromCode(code)) return
        }
      } catch (ocrError) {
        if (mine !== epoch) return
        noteOcrFailure(ocrError)
      }
    }

    const top = lastMatches[0]
    if (!top || top.distance > NO_MATCH_DISTANCE) {
      state.value = "idle"
      noMatch.value = true
      return
    }
    await lock({ item: top, method: "hash", distance: top.distance })
  }

  return {
    state,
    result,
    noMatch,
    hint,
    error,
    autoAdd,
    toast,
    ocrProgress,
    ocrAvailable,
    lastCode,
    hashedCount,
    setIndex,
    start,
    stop,
    pause,
    resume,
    scanOnce,
    reset,
    pickAlternative,
    trackOcrProgress
  }
}
