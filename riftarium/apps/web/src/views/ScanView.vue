<script setup>
import { nextTick, onBeforeUnmount, onMounted, reactive, ref } from "vue"
import { onBeforeRouteLeave } from "vue-router"
import { api, cardThumb, session, CONDITIONS, LANGS, RARITIES, TYPES } from "../api.js"
import { bestMatches } from "../scanHash.js"
import { hashFromFile, hashFromVideoFrame } from "../scanCapture.js"

/* Au-delà de cette distance (sur 512 bits), la photo ne ressemble à rien de connu :
   on propose de reprendre plutôt que d'afficher des candidats absurdes. */
const NO_MATCH_DISTANCE = 200

/* Contrat serveur : dHash 16×16 H+V de la fenêtre d'illustration (indépendante de la langue).
   Un autre algo (vieux cache, serveur pas à jour) rendrait le classement absurde : on refuse. */
const EXPECTED_ALGO = "dhash16-hv-art"

/* Index des empreintes dHash de toutes les cartes, chargé une fois au montage. */
const index = reactive({ loading: true, error: "", items: [] })

const video = ref(null)
const frame = ref(null)
/* idle → starting → on, ou off (refusé, absent, desktop) avec explication éventuelle. */
const camera = reactive({ status: "idle", error: "" })
let stream = null

const scanning = ref(false)
const scanError = ref("")
const noMatch = ref(false)
const candidates = ref([]) // [{ id, h, distance, card }]
const added = reactive({}) // id → nombre d'exemplaires ajoutés pendant la session
const addingId = ref("")

/* Langue et état appliqués aux ajouts — mémorisés entre les sessions de scan
   (on scanne généralement des cartes de la même langue à la chaîne). */
const SCAN_PREFS_KEY = "riftarium.scanPrefs"
function loadScanPrefs() {
  try {
    const raw = JSON.parse(localStorage.getItem(SCAN_PREFS_KEY) || "{}")
    return {
      lang: raw.lang in LANGS ? raw.lang : "FR",
      condition: raw.condition in CONDITIONS ? raw.condition : "NM"
    }
  } catch {
    return { lang: "FR", condition: "NM" }
  }
}
const scanLang = ref(loadScanPrefs().lang)
const scanCondition = ref(loadScanPrefs().condition)
function rememberScanPrefs() {
  try {
    localStorage.setItem(SCAN_PREFS_KEY, JSON.stringify({ lang: scanLang.value, condition: scanCondition.value }))
  } catch {
    /* stockage indisponible (navigation privée) : préférences non persistées */
  }
}

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
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } })
    camera.status = "on"
    await nextTick() // le <video> n'est rendu qu'une fois le flux obtenu
    if (!video.value) return stopCamera()
    video.value.srcObject = stream
    await video.value.play?.()?.catch?.(() => {})
  } catch (error) {
    camera.status = "off"
    camera.error = explainCameraError(error)
  }
}

function stopCamera() {
  for (const track of stream?.getTracks() || []) track.stop()
  stream = null
  if (video.value) video.value.srcObject = null
  if (camera.status === "on" || camera.status === "starting") camera.status = "off"
}

/* Coupe la caméra à la navigation comme au démontage : pas de LED caméra fantôme. */
onBeforeRouteLeave(() => stopCamera())
onBeforeUnmount(() => stopCamera())

onMounted(async () => {
  try {
    const data = await api("/api/cards/hashes")
    if (data?.items?.length && data.algo !== EXPECTED_ALGO) {
      index.error = `Empreintes incompatibles avec cette version du site (« ${data.algo || "?"} » au lieu de « ${EXPECTED_ALGO} »). Rechargez la page ; si le problème persiste, le serveur n'est pas encore à jour.`
    } else {
      index.items = data?.items || []
    }
  } catch (error) {
    index.error = error.message
  } finally {
    index.loading = false
  }
  if (index.items.length) startCamera()
})

/* Le rééchantillonnage canvas et la photo étant imparfaits, le résultat est un CLASSEMENT
   des cartes les plus ressemblantes, que l'utilisateur confirme — pas une identification. */
async function runScan(makeHash) {
  if (scanning.value || !index.items.length) return
  scanning.value = true
  scanError.value = ""
  noMatch.value = false
  candidates.value = []
  try {
    const hex = await makeHash()
    const matches = bestMatches(hex, index.items, 3)
    if (!matches.length || matches[0].distance > NO_MATCH_DISTANCE) {
      noMatch.value = true
      return
    }
    const loaded = await Promise.all(
      matches.map(async (match) => {
        try {
          return { ...match, card: await api(`/api/cards/${match.id}`) }
        } catch {
          return null // carte candidate indisponible : on garde les autres
        }
      })
    )
    candidates.value = loaded.filter(Boolean)
    if (!candidates.value.length) scanError.value = "Impossible de charger les cartes candidates. Réessayez."
  } catch {
    scanError.value = "Photo illisible. Réessayez avec la carte bien cadrée."
  } finally {
    scanning.value = false
  }
}

async function capture() {
  const element = video.value
  if (!element || !element.videoWidth || !frame.value) return
  /* Le flux couvre le cadre en object-fit: cover : on remonte du rectangle affiché
     vers les coordonnées intrinsèques de la vidéo pour ne découper QUE la zone du cadre. */
  const videoRect = element.getBoundingClientRect()
  const frameRect = frame.value.getBoundingClientRect()
  const scale = Math.max(element.videoWidth / videoRect.width, element.videoHeight / videoRect.height)
  const crop = {
    sx: (element.videoWidth - videoRect.width * scale) / 2 + (frameRect.left - videoRect.left) * scale,
    sy: (element.videoHeight - videoRect.height * scale) / 2 + (frameRect.top - videoRect.top) * scale,
    sw: frameRect.width * scale,
    sh: frameRect.height * scale
  }
  await runScan(() => hashFromVideoFrame(element, crop))
}

async function onFileChange(event) {
  const file = event.target.files?.[0]
  if (!file) return
  await runScan(() => hashFromFile(file))
  event.target.value = "" // permet de réimporter le même fichier
}

async function addToCollection(candidate) {
  if (addingId.value) return
  addingId.value = candidate.id
  scanError.value = ""
  try {
    await api(`/api/collection/${candidate.id}/entries`, {
      method: "POST",
      body: { qty: 1, condition: scanCondition.value, lang: scanLang.value }
    })
    rememberScanPrefs()
    added[candidate.id] = (added[candidate.id] || 0) + 1
  } catch (error) {
    scanError.value = error.message
  } finally {
    addingId.value = ""
  }
}

function newScan() {
  candidates.value = []
  noMatch.value = false
  scanError.value = ""
}
</script>

<template>
  <section class="scan">
    <div class="wrap scan-wrap">
      <p class="scan-eyebrow mono">Collection</p>
      <h1>Scanner une carte</h1>
      <p class="muted scan-intro">
        Cadrez la carte dans la silhouette puis capturez : les cartes les plus ressemblantes s'affichent, à vous de
        confirmer la bonne.
      </p>

      <p v-if="index.loading" class="muted scan-status">Chargement des empreintes…</p>
      <p v-else-if="index.error" class="error">{{ index.error }}</p>
      <div v-else-if="!index.items.length" class="panel scan-empty">
        <p>Empreintes pas encore calculées. Le scan sera disponible dès que le serveur les aura générées.</p>
      </div>

      <template v-else>
        <div v-if="camera.status === 'on'" class="scan-stage">
          <video ref="video" class="scan-video" autoplay playsinline muted></video>
          <div ref="frame" class="scan-frame" aria-hidden="true"></div>
          <button
            type="button"
            class="scan-shutter"
            :disabled="scanning"
            aria-label="Capturer la carte"
            @click="capture"
          ></button>
        </div>
        <p v-else-if="camera.status === 'starting'" class="muted scan-status">Démarrage de la caméra…</p>
        <div v-else class="panel scan-nocam">
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
        </div>

        <p v-if="scanning" class="muted scan-status" role="status">Analyse de la photo…</p>
        <p v-if="scanError" class="error">{{ scanError }}</p>

        <div v-if="noMatch" class="panel scan-nomatch">
          <p>
            Aucun résultat plausible. Reprenez la photo : carte bien à plat, silhouette remplie, lumière uniforme et
            sans reflet.
          </p>
        </div>

        <div v-if="candidates.length" class="scan-results">
          <h2>Est-ce l'une de ces cartes ?</h2>
          <p v-if="!session.token" class="muted scan-login">
            <RouterLink :to="{ path: '/connexion', query: { suite: '/scan' } }">Connectez-vous</RouterLink> pour les
            ajouter à votre collection. En attendant, touchez une carte pour ouvrir sa fiche.
          </p>
          <div v-else class="scan-prefs">
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
          </div>
          <ul class="scan-candidates">
            <li v-for="candidate in candidates" :key="candidate.id">
              <component
                :is="session.token ? 'button' : 'RouterLink'"
                class="scan-candidate"
                v-bind="
                  session.token
                    ? { type: 'button', disabled: addingId === candidate.id }
                    : { to: `/cartes/${candidate.id}` }
                "
                @click="session.token ? addToCollection(candidate) : null"
              >
                <img
                  :src="cardThumb(candidate.card.image_url, 200)"
                  :alt="`Carte Riftbound : ${candidate.card.name}`"
                  loading="lazy"
                  decoding="async"
                />
                <span class="scan-candidate-info">
                  <b>{{ candidate.card.name }}</b>
                  <span class="mono"
                    >{{ candidate.card.riftbound_id?.toUpperCase() }} · {{ candidate.card.set_id }}</span
                  >
                  <span class="muted">
                    {{ TYPES[candidate.card.type] || candidate.card.type }} ·
                    {{ RARITIES[candidate.card.rarity] || candidate.card.rarity }}
                  </span>
                  <span class="mono scan-distance">écart {{ candidate.distance }}/512</span>
                </span>
                <span v-if="added[candidate.id]" class="scan-added">
                  Ajouté ✓<template v-if="added[candidate.id] > 1"> ×{{ added[candidate.id] }}</template>
                </span>
                <span v-else-if="session.token" class="scan-add-hint mono">+1</span>
              </component>
            </li>
          </ul>
          <div class="scan-again">
            <button type="button" class="btn btn-ghost btn-sm" @click="newScan">Nouveau scan</button>
            <RouterLink v-if="session.token" class="btn btn-ghost btn-sm" to="/collection">Ma collection</RouterLink>
          </div>
        </div>
      </template>
    </div>
  </section>
</template>
