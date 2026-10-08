<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, cardThumb } from "../api.js"
import UserAvatar from "../components/UserAvatar.vue"
import { legendOf } from "../deckDisplay.js"
import { profilePath } from "../social.js"
import {
  cancelRoom,
  confirmMatch,
  disputeMatch,
  getCurrent,
  getMatch,
  getRoom,
  joinRoom,
  leaveRoom,
  matchStatusLabel,
  modeLabel,
  roomStatusLabel,
  updateMe
} from "../play.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftField from "../ui/RiftField.vue"
import RiftPanel from "../ui/RiftPanel.vue"

/* Temps réel par sondage : 5 s côté web (2 s sur mobile, où vit le compteur).
   Le minuteur est réarmé après chaque réponse — jamais deux requêtes en vol — et
   le délai double à chaque échec consécutif jusqu'à une minute, pour ne pas
   marteler une API en panne. */
const POLL_MS = 5000
const POLL_MAX_MS = 60000
const SEARCH_DEBOUNCE_MS = 300

const route = useRoute()
const router = useRouter()

/* Le code circule en majuscules (alphabet sans 0/O/1/I) : on normalise ce qui vient de l'URL. */
const code = computed(() => String(route.params.code || "").toUpperCase())

const me = ref(null)
const room = ref(null)
const match = ref(null)
const current = ref(null)
const loading = ref(true)
/* `error` = échec d'une action de l'utilisateur (rejoindre, se déclarer prêt…) ou
   du chargement initial ; `pollError` = hoquet du sondage silencieux. Deux refs
   distinctes : un sondage raté ne doit jamais effacer le message d'une action. */
const error = ref("")
const pollError = ref("")
const notFound = ref(false)
const busy = ref(false)

const codeDraft = ref("")
const decks = ref([])
const legendQuery = ref("")
const legendResults = ref([])
const legendSearching = ref(false)

let pollTimer = null
/* Passe à true au démontage : garde-fou pour tout code qui reprend la main après
   un await (le composant peut disparaître pendant le chargement initial). */
let stopped = false
/* Requête de sondage en vol : évite le chevauchement de deux lectures du salon. */
let polling = false
let pollFailures = 0
let legendTimer = null
let legendSeq = 0

const players = computed(() => [...(room.value?.players || [])].sort((a, b) => (a.seat ?? 0) - (b.seat ?? 0)))
const myPlayer = computed(() => players.value.find((player) => player.user?.id === me.value?.id) || null)
const isHost = computed(() => Boolean(room.value && me.value && room.value.host_id === me.value.id))
/* Deux sièges seulement en v1 : un salon plein ne se rejoint pas. */
const canJoin = computed(() =>
  Boolean(room.value && !myPlayer.value && room.value.status === "open" && players.value.length < 2)
)
const bothReady = computed(() => players.value.length === 2 && players.value.every((player) => player.ready))
const isHostPlayer = (player) => Boolean(room.value && player.user?.id === room.value.host_id)
/* Deux sièges face à face : le second reste visible, libre, tant que personne ne l'occupe. */
const seats = computed(() => [players.value[0] ?? null, players.value[1] ?? null])

const myMatchPlayer = computed(() => (match.value?.players || []).find((p) => p.user?.id === me.value?.id) || null)
const canConfirm = computed(() =>
  Boolean(match.value?.status === "awaiting_confirmation" && myMatchPlayer.value && !myMatchPlayer.value.confirmed)
)

/* Un salon annulé ou une partie close ne bougeront plus : inutile de continuer à sonder. */
const settled = computed(() => {
  if (!room.value) return false
  if (room.value.status === "cancelled") return true
  return room.value.status === "finished" && ["confirmed", "disputed", "abandoned"].includes(match.value?.status)
})

async function loadMatch(id) {
  try {
    match.value = await getMatch(id)
  } catch {
    /* pas (ou plus) participant : le match reste masqué, le salon suffit */
  }
}

async function loadRoom({ silent = false } = {}) {
  if (!code.value) return
  if (!silent) loading.value = true
  try {
    room.value = await getRoom(code.value)
    if (room.value.match_id) await loadMatch(room.value.match_id)
    else match.value = null
    pollFailures = 0
    pollError.value = ""
    if (!silent) error.value = ""
  } catch (e) {
    pollFailures += 1
    if (e.status === 404) {
      /* Le salon n'existe plus (expiré, annulé) ou le code est faux : rien à
         attendre, on coupe le sondage au lieu de boucler sur un 404. */
      notFound.value = true
      stopPolling()
      room.value = null
      match.value = null
      pollError.value = ""
      error.value = "Salon introuvable : ce code n'existe plus (salon expiré ou annulé)."
    } else if (silent) {
      /* Sondage : on garde le dernier état connu plutôt que de vider la page sur un hoquet réseau. */
      pollError.value = "Mise à jour interrompue — dernier état connu affiché."
    } else {
      error.value = e.message
      room.value = null
    }
  } finally {
    if (!silent) loading.value = false
  }
}

function stopPolling() {
  clearTimeout(pollTimer)
  pollTimer = null
}

/* Délai courant : 5 s, puis 10, 20, 40, plafonné à 60 s tant que ça échoue. */
function pollDelay() {
  return Math.min(POLL_MAX_MS, POLL_MS * 2 ** Math.max(0, pollFailures))
}

function schedulePoll() {
  stopPolling()
  if (stopped || notFound.value || settled.value) return
  pollTimer = setTimeout(poll, pollDelay())
}

async function poll() {
  if (stopped || notFound.value || settled.value) return
  /* Onglet en arrière-plan : on saute le tour (aucune requête) sans perdre le minuteur. */
  if (polling || (typeof document !== "undefined" && document.hidden)) {
    schedulePoll()
    return
  }
  polling = true
  try {
    await loadRoom({ silent: true })
  } finally {
    polling = false
  }
  schedulePoll()
}

/* Retour au premier plan : on rafraîchit sans attendre la fin du minuteur. */
function onVisibilityChange() {
  if (typeof document !== "undefined" && !document.hidden && pollTimer) poll()
}

/* Salon annulé ou partie close : plus rien ne bougera, on arrête net. */
watch(settled, (value) => {
  if (value) stopPolling()
})

/* Le serveur reste seul juge de l'état : join / leave / cancel / me renvoient le
   RoomOut à jour, on le prend tel quel ; sinon (confirm, dispute) on relit. */
async function run(action) {
  if (busy.value) return false
  busy.value = true
  error.value = ""
  try {
    const result = await action()
    if (result?.code) {
      room.value = result
      if (result.match_id) await loadMatch(result.match_id)
      else match.value = null
    } else {
      await loadRoom({ silent: true })
    }
    return true
  } catch (e) {
    error.value = e.message
    return false
  } finally {
    busy.value = false
  }
}

const join = () => run(() => joinRoom(code.value))
const leave = () => run(() => leaveRoom(code.value))
const cancel = () => run(() => cancelRoom(code.value))
const confirmResult = () => run(() => confirmMatch(match.value.id))
const disputeResult = () => run(() => disputeMatch(match.value.id))

/* Changer de légende ou de deck remet le joueur « pas prêt » : sans cela, l'hôte
   pourrait lancer la partie sur un choix que l'on venait juste de modifier. */
function pickLegend(card) {
  return run(async () => {
    await updateMe(code.value, { legend_card_id: card.id, deck_id: myPlayer.value?.deck?.id ?? null, ready: false })
    legendQuery.value = ""
    legendResults.value = []
  })
}

/* Choisir un deck, c'est choisir sa légende : on lit le deck pour reprendre la
   carte de zone Légende telle qu'elle y est rangée — même `id`, donc la même
   impression (alt-art, overnumbered, signature) que sur la table. Elle part dans
   le même PUT que le deck, et reste modifiable à la main ensuite. */
async function legendIdOfDeck(deckId) {
  try {
    const deck = await api(`/api/decks/${encodeURIComponent(deckId)}`)
    return legendOf(deck)?.id ?? null
  } catch {
    /* Deck illisible : on garde la légende déjà choisie plutôt que de l'effacer. */
    return null
  }
}

async function pickDeck(event) {
  const select = event.target
  const value = select.value
  /* Le <select> est piloté par le serveur (`:value`) : si le PUT échoue, l'état
     affiché ne bouge pas et Vue ne repatche rien — on remet la valeur à la main. */
  const previous = myPlayer.value?.deck?.id ?? ""
  const ok = await run(async () => {
    const deckId = value ? Number(value) : null
    const currentLegendId = myPlayer.value?.legend?.id ?? null
    const legendId = deckId ? ((await legendIdOfDeck(deckId)) ?? currentLegendId) : currentLegendId
    await updateMe(code.value, { legend_card_id: legendId, deck_id: deckId, ready: false })
  })
  if (!ok) select.value = String(previous)
}

function toggleReady() {
  return run(() =>
    updateMe(code.value, {
      legend_card_id: myPlayer.value?.legend?.id ?? null,
      deck_id: myPlayer.value?.deck?.id ?? null,
      ready: !myPlayer.value?.ready
    })
  )
}

/* Jeton de séquence : seule la dernière recherche lancée a le droit d'écrire le
   résultat, sinon une réponse lente écraserait celle d'une frappe plus récente. */
async function searchLegends(query) {
  const seq = ++legendSeq
  legendSearching.value = true
  try {
    const payload = await api(`/api/cards?type=Legend&q=${encodeURIComponent(query)}`)
    if (seq !== legendSeq) return
    const list = Array.isArray(payload) ? payload : payload?.items || []
    legendResults.value = list.slice(0, 12)
  } catch {
    if (seq === legendSeq) legendResults.value = []
  } finally {
    if (seq === legendSeq) legendSearching.value = false
  }
}

watch(legendQuery, (value) => {
  clearTimeout(legendTimer)
  const query = value.trim()
  if (!query) {
    /* Champ vidé : la réponse d'une recherche encore en vol est périmée. */
    legendSeq += 1
    legendResults.value = []
    legendSearching.value = false
    return
  }
  legendTimer = setTimeout(() => searchLegends(query), SEARCH_DEBOUNCE_MS)
})

function openCode() {
  const value = codeDraft.value.trim().toUpperCase()
  if (value) router.push(`/salon/${encodeURIComponent(value)}`)
}

onMounted(async () => {
  if (typeof document !== "undefined") {
    document.addEventListener("visibilitychange", onVisibilityChange)
  }
  try {
    me.value = await api("/api/auth/me")
  } catch {
    /* Un 401 est déjà traité par api() (session fermée, App.vue redirige vers la
       connexion) ; toute autre panne laisse la page en lecture seule. */
  }
  if (!code.value) {
    try {
      current.value = await getCurrent()
    } catch {
      /* reprise indisponible : la saisie du code suffit */
    }
    if (!stopped) loading.value = false
    return
  }
  await loadRoom()
  try {
    decks.value = await api("/api/decks/mine")
  } catch {
    /* sans liste de decks, le choix de légende reste possible */
  }
  /* Démonté pendant ces attentes : surtout ne pas laisser un minuteur orphelin. */
  if (stopped) return
  schedulePoll()
})

onBeforeUnmount(() => {
  stopped = true
  stopPolling()
  clearTimeout(legendTimer)
  if (typeof document !== "undefined") {
    document.removeEventListener("visibilitychange", onVisibilityChange)
  }
})
</script>

<template>
  <div class="wrap cards-wrap salon">
    <h1 class="salon-title">
      Salon de jeu
      <span v-if="code" class="salon-code">{{ room?.code || code }}</span>
    </h1>

    <!-- Sans code : saisie manuelle, pour qui a reçu le code sans le lien. -->
    <RiftPanel v-if="!code" class="salon-rejoindre" title="Rejoindre un salon">
      <p class="salon-note">
        Saisissez le code à six caractères affiché sur le téléphone de l'hôte, ou ouvrez simplement le lien qu'il vous a
        partagé.
      </p>
      <form class="salon-code-form" @submit.prevent="openCode">
        <div class="salon-code-field">
          <RiftField
            v-model="codeDraft"
            label="Code du salon"
            maxlength="6"
            autocomplete="off"
            autocapitalize="characters"
            autocorrect="off"
            spellcheck="false"
            placeholder="ABC234"
          />
        </div>
        <RiftButton type="submit" variant="primary" :disabled="!codeDraft.trim()">Rejoindre</RiftButton>
      </form>
      <p v-if="current?.room" class="salon-note">
        Vous avez déjà un salon en cours :
        <RouterLink class="salon-link" :to="`/salon/${current.room.code}`">{{ current.room.code }}</RouterLink>
      </p>
    </RiftPanel>

    <template v-else>
      <p v-if="loading" class="salon-note" role="status">Chargement du salon…</p>
      <p v-else-if="error && !room" class="salon-error" role="alert">{{ error }}</p>

      <template v-else-if="room">
        <RiftPanel class="salon-head" tag="div">
          <div class="salon-meta">
            <RiftChip class="salon-statut" static selected :label="roomStatusLabel(room.status)" />
            <RiftChip class="salon-format" static :label="modeLabel(room.mode)" />
            <span class="salon-regles">
              {{ room.victory_score }} points · {{ room.rounds_to_win }} manche(s) gagnante(s)
            </span>
          </div>

          <div class="salon-duel">
            <template v-for="(player, index) in seats" :key="index">
              <p v-if="index === 1" class="salon-contre">contre</p>
              <div v-if="player" class="salon-seat" :class="{ 'salon-seat-ready': player.ready }">
                <p class="salon-who">
                  <UserAvatar :src="player.user?.avatar_url" :handle="player.user?.handle" :size="40" />
                  <!-- Le pseudo mène au profil public : de quoi jauger un adversaire inconnu. -->
                  <RouterLink
                    v-if="player.user?.handle"
                    class="salon-pseudo salon-ellipse"
                    :to="profilePath(player.user.handle)"
                    :title="player.user.handle"
                  >
                    {{ player.user.handle }}
                  </RouterLink>
                  <span v-else class="salon-pseudo salon-ellipse salon-faint">Compte supprimé</span>
                  <span v-if="isHostPlayer(player)" class="salon-hote">hôte</span>
                </p>
                <p class="salon-legend">
                  <img
                    v-if="player.legend?.image_url"
                    class="salon-thumb"
                    :src="cardThumb(player.legend.image_url, 72)"
                    :alt="`Légende : ${player.legend.name}`"
                    width="36"
                    height="36"
                    loading="lazy"
                    decoding="async"
                  />
                  <span v-else class="salon-thumb salon-thumb-empty" aria-hidden="true"></span>
                  <span class="salon-ellipse" :class="{ 'salon-faint': !player.legend }">
                    {{ player.legend?.name || "Légende à choisir" }}
                  </span>
                </p>
                <p class="salon-deck salon-ellipse" :class="{ 'salon-faint': !player.deck }">
                  {{ player.deck?.name || "Deck à choisir" }}
                </p>
                <RiftChip
                  class="salon-pret"
                  static
                  :selected="player.ready"
                  :label="player.ready ? 'Prêt' : 'Pas encore prêt'"
                />
              </div>
              <div v-else class="salon-seat salon-seat-libre">
                <p class="salon-note">Place libre — en attente d'un adversaire.</p>
              </div>
            </template>
          </div>
        </RiftPanel>

        <p v-if="error" class="salon-error" role="alert">{{ error }}</p>
        <p v-if="pollError" class="salon-note" role="status">{{ pollError }}</p>

        <RiftPanel v-if="canJoin" class="salon-join" tag="div">
          <p class="salon-note">Ce salon vous attend : rejoignez-le, puis choisissez votre légende et votre deck.</p>
          <RiftButton variant="primary" :disabled="busy" @click="join">Rejoindre</RiftButton>
        </RiftPanel>

        <p v-else-if="!myPlayer && room.status === 'open'" class="salon-note">
          Ce salon est complet : les deux places sont prises.
        </p>
        <p v-else-if="!myPlayer" class="salon-note">Vous ne participez pas à ce salon.</p>

        <!-- Choix perso : uniquement tant que la partie n'est pas lancée. -->
        <RiftPanel v-if="myPlayer && room.status === 'open'" class="salon-choix" title="Mes choix">
          <div class="salon-choix-grid">
            <div class="salon-legend-search">
              <RiftField
                v-model="legendQuery"
                label="Légende"
                search
                inputmode="search"
                autocomplete="off"
                autocapitalize="off"
                autocorrect="off"
                spellcheck="false"
                placeholder="Rechercher une légende…"
              />
              <p v-if="legendSearching" class="salon-note" role="status">Recherche…</p>
              <ul v-if="legendResults.length" class="salon-legend-results">
                <li v-for="card in legendResults" :key="card.id">
                  <button type="button" class="salon-legend-option" :disabled="busy" @click="pickLegend(card)">
                    <img
                      v-if="card.image_url"
                      class="salon-thumb"
                      :src="cardThumb(card.image_url, 72)"
                      alt=""
                      width="32"
                      height="32"
                      loading="lazy"
                      decoding="async"
                    />
                    <span v-else class="salon-thumb salon-thumb-empty" aria-hidden="true"></span>
                    <span class="salon-ellipse">{{ card.name }}</span>
                  </button>
                </li>
              </ul>
              <p v-else-if="legendQuery.trim() && !legendSearching" class="salon-note">Aucune légende trouvée.</p>
            </div>

            <div class="salon-deck-field">
              <label class="salon-label" for="room-deck">Deck</label>
              <span class="salon-select-box">
                <select
                  id="room-deck"
                  class="salon-select"
                  :value="myPlayer.deck?.id ?? ''"
                  :disabled="busy"
                  @change="pickDeck"
                >
                  <option value="">Sans deck</option>
                  <option v-for="deck in decks" :key="deck.id" :value="deck.id">{{ deck.name }}</option>
                </select>
              </span>
            </div>
          </div>

          <RiftButton
            class="salon-ready"
            :variant="myPlayer.ready ? 'ghost' : 'primary'"
            :aria-pressed="myPlayer.ready ? 'true' : 'false'"
            :disabled="busy"
            @click="toggleReady"
          >
            {{ myPlayer.ready ? "Je ne suis plus prêt" : "Je suis prêt" }}
          </RiftButton>
        </RiftPanel>

        <!-- Le lancement vit sur le téléphone de l'hôte : le compteur y est tenu. -->
        <RiftPanel
          v-if="myPlayer && room.status === 'open' && bothReady"
          class="salon-notice"
          tag="div"
          accent="var(--bronze)"
        >
          <p class="salon-notice-text">
            <template v-if="isHost">Lancez la partie depuis l'application Riftarium sur votre téléphone.</template>
            <template v-else>Tout le monde est prêt : l'hôte lance la partie depuis son téléphone.</template>
          </p>
        </RiftPanel>

        <div v-if="myPlayer && room.status === 'open'" class="salon-actions">
          <RiftButton v-if="isHost" class="salon-danger" variant="secondary" :disabled="busy" @click="cancel">
            Annuler le salon
          </RiftButton>
          <RiftButton v-else variant="ghost" :disabled="busy" @click="leave">Quitter le salon</RiftButton>
        </div>

        <RiftPanel v-if="match" class="salon-partie" title="Partie">
          <p class="salon-partie-status">
            {{ matchStatusLabel(match.status) }}
            <span v-if="match.state?.round"> · manche {{ match.state.round }}</span>
            <span v-if="match.state?.turn"> · tour {{ match.state.turn }}</span>
          </p>
          <ul class="salon-scores" aria-live="polite">
            <li v-for="player in match.players" :key="player.seat" class="salon-score-side" aria-atomic="true">
              <span class="sr-only">{{ player.user?.handle || "Compte supprimé" }} : {{ player.score }}</span>
              <span class="salon-score-who">
                <UserAvatar :src="player.user?.avatar_url" :handle="player.user?.handle" :size="28" />
                <RouterLink
                  v-if="player.user?.handle"
                  class="salon-pseudo salon-ellipse"
                  :to="profilePath(player.user.handle)"
                  :title="player.user.handle"
                >
                  {{ player.user.handle }}
                </RouterLink>
                <span v-else class="salon-pseudo salon-ellipse salon-faint">Compte supprimé</span>
              </span>
              <b class="salon-score" aria-hidden="true">{{ player.score }}</b>
              <span v-if="match.mode === 'match'" class="salon-manches">{{ player.rounds_won }} manche(s)</span>
              <RiftChip v-if="player.confirmed" class="salon-confirme" static selected label="Confirmé" />
            </li>
          </ul>
          <p class="salon-note">Cette page suit le score en lecture seule.</p>
          <div class="salon-issue" aria-live="polite">
            <div v-if="canConfirm" class="salon-actions">
              <RiftButton variant="primary" :disabled="busy" @click="confirmResult">Confirmer le résultat</RiftButton>
              <RiftButton variant="ghost" :disabled="busy" @click="disputeResult">Contester</RiftButton>
            </div>
            <p v-else-if="match.status === 'disputed'" class="salon-note">
              Résultat contesté : cette partie est exclue des
              <RouterLink class="salon-link" to="/statistiques">statistiques</RouterLink>.
            </p>
            <p v-else-if="match.status === 'confirmed' || match.status === 'abandoned'" class="salon-note">
              Partie close — elle apparaît dans votre
              <RouterLink class="salon-link" to="/historique">historique</RouterLink>.
            </p>
          </div>
        </RiftPanel>
      </template>
    </template>
  </div>
</template>

<style scoped>
.salon {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
.salon p {
  margin: 0;
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.salon-title {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: var(--space-2) var(--space-4);
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.salon-code {
  font-family: var(--font-label);
  font-size: 0.6em;
  font-weight: 600;
  letter-spacing: 0.18em;
  color: var(--bronze-light);
}
.salon-note {
  color: var(--ink-muted);
}
.salon-error {
  color: var(--blood-text);
}
.salon-faint {
  color: var(--ink-muted);
}
.salon-link {
  color: var(--bronze-light);
}
.salon-link:focus-visible,
.salon-pseudo:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
/* Les pseudos et noms longs sont tronqués par une ellipse, jamais renvoyés à la ligne. */
.salon-ellipse {
  display: block;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ---------- Sans code ---------- */
.salon-rejoindre {
  display: grid;
  gap: var(--space-4);
  max-width: 640px;
}
.salon-code-form {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: var(--space-3);
}
.salon-code-field {
  flex: 1 1 200px;
}
/* Le code circule en majuscules : la saisie s'affiche déjà ainsi. */
.salon-code-field :deep(.rift-field-input) {
  font-family: var(--font-label);
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

/* ---------- En-tête : deux joueurs face à face ---------- */
.salon-head {
  display: grid;
  gap: var(--space-4);
}
.salon-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2) var(--space-3);
}
.salon-statut,
.salon-format {
  flex: none;
}
.salon-regles {
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.salon-duel {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  align-items: stretch;
  gap: var(--space-4);
}
.salon-contre {
  align-self: center;
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--bronze);
}
.salon-seat {
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--space-2);
  padding: var(--space-4);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  border-left: 3px solid var(--line);
}
.salon-seat-ready {
  border-left-color: var(--bronze-light);
}
.salon-seat-libre {
  justify-content: center;
  border-style: dashed;
}
.salon-who {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  min-width: 0;
}
.salon-pseudo {
  font-family: var(--font-label);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: 0.04em;
  color: var(--ink);
}
a.salon-pseudo:hover {
  color: var(--bronze-light);
}
.salon-hote {
  flex: none;
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.salon-legend {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  min-width: 0;
  color: var(--ink);
}
.salon-deck {
  width: 100%;
  font-size: 14px;
  color: var(--ink);
}
/* La pastille « Prêt » se cale en bas du siège, alignée d'une colonne à l'autre. */
.salon-pret {
  margin-top: auto;
}
.salon-thumb {
  width: 36px;
  height: 36px;
  flex: none;
  border-radius: 50%;
  object-fit: cover;
  background: var(--bg-raised);
  border: 1px solid var(--bronze);
}
.salon-thumb-empty {
  display: inline-block;
  border-style: dashed;
}

/* ---------- Rejoindre ---------- */
.salon-join {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}

/* ---------- Mes choix ---------- */
.salon-choix {
  display: grid;
  gap: var(--space-4);
}
.salon-choix-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: var(--space-4);
  align-items: start;
}
.salon-legend-search {
  display: grid;
  gap: var(--space-2);
}
.salon-legend-results {
  display: grid;
  gap: var(--space-1);
  margin: 0;
  padding: 0;
  list-style: none;
  max-height: 320px;
  overflow-y: auto;
}
/* Bouton de résultat entièrement redéfini : rien ne doit venir de main.css. */
.salon-legend-option {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  min-height: 44px;
  padding: var(--space-1) var(--space-3);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  border-radius: 0;
  box-shadow: none;
  color: var(--ink);
  font: inherit;
  text-align: left;
  cursor: pointer;
  transition: border-color var(--t-fast);
}
.salon-legend-option:hover {
  border-color: var(--bronze);
}
.salon-legend-option:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.salon-legend-option:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.salon-legend-option .salon-thumb {
  width: 32px;
  height: 32px;
}
.salon-deck-field {
  display: grid;
  gap: var(--space-1);
}
.salon-label {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.salon-select-box {
  position: relative;
  display: block;
}
/* Chevron dessiné au filet : le select natif perd le sien (appearance: none). */
.salon-select-box::after {
  content: "";
  position: absolute;
  top: 50%;
  right: var(--space-4);
  width: 8px;
  height: 8px;
  border-right: 2px solid var(--bronze-light);
  border-bottom: 2px solid var(--bronze-light);
  transform: translateY(-70%) rotate(45deg);
  pointer-events: none;
}
/* main.css style `select` (fond, arrondi, halo au focus) : on reprend tout. */
.salon-select {
  display: block;
  width: 100%;
  min-height: 44px;
  padding: 0 calc(var(--space-6) + var(--space-2)) 0 var(--space-3);
  appearance: none;
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  border-radius: 0;
  box-shadow: none;
  color: var(--ink);
  font: inherit;
  outline: none;
  cursor: pointer;
  transition: border-color var(--t-fast);
}
.salon-select:focus {
  border-color: var(--bronze-light);
  box-shadow: none;
}
.salon-select:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.salon-select:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.salon-ready {
  justify-self: start;
}

/* ---------- Notice et actions ---------- */
.salon-notice-text {
  color: var(--ink);
}
.salon-notice {
  padding-block: var(--space-4);
}
.salon-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
/* Action destructrice : filet et encre rouges, survol distinct d'un bouton principal. */
.salon-actions .salon-danger {
  border-color: var(--blood);
  color: var(--blood-text);
}
.salon-actions .salon-danger:hover {
  border-color: var(--blood-bright);
  background: color-mix(in srgb, var(--blood) 18%, transparent);
  color: var(--ink);
}

/* ---------- Partie ---------- */
.salon-partie {
  display: grid;
  gap: var(--space-3);
}
.salon-partie-status {
  font-family: var(--font-label);
  font-size: 15px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.salon-scores {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--space-4);
  margin: 0;
  padding: 0;
  list-style: none;
}
.salon-score-side {
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  padding: var(--space-3);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  text-align: center;
}
.salon-score-who {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  max-width: 100%;
  min-width: 0;
}
.salon-score {
  font-family: var(--font-display);
  font-size: 40px;
  font-weight: 700;
  line-height: 1.1;
  color: var(--ink);
}
.salon-manches {
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.salon-confirme {
  margin-top: var(--space-1);
}
.salon-issue {
  display: grid;
  gap: var(--space-2);
}

@media (max-width: 560px) {
  /* Les deux sièges s'empilent, le « contre » entre eux. */
  .salon-duel {
    grid-template-columns: minmax(0, 1fr);
    gap: var(--space-2);
  }
  .salon-contre {
    justify-self: center;
  }
}
</style>
