<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { onBeforeRouteLeave } from "vue-router"
import { api, cardThumb, session, CONDITIONS, LANGS, RARITIES, TYPES } from "../api.js"
import { PRICE_NOTE, cardmarketUrl, formatEur } from "../prices.js"
import { codeImageFromVideoFrame, hashesFromVideoFrame, scanFile } from "../scanCapture.js"
import { cancelOcr, ensureOcrWorker, formatCode, readCodeText, terminateOcrWorker } from "../scanOcr.js"
import { useCardScanner } from "../composables/useCardScanner.js"

/* Contrat serveur : dHash 16×16 H+V de la fenêtre d'illustration (indépendante de la langue).
   Un autre algo (vieux cache, serveur pas à jour) rendrait le classement absurde : on refuse. */
const EXPECTED_ALGO = "dhash16-hv-art"

/* Version du format de l'index attendue par ce bundle : « rid » sur chaque item et les
   cartes sans empreinte incluses. Elle voyage dans l'URL pour contourner le cache navigateur
   (max-age=3600) — sans elle, un onglet rouvert après déploiement rejouerait l'ancien payload. */
const INDEX_VERSION = "2"

/* Index du scan (empreintes + codes de toutes les cartes), chargé une fois au montage.
   `total` = cartes connues (voie code), `hashed` = cartes avec empreinte (voie ressemblance). */
const index = reactive({ loading: true, error: "", total: 0, hashed: 0 })

const video = ref(null)
const frame = ref(null)
/* idle → starting → on, ou off (refusé, absent, desktop) avec explication éventuelle. */
const camera = reactive({ status: "idle", error: "" })
let stream = null
const torch = reactive({ available: false, on: false })

const added = reactive({}) // id → nombre d'exemplaires ajoutés pendant la session
const adding = ref(false)
const importing = ref(false)
const showAlternatives = ref(false)
const loadingAlternatives = ref(false)
const alternativeCards = reactive({}) // id → carte, chargées seulement si on déplie
/* Le <h2> du résultat reçoit le focus au verrouillage : sans cela, un lecteur d'écran ne
   signale rien quand le panneau apparaît sous la scène caméra. */
const resultHeading = ref(null)

/* Langue, état et mode d'ajout appliqués aux ajouts — mémorisés entre les sessions de scan
   (on scanne généralement des cartes de la même langue à la chaîne). */
const SCAN_PREFS_KEY = "riftarium.scanPrefs"
function loadScanPrefs() {
  try {
    const raw = JSON.parse(localStorage.getItem(SCAN_PREFS_KEY) || "{}")
    return {
      lang: raw.lang in LANGS ? raw.lang : "FR",
      condition: raw.condition in CONDITIONS ? raw.condition : "NM",
      auto: raw.auto === true
    }
  } catch {
    return { lang: "FR", condition: "NM", auto: false }
  }
}
const prefs = loadScanPrefs()
const scanLang = ref(prefs.lang)
const scanCondition = ref(prefs.condition)
/* Quantité ajoutée par confirmation (non persistée : repart à 1 à chaque session). */
const scanQty = ref(1)
function rememberScanPrefs() {
  try {
    localStorage.setItem(
      SCAN_PREFS_KEY,
      JSON.stringify({ lang: scanLang.value, condition: scanCondition.value, auto: autoAdd.value })
    )
  } catch {
    /* stockage indisponible (navigation privée) : préférences non persistées */
  }
}

function normalizedQty() {
  return Math.min(99, Math.max(1, Math.round(Number(scanQty.value) || 1)))
}

/* Rectangle de la carte dans les coordonnées intrinsèques de la vidéo. Le flux couvre le
   cadre en object-fit: cover : on remonte du rectangle affiché vers la source pour que le
   balayage porte sur la zone que l'utilisateur voit dans la silhouette. */
function videoCardRect() {
  const element = video.value
  if (!element?.videoWidth || !frame.value) return null
  const videoRect = element.getBoundingClientRect()
  const frameRect = frame.value.getBoundingClientRect()
  if (!videoRect.width || !frameRect.width) return null
  const scale = Math.max(element.videoWidth / videoRect.width, element.videoHeight / videoRect.height)
  return {
    sx: (element.videoWidth - videoRect.width * scale) / 2 + (frameRect.left - videoRect.left) * scale,
    sy: (element.videoHeight - videoRect.height * scale) / 2 + (frameRect.top - videoRect.top) * scale,
    sw: frameRect.width * scale,
    sh: frameRect.height * scale
  }
}

const scanner = useCardScanner({
  loadCard: (id) => api(`/api/cards/${id}`),
  addCard: async (card) => {
    const qty = normalizedQty()
    await api(`/api/collection/${card.id}/entries`, {
      method: "POST",
      body: { qty, condition: scanCondition.value, lang: scanLang.value }
    })
    added[card.id] = (added[card.id] || 0) + qty
    return { qty }
  },
  grabHashes: () => {
    const rect = videoCardRect()
    return rect ? hashesFromVideoFrame(video.value, rect) : null
  },
  grabCodeImage: () => {
    const rect = videoCardRect()
    return rect ? codeImageFromVideoFrame(video.value, rect) : null
  },
  /* readCodeText renvoie null si un OCR est déjà en cours : la boucle saute son tour. */
  readText: (image) => readCodeText(image),
  vibrate: (ms) => navigator.vibrate?.(ms)
})
/* Déstructuré pour que le template lise `result`, `autoAdd`… directement (les refs de premier
   niveau y sont déballées automatiquement, pas celles d'un objet). */
const { state, result, noMatch, hint, autoAdd, toast, ocrProgress, ocrAvailable, lastCode } = scanner
const scanError = scanner.error
autoAdd.value = prefs.auto && Boolean(session.token)

const card = computed(() => result.value?.card || null)
const priceMain = computed(() => formatEur(card.value?.price_eur))
/* Cartes n'existant qu'en foil : le prix principal EST le prix foil, inutile de doubler. */
const priceFoil = computed(() =>
  card.value?.price_foil_eur !== card.value?.price_eur ? formatEur(card.value?.price_foil_eur) : null
)

/** Comment la carte a été identifiée : l'utilisateur doit pouvoir juger de la confiance. */
const methodLabel = computed(() => {
  const found = result.value
  if (!found) return ""
  if (found.method === "manual") return "Choisie dans les alternatives"
  if (found.method === "code") return `Code lu : ${formatCode(found.code)}`
  return `Ressemblance visuelle, écart ${found.distance}/512`
})

/** Texte du HUD superposé à la caméra (role="status"). */
const hudText = computed(() => {
  if (state.value === "locked") return "Carte identifiée"
  if (state.value === "paused") return "Scan en pause"
  if (ocrProgress.value !== null) return `Moteur de lecture : ${Math.round(ocrProgress.value * 100)} %`
  if (lastCode.value) return `Code lu : ${formatCode(lastCode.value)}`
  if (hint.value) return "Rien de sûr : rapprochez-vous, mettez plus de lumière et évitez les reflets."
  return "Recherche…"
})

/* Le panneau résultat apparaît SOUS la scène caméra, hors du champ de lecture : sans y
   amener le focus, un lecteur d'écran n'annonce rien au verrouillage et la navigation
   clavier reste bloquée en haut de page. */
watch(
  () => result.value?.id,
  async (id) => {
    if (!id) return
    await nextTick()
    resultHeading.value?.focus?.()
  }
)

function explainCameraError(error) {
  if (error?.name === "NotAllowedError" || error?.name === "SecurityError") {
    return "Accès à la caméra refusé. Autorisez-le dans les réglages du navigateur, ou importez une photo."
  }
  if (error?.name === "NotFoundError" || error?.name === "OverconstrainedError") {
    return "Aucune caméra détectée sur cet appareil."
  }
  return "Caméra indisponible. Importez une photo de la carte."
}

async function startCamera() {
  if (!navigator.mediaDevices?.getUserMedia) {
    camera.status = "off" // desktop sans caméra : le fallback fichier suffit, pas d'erreur à afficher
    return
  }
  camera.status = "starting"
  camera.error = ""
  try {
    /* facingMode en `ideal` et non `exact` : sur un portable sans caméra arrière, `exact`
       ferait échouer getUserMedia au lieu de retomber sur la webcam. 1920×1080 demandé
       parce que le code collector ne fait que ~1,8 % de la hauteur de la carte : en 640×480
       il n'y a physiquement pas assez de pixels pour le lire. */
    stream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: { ideal: "environment" },
        width: { ideal: 1920 },
        height: { ideal: 1080 }
      }
    })
    camera.status = "on"
    await nextTick() // le <video> n'est rendu qu'une fois le flux obtenu
    if (!video.value) return stopCamera()
    video.value.srcObject = stream
    await video.value.play?.()?.catch?.(() => {})
    const track = stream.getVideoTracks?.()[0]
    torch.available = Boolean(track?.getCapabilities?.().torch)
    torch.on = false
    scanner.start()
  } catch (error) {
    camera.status = "off"
    camera.error = explainCameraError(error)
  }
}

/* Le moteur pèse plusieurs Mo au premier scan : on le télécharge dès le montage, caméra ou
   pas — sur desktop la voie normale est l'import de photo, et attendre le premier import
   pour commencer le téléchargement donnait plusieurs secondes de blocage sans explication. */
function warmOcr() {
  ensureOcrWorker(scanner.trackOcrProgress).catch(() => {
    ocrAvailable.value = false
  })
}

function stopCamera() {
  for (const track of stream?.getTracks() || []) track.stop()
  stream = null
  torch.available = false
  torch.on = false
  if (video.value) video.value.srcObject = null
  if (camera.status === "on" || camera.status === "starting") camera.status = "off"
}

async function toggleTorch() {
  const track = stream?.getVideoTracks?.()[0]
  if (!track) return
  try {
    await track.applyConstraints({ advanced: [{ torch: !torch.on }] })
    torch.on = !torch.on
  } catch {
    torch.available = false // la lampe est refusée par cet appareil : on retire le bouton
  }
}

/* Onglet caché : on suspend l'analyse (CPU) mais on GARDE le flux caméra ouvert — le
   couper ferait clignoter la LED et imposerait une reprise de plusieurs secondes (voire une
   redemande de permission sur certains navigateurs) à chaque va-et-vient entre onglets. */
function onVisibilityChange() {
  if (document.hidden) scanner.pause()
  else scanner.resume()
}

/** Coupe boucle, caméra et worker OCR. Attendue : un terminate encore en vol pendant qu'on
    revient sur /scan relancerait un moteur qu'on est en train de tuer. */
async function shutdown() {
  scanner.stop()
  stopCamera()
  document.removeEventListener("visibilitychange", onVisibilityChange)
  /* Un worker wasm oublié garde des dizaines de Mo et continue de tourner. */
  await terminateOcrWorker()
}

/* Coupe caméra, boucle et worker OCR à la navigation comme au démontage. */
onBeforeRouteLeave(async () => {
  await shutdown()
})
onBeforeUnmount(() => {
  shutdown()
})

onMounted(async () => {
  document.addEventListener("visibilitychange", onVisibilityChange)
  try {
    const data = await api(`/api/cards/hashes?v=${INDEX_VERSION}`)
    const items = data?.items || []
    const hashed = items.filter((item) => item.h).length
    const outdated = `Index des cartes incompatible avec cette version du site. Rechargez la page ; si le problème persiste, le serveur n'est pas encore à jour.`
    if (hashed && data.algo !== EXPECTED_ALGO) {
      index.error = `Empreintes incompatibles avec cette version du site (« ${data.algo || "?"} » au lieu de « ${EXPECTED_ALGO} »). Rechargez la page ; si le problème persiste, le serveur n'est pas encore à jour.`
    } else if (items.length && items.some((item) => !item.rid)) {
      /* Payload d'avant l'ajout de `rid` (cache Redis ou navigateur d'une version antérieure).
         Le laisser passer serait pire qu'une erreur : plus aucun code lisible, et un
         regroupement par variante qui met toutes les cartes dans le même sac — donc un
         verrouillage sans marge vérifiable sur n'importe quelle carte. */
      index.error = outdated
    } else {
      scanner.setIndex(items)
      index.total = items.length
      index.hashed = hashed
    }
  } catch (error) {
    index.error = error.message
  } finally {
    index.loading = false
  }
  if (!index.total) return
  warmOcr()
  /* Sans empreinte, la caméra n'aurait que la voie code : trop peu fiable pour une boucle
     automatique. L'import de photo, lui, reste proposé. */
  if (index.hashed) startCamera()
})

async function onFileChange(event) {
  const file = event.target.files?.[0]
  event.target.value = "" // permet de réimporter le même fichier
  if (!file || importing.value) return // deux imports en parallèle se voleraient le résultat
  importing.value = true
  scanner.stop()
  /* La lecture lancée par la boucle caméra tient encore la place (un seul OCR à la fois) :
     sans l'annuler, readCodeText renverrait null pour la photo — son code ne serait jamais
     lu — et la lecture caméra reviendrait verrouiller par-dessus le résultat de la photo. */
  cancelOcr()
  showAlternatives.value = false
  try {
    const { hexes, codeImage } = await scanFile(file)
    await scanner.scanOnce({ hexes, codeImage })
  } catch {
    scanError.value = "Photo illisible. Réessayez avec la carte bien à plat et bien éclairée."
  } finally {
    importing.value = false
  }
}

async function addToCollection() {
  if (adding.value || !card.value) return
  adding.value = true
  scanError.value = ""
  try {
    const qty = normalizedQty()
    await api(`/api/collection/${card.value.id}/entries`, {
      method: "POST",
      body: { qty, condition: scanCondition.value, lang: scanLang.value }
    })
    rememberScanPrefs()
    added[card.value.id] = (added[card.value.id] || 0) + qty
  } catch (error) {
    scanError.value = error.message
  } finally {
    adding.value = false
  }
}

/** Déplie les alternatives et ne charge leurs visuels qu'à ce moment (jamais dans la boucle).
    Verrou `loadingAlternatives` : la garde `showAlternatives` est lue AVANT les await, des
    clics répétés relanceraient sinon les mêmes GET en parallèle. */
async function toggleAlternatives() {
  if (loadingAlternatives.value) return
  showAlternatives.value = !showAlternatives.value
  if (!showAlternatives.value) return
  loadingAlternatives.value = true
  try {
    for (const alternative of result.value?.alternatives || []) {
      if (alternativeCards[alternative.id]) continue
      try {
        alternativeCards[alternative.id] = await api(`/api/cards/${alternative.id}`)
      } catch {
        /* Candidate indisponible : les autres restent proposées. */
      }
    }
  } finally {
    loadingAlternatives.value = false
  }
}

async function pickAlternative(alternative) {
  showAlternatives.value = false
  await scanner.pickAlternative(alternative)
}

function scanAgain() {
  showAlternatives.value = false
  /* Sans caméra (desktop), il n'y a pas de boucle à relancer : on vide juste le résultat
     pour laisser la place à un nouvel import. */
  if (camera.status === "on") scanner.start()
  else scanner.reset()
}

function onAutoAddChange() {
  rememberScanPrefs()
  /* Basculer en cours de résultat ne doit pas ajouter la carte affichée à retardement :
     le mode ne prend effet qu'au prochain verrouillage. */
}
</script>

<template>
  <section class="scan">
    <div class="wrap scan-wrap">
      <h1 class="sr-only">Scanner une carte</h1>
      <p class="muted scan-intro">
        Présentez la carte dans la silhouette : elle est reconnue automatiquement, par son code imprimé ou par son
        illustration. Aucun bouton à appuyer. Les champs de bataille, imprimés en paysage, sont reconnus à
        l'illustration seule — leur code n'est pas lu.
      </p>

      <p v-if="index.loading" class="muted scan-status">Chargement de l'index des cartes…</p>
      <p v-else-if="index.error" class="error">{{ index.error }}</p>
      <div v-else-if="!index.total" class="panel scan-empty">
        <p>Aucune carte à reconnaître pour l'instant. Le scan sera disponible dès que le catalogue sera synchronisé.</p>
      </div>

      <template v-else>
        <!-- Empreintes absentes : la voie « ressemblance » est morte, mais la lecture du code
             suffit à identifier une carte. On garde donc l'import de photo, sans lancer la
             boucle caméra (elle n'aurait rien à comparer entre deux images). -->
        <div v-if="!index.hashed" class="panel scan-nocam">
          <p>
            Empreintes visuelles pas encore calculées : seule la lecture du code imprimé est disponible. Importez une
            photo bien nette du bas de la carte.
          </p>
        </div>
        <div
          v-if="index.hashed && camera.status === 'on'"
          class="scan-stage"
          :class="{ 'is-locked': state === 'locked' }"
        >
          <video ref="video" class="scan-video" autoplay playsinline muted></video>
          <div ref="frame" class="scan-frame" aria-hidden="true"></div>
          <p class="scan-hud" role="status">{{ hudText }}</p>
          <button v-if="torch.available" type="button" class="scan-torch" :aria-pressed="torch.on" @click="toggleTorch">
            {{ torch.on ? "Éteindre la lampe" : "Lampe" }}
          </button>
        </div>
        <p v-else-if="index.hashed && camera.status === 'starting'" class="muted scan-status">
          Démarrage de la caméra…
        </p>
        <div v-else-if="index.hashed" class="panel scan-nocam">
          <p v-if="camera.error">{{ camera.error }}</p>
          <p v-else>Pas de caméra ici ? Importez une photo de la carte : le résultat est le même.</p>
        </div>

        <div class="scan-actions">
          <label class="btn btn-ghost scan-import">
            Importer une photo
            <input type="file" accept="image/*" capture="environment" @change="onFileChange" />
          </label>
          <button
            v-if="camera.status === 'off' && camera.error"
            type="button"
            class="btn btn-ghost"
            @click="startCamera"
          >
            Réessayer la caméra
          </button>
          <label v-if="session.token" class="scan-auto">
            <input type="checkbox" v-model="autoAdd" @change="onAutoAddChange" />
            Ajout automatique
          </label>
        </div>

        <!-- Hors scène caméra (desktop, import de photo) : le HUD n'est pas rendu, il faut
             donc dire ici que le moteur se télécharge — sinon le premier import paraît figé. -->
        <p v-if="importing" class="muted scan-status" role="status">Analyse de la photo…</p>
        <p v-else-if="ocrProgress !== null && camera.status !== 'on'" class="muted scan-status" role="status">
          Moteur de lecture : {{ Math.round(ocrProgress * 100) }} %
        </p>
        <p v-if="!ocrAvailable" class="muted scan-note">
          Lecture du code indisponible sur cet appareil : l'identification se fait par ressemblance visuelle.
        </p>
        <div v-if="scanError" class="scan-recover">
          <p class="error">{{ scanError }}</p>
          <button v-if="camera.status === 'on'" type="button" class="btn btn-ghost btn-sm" @click="scanAgain">
            Reprendre le scan
          </button>
        </div>

        <div v-if="toast" class="scan-toast" role="status">
          Ajouté : {{ toast.card.name }} ×{{ toast.qty
          }}<template v-if="formatEur(toast.card.price_eur)"> · {{ formatEur(toast.card.price_eur) }}</template>
        </div>

        <div v-if="noMatch" class="panel scan-nomatch">
          <p>
            Aucun résultat plausible. Reprenez la photo : carte bien à plat, silhouette remplie, lumière uniforme et
            sans reflet.
          </p>
          <button v-if="camera.status === 'on'" type="button" class="btn btn-ghost btn-sm" @click="scanAgain">
            Reprendre le scan
          </button>
        </div>

        <div v-if="result" class="scan-result" role="status" aria-live="polite">
          <div v-if="!card" class="muted scan-status">Chargement de la carte…</div>
          <template v-else>
            <div class="scan-result-head">
              <img
                class="scan-result-visual"
                :src="cardThumb(card.image_url, 320)"
                :alt="`Carte Riftbound : ${card.name}`"
                decoding="async"
              />
              <div class="scan-result-info">
                <h2 ref="resultHeading" tabindex="-1">{{ card.name }}</h2>
                <p class="mono scan-result-code">{{ card.riftbound_id?.toUpperCase() }} · {{ card.set_id }}</p>
                <p class="muted">{{ TYPES[card.type] || card.type }} · {{ RARITIES[card.rarity] || card.rarity }}</p>
                <div class="scan-price">
                  <p v-if="priceMain" class="price-line">
                    <b class="price-amount">{{ priceMain }}</b>
                    <span v-if="priceFoil" class="price-foil">foil : {{ priceFoil }}</span>
                  </p>
                  <p v-else class="muted">Prix indisponible pour cette carte.</p>
                  <p class="price-note">{{ PRICE_NOTE }}</p>
                  <a class="price-link" :href="cardmarketUrl(card.name)" target="_blank" rel="noopener">
                    Voir sur Cardmarket ↗
                  </a>
                </div>
                <p class="mono scan-method">{{ methodLabel }}</p>
              </div>
            </div>

            <p v-if="result.ambiguous" class="scan-ambiguous">
              Plusieurs impressions portent ce numéro (étoile difficile à lire) : vérifiez la carte affichée, ou
              choisissez ci-dessous.
            </p>

            <div v-if="session.token" class="scan-prefs">
              <label>
                Langue
                <select v-model="scanLang" @change="rememberScanPrefs">
                  <option v-for="(label, code) in LANGS" :key="code" :value="code">{{ label }}</option>
                </select>
              </label>
              <label>
                État
                <select v-model="scanCondition" @change="rememberScanPrefs">
                  <option v-for="(label, code) in CONDITIONS" :key="code" :value="code">{{ label }}</option>
                </select>
              </label>
              <label>
                Quantité
                <input v-model.number="scanQty" type="number" min="1" max="99" inputmode="numeric" class="scan-qty" />
              </label>
            </div>
            <p v-else class="muted scan-login">
              <RouterLink :to="{ path: '/connexion', query: { suite: '/scan' } }">Connectez-vous</RouterLink> pour
              ajouter cette carte à votre collection.
            </p>

            <div class="scan-result-actions">
              <button
                v-if="session.token"
                type="button"
                class="btn scan-add"
                :disabled="adding"
                @click="addToCollection"
              >
                Ajouter à ma collection
              </button>
              <RouterLink class="btn btn-ghost" :to="`/cartes/${card.id}`">Voir la fiche</RouterLink>
              <button type="button" class="btn btn-ghost" @click="scanAgain">Scanner une autre carte</button>
            </div>
            <p v-if="added[card.id]" class="scan-added">
              Ajouté ✓<template v-if="added[card.id] > 1"> ×{{ added[card.id] }}</template>
            </p>

            <div v-if="result.alternatives.length" class="scan-alt">
              <button
                type="button"
                class="scan-alt-toggle"
                :aria-expanded="showAlternatives"
                @click="toggleAlternatives"
              >
                Ce n'est pas la bonne carte ?
              </button>
              <ul v-if="showAlternatives" class="scan-alt-list">
                <li v-for="alternative in result.alternatives" :key="alternative.id">
                  <button type="button" class="scan-alt-item" @click="pickAlternative(alternative)">
                    <img
                      v-if="alternativeCards[alternative.id]"
                      :src="cardThumb(alternativeCards[alternative.id].image_url, 120)"
                      :alt="`Carte Riftbound : ${alternativeCards[alternative.id].name}`"
                      loading="lazy"
                      decoding="async"
                    />
                    <span class="scan-alt-info">
                      <b>{{ alternativeCards[alternative.id]?.name || alternative.rid?.toUpperCase() }}</b>
                      <span class="mono muted">
                        {{ alternative.rid?.toUpperCase()
                        }}<template v-if="alternative.distance !== null && alternative.distance !== undefined">
                          · écart {{ alternative.distance }}/512</template
                        >
                      </span>
                    </span>
                  </button>
                </li>
              </ul>
            </div>
          </template>
        </div>
      </template>
    </div>
  </section>
</template>
