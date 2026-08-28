<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, cardThumb } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
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

/* Temps réel par sondage : 5 s côté web (2 s sur mobile, où vit le compteur). */
const POLL_MS = 5000
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
const error = ref("")
const busy = ref(false)

const codeDraft = ref("")
const decks = ref([])
const legendQuery = ref("")
const legendResults = ref([])
const legendSearching = ref(false)

let poller = null
let legendTimer = null

const players = computed(() => [...(room.value?.players || [])].sort((a, b) => (a.seat ?? 0) - (b.seat ?? 0)))
const myPlayer = computed(() => players.value.find((player) => player.user?.id === me.value?.id) || null)
const isHost = computed(() => Boolean(room.value && me.value && room.value.host_id === me.value.id))
/* Deux sièges seulement en v1 : un salon plein ne se rejoint pas. */
const canJoin = computed(() =>
  Boolean(room.value && !myPlayer.value && room.value.status === "open" && players.value.length < 2)
)
const bothReady = computed(() => players.value.length === 2 && players.value.every((player) => player.ready))
const seatLabel = (player) => (room.value && player.user?.id === room.value.host_id ? "Hôte" : "Invité")

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
    error.value = ""
    if (room.value.match_id) await loadMatch(room.value.match_id)
    else match.value = null
  } catch (e) {
    /* Sondage : on garde le dernier état connu plutôt que de vider la page sur un hoquet réseau. */
    if (!silent) {
      error.value = e.message
      room.value = null
    }
  } finally {
    if (!silent) loading.value = false
  }
}

/* Le serveur reste seul juge de l'état : join / leave / cancel / me renvoient le
   RoomOut à jour, on le prend tel quel ; sinon (confirm, dispute) on relit. */
async function run(action) {
  if (busy.value) return
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
  } catch (e) {
    error.value = e.message
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

function pickDeck(event) {
  const value = event.target.value
  return run(async () => {
    const deckId = value ? Number(value) : null
    const current = myPlayer.value?.legend?.id ?? null
    const legendId = deckId ? ((await legendIdOfDeck(deckId)) ?? current) : current
    await updateMe(code.value, { legend_card_id: legendId, deck_id: deckId, ready: false })
  })
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

async function searchLegends(query) {
  legendSearching.value = true
  try {
    const payload = await api(`/api/cards?type=Legend&q=${encodeURIComponent(query)}`)
    const list = Array.isArray(payload) ? payload : payload?.items || []
    legendResults.value = list.slice(0, 12)
  } catch {
    legendResults.value = []
  } finally {
    legendSearching.value = false
  }
}

watch(legendQuery, (value) => {
  clearTimeout(legendTimer)
  const query = value.trim()
  if (!query) {
    legendResults.value = []
    return
  }
  legendTimer = setTimeout(() => searchLegends(query), SEARCH_DEBOUNCE_MS)
})

function openCode() {
  const value = codeDraft.value.trim().toUpperCase()
  if (value) router.push(`/salon/${encodeURIComponent(value)}`)
}

onMounted(async () => {
  try {
    me.value = await api("/api/auth/me")
  } catch {
    /* 401 déjà traité par api() ; sans identité, la page reste en lecture */
  }
  if (!code.value) {
    try {
      current.value = await getCurrent()
    } catch {
      /* reprise indisponible : la saisie du code suffit */
    }
    loading.value = false
    return
  }
  await loadRoom()
  try {
    decks.value = await api("/api/decks/mine")
  } catch {
    /* sans liste de decks, le choix de légende reste possible */
  }
  poller = setInterval(() => {
    if (!settled.value) loadRoom({ silent: true })
  }, POLL_MS)
})

onBeforeUnmount(() => {
  clearInterval(poller)
  clearTimeout(legendTimer)
})
</script>

<template>
  <PageBanner :art="BANNERS.table" title="Salon de jeu" />

  <section>
    <div class="wrap play-page play-room">
      <!-- Sans code : saisie manuelle, pour qui a reçu le code sans le lien. -->
      <div v-if="!code" class="panel play-empty">
        <h3>Rejoindre un salon</h3>
        <p class="muted">
          Saisissez le code à six caractères affiché sur le téléphone de l'hôte, ou ouvrez simplement le lien qu'il vous
          a partagé.
        </p>
        <form class="play-code-form" @submit.prevent="openCode">
          <label class="play-code-label" for="room-code">Code du salon</label>
          <input
            id="room-code"
            v-model="codeDraft"
            type="text"
            class="play-code-input mono"
            maxlength="6"
            autocapitalize="characters"
            autocorrect="off"
            spellcheck="false"
            placeholder="ABC234"
          />
          <button class="btn btn-gold" type="submit" :disabled="!codeDraft.trim()">Ouvrir le salon</button>
        </form>
        <p v-if="current?.room" class="muted">
          Vous avez déjà un salon en cours :
          <RouterLink :to="`/salon/${current.room.code}`">{{ current.room.code }}</RouterLink>
        </p>
      </div>

      <template v-else>
        <p v-if="loading" class="muted">Chargement du salon…</p>
        <p v-else-if="error && !room" class="error">{{ error }}</p>

        <template v-else-if="room">
          <div class="panel play-room-head">
            <p class="mono play-room-code">Salon {{ room.code }}</p>
            <span class="chip play-mode">{{ modeLabel(room.mode) }}</span>
            <span class="chip play-status">{{ roomStatusLabel(room.status) }}</span>
            <span class="mono muted play-room-rules">
              {{ room.victory_score }} points · {{ room.rounds_to_win }} manche(s) gagnante(s)
            </span>
          </div>

          <p v-if="error" class="error">{{ error }}</p>

          <ul class="play-seats">
            <li v-for="player in players" :key="player.seat" class="panel play-seat" :class="{ ready: player.ready }">
              <p class="play-seat-who">
                <UserAvatar :src="player.user?.avatar_url" :handle="player.user?.handle" :size="32" />
                <!-- Le pseudo mène au profil public : de quoi jauger un adversaire inconnu. -->
                <RouterLink v-if="player.user?.handle" :to="profilePath(player.user.handle)">
                  {{ player.user.handle }}
                </RouterLink>
                <span v-else>Compte supprimé</span>
                <span class="chip play-seat-role">{{ seatLabel(player) }}</span>
              </p>
              <div class="play-side-legend">
                <img
                  v-if="player.legend?.image_url"
                  class="play-legend-thumb"
                  :src="cardThumb(player.legend.image_url, 72)"
                  :alt="`Légende : ${player.legend.name}`"
                  width="72"
                  height="72"
                  loading="lazy"
                  decoding="async"
                />
                <span v-else class="play-legend-thumb empty" aria-hidden="true"></span>
                <span class="mono">{{ player.legend?.name || "Légende à choisir" }}</span>
              </div>
              <p class="mono play-seat-deck">{{ player.deck?.name || "Deck à choisir" }}</p>
              <p class="mono play-seat-ready" :class="player.ready ? 'is-ready' : 'muted'">
                {{ player.ready ? "Prêt ✓" : "Pas encore prêt" }}
              </p>
            </li>
            <li v-if="players.length < 2" class="panel play-seat empty">
              <p class="muted">Place libre — en attente d'un adversaire.</p>
            </li>
          </ul>

          <div v-if="canJoin" class="panel play-actions">
            <p class="muted">Ce salon vous attend : rejoignez-le, puis choisissez votre légende et votre deck.</p>
            <button class="btn btn-gold" type="button" :disabled="busy" @click="join">Rejoindre</button>
          </div>

          <p v-else-if="!myPlayer && room.status === 'open'" class="muted">
            Ce salon est complet : les deux places sont prises.
          </p>
          <p v-else-if="!myPlayer" class="muted">Vous ne participez pas à ce salon.</p>

          <!-- Choix perso : uniquement tant que la partie n'est pas lancée. -->
          <div v-if="myPlayer && room.status === 'open'" class="panel play-picker">
            <h3>Mes choix</h3>

            <div class="field">
              <label for="room-legend">Légende</label>
              <input
                id="room-legend"
                v-model="legendQuery"
                type="search"
                inputmode="search"
                autocapitalize="off"
                autocorrect="off"
                spellcheck="false"
                placeholder="Rechercher une légende…"
              />
              <p v-if="legendSearching" class="muted mono">Recherche…</p>
              <ul v-if="legendResults.length" class="play-legend-results">
                <li v-for="card in legendResults" :key="card.id">
                  <button type="button" :disabled="busy" @click="pickLegend(card)">
                    <img
                      v-if="card.image_url"
                      class="play-legend-thumb"
                      :src="cardThumb(card.image_url, 72)"
                      alt=""
                      width="72"
                      height="72"
                      loading="lazy"
                      decoding="async"
                    />
                    <span>{{ card.name }}</span>
                  </button>
                </li>
              </ul>
              <p v-else-if="legendQuery.trim() && !legendSearching" class="muted mono">Aucune légende trouvée.</p>
            </div>

            <div class="field">
              <label for="room-deck">Deck</label>
              <select id="room-deck" :value="myPlayer.deck?.id ?? ''" :disabled="busy" @change="pickDeck">
                <option value="">Sans deck</option>
                <option v-for="deck in decks" :key="deck.id" :value="deck.id">{{ deck.name }}</option>
              </select>
            </div>

            <button
              class="btn"
              :class="myPlayer.ready ? 'btn-ghost' : 'btn-gold'"
              type="button"
              :aria-pressed="myPlayer.ready"
              :disabled="busy"
              @click="toggleReady"
            >
              {{ myPlayer.ready ? "Je ne suis plus prêt" : "Je suis prêt" }}
            </button>
          </div>

          <!-- Le lancement vit sur le téléphone de l'hôte : le compteur y est tenu. -->
          <p v-if="myPlayer && room.status === 'open' && bothReady" class="panel play-notice">
            <template v-if="isHost">Lancez la partie depuis l'application Riftarium sur votre téléphone.</template>
            <template v-else>Tout le monde est prêt : l'hôte lance la partie depuis son téléphone.</template>
          </p>

          <div v-if="myPlayer && room.status === 'open'" class="play-actions-row">
            <button v-if="isHost" class="btn btn-danger" type="button" :disabled="busy" @click="cancel">
              Annuler le salon
            </button>
            <button v-else class="btn btn-ghost" type="button" :disabled="busy" @click="leave">Quitter le salon</button>
          </div>

          <div v-if="match" class="panel play-match">
            <h3>Partie</h3>
            <p class="mono play-match-status">
              {{ matchStatusLabel(match.status) }}
              <span v-if="match.state?.round"> · manche {{ match.state.round }}</span>
              <span v-if="match.state?.turn"> · tour {{ match.state.turn }}</span>
            </p>
            <ul class="play-match-scores">
              <li v-for="player in match.players" :key="player.seat">
                <span class="play-match-name">
                  <UserAvatar :src="player.user?.avatar_url" :handle="player.user?.handle" :size="24" />
                  <RouterLink v-if="player.user?.handle" :to="profilePath(player.user.handle)">
                    {{ player.user.handle }}
                  </RouterLink>
                  <span v-else>Compte supprimé</span>
                </span>
                <b class="play-match-score">{{ player.score }}</b>
                <span v-if="match.mode === 'match'" class="mono muted">{{ player.rounds_won }} manche(s)</span>
                <span v-if="player.confirmed" class="chip play-outcome calm">Confirmé</span>
              </li>
            </ul>
            <p class="muted">
              Le compteur se tient sur le téléphone de l'hôte ; cette page suit le score en lecture seule.
            </p>
            <div v-if="canConfirm" class="play-actions-row">
              <button class="btn btn-gold" type="button" :disabled="busy" @click="confirmResult">
                Confirmer le résultat
              </button>
              <button class="btn btn-ghost" type="button" :disabled="busy" @click="disputeResult">Contester</button>
            </div>
            <p v-else-if="match.status === 'disputed'" class="muted">
              Résultat contesté : cette partie est exclue des
              <RouterLink to="/statistiques">statistiques</RouterLink>.
            </p>
            <p v-else-if="match.status === 'confirmed' || match.status === 'abandoned'" class="muted">
              Partie close — elle apparaît dans votre <RouterLink to="/historique">historique</RouterLink>.
            </p>
          </div>
        </template>
      </template>
    </div>
  </section>
</template>
