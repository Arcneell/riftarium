<script setup>
import { computed, onBeforeUnmount, reactive, ref, watch } from "vue"
import { api } from "../api.js"
import { BANNERS } from "../banners.js"
import ModalDialog from "../components/ModalDialog.vue"
import PageBanner from "../components/PageBanner.vue"

const TABS = { stats: "Statistiques", users: "Utilisateurs", decks: "Decks" }
const tab = ref("stats")

const PAGE_SIZE = 20

/* Statuts de modération renvoyés par l'API (le POST accepte approved|rejected). */
const MODERATION = {
  pending: { label: "En attente", tone: "is-wait" },
  published: { label: "Publié", tone: "is-ok" },
  approved: { label: "Approuvé", tone: "is-ok" },
  rejected: { label: "Rejeté", tone: "is-ko" }
}
const DECK_STATUSES = [
  { value: "pending", label: "En attente" },
  { value: "published", label: "Publiés" },
  { value: "rejected", label: "Rejetés" },
  { value: "", label: "Tous" }
]
/* Durées de suspension proposées (876000 h ≈ 100 ans : « définitif »). */
const SUSPEND_DURATIONS = [
  { hours: 24, label: "24 heures" },
  { hours: 168, label: "7 jours" },
  { hours: 720, label: "30 jours" },
  { hours: 876000, label: "Définitif" }
]

/* Libellés des rubriques du comptage de fréquentation anonyme (voir router.js). */
const SECTION_LABELS = {
  home: "Accueil",
  cartes: "Cartothèque",
  carte: "Fiche carte",
  regles: "Règles",
  decks: "Mes decks",
  deck: "Fiche deck",
  communaute: "Communauté",
  collection: "Collection",
  scan: "Scan",
  profil: "Profil",
  autre: "Autre"
}

const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short", year: "numeric" }) : ""
const formatDateTime = (iso) =>
  iso
    ? new Date(iso).toLocaleString("fr-FR", {
        day: "numeric",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit"
      })
    : ""

function buildQuery(params) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value !== "" && value !== null && value !== undefined) query.set(key, value)
  }
  return query.toString()
}

/* --- Statistiques --- */
const stats = ref(null)
const statsLoading = ref(false)
const statsError = ref("")

/* Histogramme 30 jours en pur CSS : hauteur des barres proportionnelle au pic. */
const histoMax = computed(() => Math.max(1, ...(stats.value?.visits?.daily || []).map((day) => day.hits)))
const histoHeight = (hits) => Math.max(2, Math.round((hits / histoMax.value) * 100))
const histoDate = (iso) => new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short" })

async function loadStats() {
  statsLoading.value = true
  statsError.value = ""
  try {
    stats.value = await api("/api/admin/stats")
  } catch (e) {
    statsError.value = e.message
  } finally {
    statsLoading.value = false
  }
}

/* --- Utilisateurs --- */
const users = reactive({ q: "", page: 1, total: 0, items: [], loading: false, error: "" })
let usersTimer = null
let usersSeq = 0

async function loadUsers() {
  const seq = ++usersSeq
  users.loading = true
  users.error = ""
  try {
    const data = await api(
      `/api/admin/users?${buildQuery({ q: users.q.trim(), page: users.page, page_size: PAGE_SIZE })}`
    )
    if (seq !== usersSeq) return
    users.total = data.total
    users.items = data.items
    if (users.page > 1 && !data.items.length) users.page = 1
  } catch (e) {
    if (seq === usersSeq) users.error = e.message
  } finally {
    if (seq === usersSeq) users.loading = false
  }
}

function scheduleUsers() {
  clearTimeout(usersTimer)
  usersTimer = setTimeout(loadUsers, 250)
}

const usersPageCount = computed(() => Math.max(1, Math.ceil(users.total / PAGE_SIZE)))

watch(
  () => users.q,
  () => {
    users.page = 1
    scheduleUsers()
  }
)
watch(() => users.page, scheduleUsers)

/* --- Decks --- */
const decks = reactive({
  status: "pending",
  q: "",
  page: 1,
  total: 0,
  size: PAGE_SIZE,
  items: [],
  loading: false,
  error: ""
})
let decksTimer = null
let decksSeq = 0

async function loadDecks() {
  const seq = ++decksSeq
  decks.loading = true
  decks.error = ""
  try {
    const data = await api(
      `/api/admin/decks?${buildQuery({ status: decks.status, q: decks.q.trim(), page: decks.page })}`
    )
    if (seq !== decksSeq) return
    decks.total = data.total
    decks.size = data.size || PAGE_SIZE
    decks.items = data.items
    if (decks.page > 1 && !data.items.length) decks.page = 1
  } catch (e) {
    if (seq === decksSeq) decks.error = e.message
  } finally {
    if (seq === decksSeq) decks.loading = false
  }
}

function scheduleDecks() {
  clearTimeout(decksTimer)
  decksTimer = setTimeout(loadDecks, 250)
}

const decksPageCount = computed(() => Math.max(1, Math.ceil(decks.total / decks.size)))

function setDeckStatus(status) {
  if (decks.status === status) return
  decks.status = status
  decks.page = 1
  loadDecks()
}

watch(
  () => decks.q,
  () => {
    decks.page = 1
    scheduleDecks()
  }
)
watch(() => decks.page, scheduleDecks)

/* Chaque activation d'onglet recharge ses données (la file de modération doit rester fraîche). */
watch(
  tab,
  (active) => {
    if (active === "stats") loadStats()
    else if (active === "users") loadUsers()
    else loadDecks()
  },
  { immediate: true }
)

/* --- Actions par ligne : un seul busy à la fois, erreur affichée près de la ligne --- */
const busyKey = ref("")
const rowError = reactive({ key: "", message: "" })

async function runRowAction(key, request, reload) {
  if (busyKey.value) return
  busyKey.value = key
  rowError.key = ""
  rowError.message = ""
  try {
    await request()
    await reload()
  } catch (e) {
    rowError.key = key
    rowError.message = e.message
  } finally {
    busyKey.value = ""
  }
}

function liftSuspension(user) {
  runRowAction(`user:${user.id}`, () => api(`/api/admin/users/${user.id}/suspend`, { method: "DELETE" }), loadUsers)
}

function moderateDeck(deck, status) {
  runRowAction(
    `deck:${deck.id}`,
    () => api(`/api/admin/decks/${deck.id}/moderation`, { method: "POST", body: { status } }),
    loadDecks
  )
}

/* --- Modale de suspension --- */
const suspend = reactive({ user: null, hours: 24, reason: "", busy: false, error: "" })

function openSuspend(user) {
  suspend.user = user
  suspend.hours = 24
  suspend.reason = ""
  suspend.error = ""
}

async function submitSuspend() {
  if (suspend.busy || !suspend.user) return
  suspend.busy = true
  suspend.error = ""
  try {
    await api(`/api/admin/users/${suspend.user.id}/suspend`, {
      method: "POST",
      body: { hours: Number(suspend.hours), reason: suspend.reason.trim() }
    })
    suspend.user = null
    await loadUsers()
  } catch (e) {
    suspend.error = e.message
  } finally {
    suspend.busy = false
  }
}

/* --- Modale de suppression d'un compte (pseudo à retaper) --- */
const removal = reactive({ user: null, confirm: "", busy: false, error: "" })

function openRemoval(user) {
  removal.user = user
  removal.confirm = ""
  removal.error = ""
}

async function submitRemoval() {
  if (removal.busy || !removal.user) return
  if (removal.confirm.trim() !== removal.user.handle) {
    removal.error = "Le pseudo saisi ne correspond pas."
    return
  }
  removal.busy = true
  removal.error = ""
  try {
    await api(`/api/admin/users/${removal.user.id}`, { method: "DELETE" })
    removal.user = null
    await loadUsers()
  } catch (e) {
    removal.error = e.message
  } finally {
    removal.busy = false
  }
}

/* --- Modale de suppression d'un deck --- */
const deckRemoval = reactive({ deck: null, busy: false, error: "" })

function openDeckRemoval(deck) {
  deckRemoval.deck = deck
  deckRemoval.error = ""
}

async function submitDeckRemoval() {
  if (deckRemoval.busy || !deckRemoval.deck) return
  deckRemoval.busy = true
  deckRemoval.error = ""
  try {
    await api(`/api/admin/decks/${deckRemoval.deck.id}`, { method: "DELETE" })
    deckRemoval.deck = null
    await loadDecks()
  } catch (e) {
    deckRemoval.error = e.message
  } finally {
    deckRemoval.busy = false
  }
}

onBeforeUnmount(() => {
  clearTimeout(usersTimer)
  clearTimeout(decksTimer)
})
</script>

<template>
  <PageBanner :art="BANNERS.auth" eyebrow="Administration" title="Console d'administration">
    Chiffres du site, gestion des comptes et file de modération des decks. Réservé aux administrateurs.
  </PageBanner>

  <section style="padding-top: 28px">
    <div class="wrap admin-wrap">
      <div class="filters admin-tabs" role="group" aria-label="Sections d'administration">
        <button
          v-for="(label, key) in TABS"
          :key="key"
          type="button"
          class="filter"
          :aria-pressed="tab === key"
          @click="tab = key"
        >
          {{ label }}
        </button>
      </div>

      <!-- Onglet Statistiques -->
      <div v-if="tab === 'stats'" class="admin-stats">
        <p v-if="statsError" class="error">{{ statsError }}</p>
        <p v-else-if="statsLoading && !stats" class="muted">Chargement des statistiques…</p>

        <template v-if="stats">
          <h3 class="admin-heading">Utilisateurs</h3>
          <div class="stat-row">
            <div class="stat">
              Total<b>{{ stats.users.total }}</b>
            </div>
            <div class="stat">
              Nouveaux (7 j)<b>{{ stats.users.new_7d }}</b>
            </div>
            <div class="stat">
              Nouveaux (30 j)<b>{{ stats.users.new_30d }}</b>
            </div>
            <div class="stat">
              Suspendus<b>{{ stats.users.suspended }}</b>
            </div>
            <div class="stat">
              E-mails vérifiés<b>{{ stats.users.verified }}</b>
            </div>
          </div>

          <h3 class="admin-heading">Decks</h3>
          <div class="stat-row">
            <div class="stat">
              Total<b>{{ stats.decks.total }}</b>
            </div>
            <div class="stat">
              Publics<b>{{ stats.decks.public }}</b>
            </div>
            <div class="stat">
              En attente<b>{{ stats.decks.pending }}</b>
            </div>
            <div class="stat">
              Likes<b>{{ stats.decks.likes_total }}</b>
            </div>
            <div class="stat">
              Vues<b>{{ stats.decks.views_total }}</b>
            </div>
          </div>

          <h3 class="admin-heading">Collection &amp; cartothèque</h3>
          <div class="stat-row">
            <div class="stat">
              Entrées de collection<b>{{ stats.collection.entries_total }}</b>
            </div>
            <div class="stat">
              Exemplaires<b>{{ stats.collection.cards_total }}</b>
            </div>
            <div class="stat">
              Cartes référencées<b>{{ stats.cards.total }}</b>
            </div>
            <div class="stat">
              Sets<b>{{ stats.cards.sets }}</b>
            </div>
          </div>

          <template v-if="stats.visits">
            <h3 class="admin-heading">Fréquentation</h3>
            <div class="stat-row">
              <div class="stat">
                Visites aujourd'hui<b>{{ stats.visits.today_hits }}</b>
              </div>
              <div class="stat">
                Visites (7 j)<b>{{ stats.visits.hits_7d }}</b>
              </div>
              <div class="stat">
                Visites (30 j)<b>{{ stats.visits.hits_30d }}</b>
              </div>
              <div class="stat">
                Uniques aujourd'hui<b>{{ stats.visits.uniques_today }}</b>
              </div>
              <div class="stat">
                Uniques (7 j)<b>{{ stats.visits.uniques_7d }}</b>
              </div>
            </div>

            <div class="admin-panels">
              <div class="panel">
                <h3>Visites par jour (30 jours)</h3>
                <div class="admin-histo" role="img" aria-label="Histogramme des visites quotidiennes sur 30 jours">
                  <div
                    v-for="day in stats.visits.daily"
                    :key="day.day"
                    class="admin-histo-bar"
                    :title="`${histoDate(day.day)} : ${day.hits} visite(s), ${day.uniques} unique(s)`"
                  >
                    <i :style="{ height: `${histoHeight(day.hits)}%` }"></i>
                  </div>
                </div>
                <p v-if="stats.visits.daily.length" class="muted mono admin-histo-range">
                  <span>{{ histoDate(stats.visits.daily[0].day) }}</span>
                  <span>{{ histoDate(stats.visits.daily[stats.visits.daily.length - 1].day) }}</span>
                </p>
                <p v-else class="muted">Pas encore de données.</p>
              </div>
              <div class="panel">
                <h3>Rubriques les plus visitées (7 j)</h3>
                <table v-if="stats.visits.sections_7d.length" class="admin-sections">
                  <thead>
                    <tr>
                      <th>Rubrique</th>
                      <th>Visites</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="row in stats.visits.sections_7d" :key="row.section">
                      <td>{{ SECTION_LABELS[row.section] || row.section }}</td>
                      <td class="num">{{ row.hits }}</td>
                    </tr>
                  </tbody>
                </table>
                <p v-else class="muted">Pas encore de données.</p>
              </div>
            </div>
          </template>

          <div class="admin-panels">
            <div class="panel">
              <h3>Dernières inscriptions</h3>
              <ul class="admin-recent">
                <li v-for="signup in stats.recent.signups" :key="signup.handle + signup.created_at">
                  <b>{{ signup.handle }}</b>
                  <span class="muted mono">{{ formatDate(signup.created_at) }}</span>
                </li>
                <li v-if="!stats.recent.signups.length" class="muted">Aucune inscription récente.</li>
              </ul>
            </div>
            <div class="panel">
              <h3>Derniers decks</h3>
              <ul class="admin-recent">
                <li v-for="deck in stats.recent.decks" :key="deck.id">
                  <RouterLink :to="`/decks/${deck.id}`">{{ deck.name }}</RouterLink>
                  <span class="muted">par {{ deck.owner }}</span>
                  <span class="admin-badge" :class="MODERATION[deck.moderation_status]?.tone">
                    {{ MODERATION[deck.moderation_status]?.label || deck.moderation_status }}
                  </span>
                  <span class="muted mono">{{ formatDate(deck.created_at) }}</span>
                </li>
                <li v-if="!stats.recent.decks.length" class="muted">Aucun deck récent.</li>
              </ul>
            </div>
          </div>
        </template>
      </div>

      <!-- Onglet Utilisateurs -->
      <div v-else-if="tab === 'users'">
        <div class="admin-toolbar">
          <label class="search">
            <Icon name="search" :size="18" />
            <input
              type="search"
              v-model="users.q"
              placeholder="Pseudo ou e-mail…"
              aria-label="Rechercher un utilisateur"
            />
          </label>
          <span class="muted mono admin-count">
            {{ users.total }} compte(s) <span v-if="users.loading">— chargement…</span>
          </span>
        </div>
        <p v-if="users.error" class="error">{{ users.error }}</p>

        <div class="admin-rows">
          <div v-for="user in users.items" :key="user.id" class="admin-row">
            <div class="admin-id">
              <b>{{ user.handle }}</b>
              <span class="muted mono">{{ user.email }}</span>
              <span class="muted mono">inscrit le {{ formatDate(user.created_at) }}</span>
            </div>
            <div class="admin-badges">
              <span v-if="user.is_admin" class="admin-badge is-gold">Admin</span>
              <span v-if="user.email_verified" class="admin-badge is-ok">E-mail vérifié</span>
              <span v-if="user.suspended_until" class="admin-badge is-ko" :title="user.suspension_reason || undefined">
                Suspendu jusqu'au {{ formatDateTime(user.suspended_until) }}
              </span>
            </div>
            <div class="admin-counts muted mono">{{ user.decks_count }} decks · {{ user.collection_count }} cartes</div>
            <div class="admin-actions">
              <button
                type="button"
                class="btn btn-ghost btn-sm"
                :disabled="busyKey === `user:${user.id}`"
                @click="openSuspend(user)"
              >
                Suspendre
              </button>
              <button
                v-if="user.suspended_until"
                type="button"
                class="btn btn-ghost btn-sm"
                :disabled="busyKey === `user:${user.id}`"
                @click="liftSuspension(user)"
              >
                Lever la suspension
              </button>
              <button
                type="button"
                class="btn btn-ghost btn-sm admin-danger"
                :disabled="busyKey === `user:${user.id}`"
                @click="openRemoval(user)"
              >
                Supprimer
              </button>
            </div>
            <p v-if="rowError.key === `user:${user.id}`" class="error admin-row-error">{{ rowError.message }}</p>
          </div>
        </div>
        <p v-if="!users.loading && !users.items.length && !users.error" class="muted">
          Aucun compte ne correspond à la recherche.
        </p>

        <div class="pager" v-if="usersPageCount > 1">
          <button class="btn btn-ghost btn-sm" :disabled="users.page <= 1" @click="users.page--">← Précédent</button>
          <span>page {{ users.page }} / {{ usersPageCount }}</span>
          <button class="btn btn-ghost btn-sm" :disabled="users.page >= usersPageCount" @click="users.page++">
            Suivant →
          </button>
        </div>
      </div>

      <!-- Onglet Decks -->
      <div v-else>
        <div class="admin-toolbar">
          <div class="filters" role="group" aria-label="Statut de modération">
            <button
              v-for="status in DECK_STATUSES"
              :key="status.value"
              type="button"
              class="filter"
              :aria-pressed="decks.status === status.value"
              @click="setDeckStatus(status.value)"
            >
              {{ status.label }}
            </button>
          </div>
          <label class="search">
            <Icon name="search" :size="18" />
            <input type="search" v-model="decks.q" placeholder="Nom du deck…" aria-label="Rechercher un deck" />
          </label>
          <span class="muted mono admin-count">
            {{ decks.total }} deck(s) <span v-if="decks.loading">— chargement…</span>
          </span>
        </div>
        <p v-if="decks.error" class="error">{{ decks.error }}</p>

        <div class="admin-rows">
          <div v-for="deck in decks.items" :key="deck.id" class="admin-row">
            <div class="admin-id">
              <RouterLink :to="`/decks/${deck.id}`" class="admin-deck-name">{{ deck.name }}</RouterLink>
              <span class="muted mono">par {{ deck.owner }}</span>
              <span class="muted mono">mis à jour le {{ formatDate(deck.updated_at) }}</span>
            </div>
            <div class="admin-badges">
              <span class="admin-badge" :class="MODERATION[deck.moderation_status]?.tone">
                {{ MODERATION[deck.moderation_status]?.label || deck.moderation_status }}
              </span>
              <span v-if="deck.is_public" class="admin-badge">Public</span>
            </div>
            <div class="admin-counts muted mono">{{ deck.likes_count }} likes · {{ deck.views_count }} vues</div>
            <div class="admin-actions">
              <button
                v-if="deck.moderation_status !== 'published' && deck.moderation_status !== 'approved'"
                type="button"
                class="btn btn-ghost btn-sm"
                :disabled="busyKey === `deck:${deck.id}`"
                @click="moderateDeck(deck, 'approved')"
              >
                Approuver
              </button>
              <button
                v-if="deck.moderation_status !== 'rejected'"
                type="button"
                class="btn btn-ghost btn-sm"
                :disabled="busyKey === `deck:${deck.id}`"
                @click="moderateDeck(deck, 'rejected')"
              >
                Rejeter
              </button>
              <button
                type="button"
                class="btn btn-ghost btn-sm admin-danger"
                :disabled="busyKey === `deck:${deck.id}`"
                @click="openDeckRemoval(deck)"
              >
                Supprimer
              </button>
            </div>
            <p v-if="rowError.key === `deck:${deck.id}`" class="error admin-row-error">{{ rowError.message }}</p>
          </div>
        </div>
        <p v-if="!decks.loading && !decks.items.length && !decks.error" class="muted">
          {{ decks.status === "pending" ? "Aucun deck en attente de modération." : "Aucun deck ne correspond." }}
        </p>

        <div class="pager" v-if="decksPageCount > 1">
          <button class="btn btn-ghost btn-sm" :disabled="decks.page <= 1" @click="decks.page--">← Précédent</button>
          <span>page {{ decks.page }} / {{ decksPageCount }}</span>
          <button class="btn btn-ghost btn-sm" :disabled="decks.page >= decksPageCount" @click="decks.page++">
            Suivant →
          </button>
        </div>
      </div>
    </div>
  </section>

  <ModalDialog v-if="suspend.user" title="Suspendre le compte" @close="suspend.user = null">
    <p>
      Le compte <strong>{{ suspend.user.handle }}</strong> ne pourra plus se connecter pendant la durée choisie. Le
      motif lui sera affiché.
    </p>
    <form class="modal-form" @submit.prevent="submitSuspend">
      <label>
        Motif (obligatoire)
        <textarea v-model="suspend.reason" rows="3" maxlength="500" required></textarea>
      </label>
      <label>
        Durée
        <select v-model.number="suspend.hours">
          <option v-for="duration in SUSPEND_DURATIONS" :key="duration.hours" :value="duration.hours">
            {{ duration.label }}
          </option>
        </select>
      </label>
      <p v-if="suspend.error" class="error">{{ suspend.error }}</p>
      <div class="modal-actions">
        <button type="button" class="btn btn-ghost" :disabled="suspend.busy" @click="suspend.user = null">
          Annuler
        </button>
        <button type="submit" class="btn btn-danger" :disabled="suspend.busy">
          {{ suspend.busy ? "Suspension…" : "Suspendre" }}
        </button>
      </div>
    </form>
  </ModalDialog>

  <ModalDialog v-if="removal.user" title="Supprimer le compte" @close="removal.user = null">
    <p>
      Cette action est irréversible : le compte, sa collection et ses decks seront effacés. Saisissez le pseudo
      <strong>{{ removal.user.handle }}</strong> pour confirmer.
    </p>
    <form class="modal-form" @submit.prevent="submitRemoval">
      <label>
        Pseudo
        <input type="text" v-model="removal.confirm" autocomplete="off" required />
      </label>
      <p v-if="removal.error" class="error">{{ removal.error }}</p>
      <div class="modal-actions">
        <button type="button" class="btn btn-ghost" :disabled="removal.busy" @click="removal.user = null">
          Annuler
        </button>
        <button type="submit" class="btn btn-danger" :disabled="removal.busy">
          {{ removal.busy ? "Suppression…" : "Supprimer définitivement" }}
        </button>
      </div>
    </form>
  </ModalDialog>

  <ModalDialog v-if="deckRemoval.deck" title="Supprimer le deck" @close="deckRemoval.deck = null">
    <p>
      Le deck <strong>{{ deckRemoval.deck.name }}</strong> de {{ deckRemoval.deck.owner }} sera supprimé définitivement.
    </p>
    <p v-if="deckRemoval.error" class="error">{{ deckRemoval.error }}</p>
    <div class="modal-actions">
      <button type="button" class="btn btn-ghost" :disabled="deckRemoval.busy" @click="deckRemoval.deck = null">
        Annuler
      </button>
      <button type="button" class="btn btn-danger" :disabled="deckRemoval.busy" @click="submitDeckRemoval">
        {{ deckRemoval.busy ? "Suppression…" : "Supprimer" }}
      </button>
    </div>
  </ModalDialog>
</template>
