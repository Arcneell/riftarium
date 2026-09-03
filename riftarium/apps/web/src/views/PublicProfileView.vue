<script setup>
import { computed, onMounted, ref } from "vue"
import { useRoute } from "vue-router"
import { cardThumb, session } from "../api.js"
import { BANNERS } from "../banners.js"
import AchievementMedal from "../components/AchievementMedal.vue"
import CardTile from "../components/CardTile.vue"
import DeckBox from "../components/DeckBox.vue"
import MatchRow from "../components/MatchRow.vue"
import PageBanner from "../components/PageBanner.vue"
import UserAvatar from "../components/UserAvatar.vue"
import { formatWinRate, winRatePercent } from "../play.js"
import { applySeo } from "../seo.js"
import {
  followUser,
  formatMemberSince,
  formatUnlockedAt,
  getPublicProfile,
  getUserCollection,
  getUserHistory,
  setPercent,
  tierLabel,
  unfollowUser,
  unlockedFirst
} from "../social.js"
import NotFoundView from "./NotFoundView.vue"

const COLLECTION_SIZE = 24
const HISTORY_SIZE = 10

const route = useRoute()
const handle = computed(() => String(route.params.handle || ""))

const profile = ref(null)
const loading = ref(true)
const error = ref("")
const notFound = ref(false)

const followBusy = ref(false)
const followError = ref("")

const collection = ref({ items: [], total: 0, page: 1, loading: false, error: "" })
const history = ref({ items: [], total: 0, page: 1, loading: false, error: "" })

const visibility = computed(() => profile.value?.visibility || {})
const shows = (key) => Boolean(visibility.value[key])

const memberSince = computed(() => formatMemberSince(profile.value?.created_at))
const achievements = computed(() => unlockedFirst(profile.value?.achievements))
const totals = computed(() => profile.value?.stats?.totals || null)
const byLegend = computed(() => profile.value?.stats?.by_legend || [])
const summary = computed(() => profile.value?.collection_summary || null)
const decks = computed(() => profile.value?.decks || [])

/* Le contrat ne chiffre pas le taux : il se déduit de J / G, comme sur /statistiques. */
const rateOf = (row) => (row?.played ? row.won / row.played : null)

/* Suivre n'a de sens que connecté, et jamais soi-même (l'API renvoie 409). */
const canFollow = computed(() => Boolean(session.token && profile.value && !profile.value.is_me))

const collectionPages = computed(() => Math.max(1, Math.ceil(collection.value.total / COLLECTION_SIZE)))
const historyPages = computed(() => Math.max(1, Math.ceil(history.value.total / HISTORY_SIZE)))

async function loadCollection(page = 1) {
  collection.value.loading = true
  collection.value.error = ""
  try {
    const payload = await getUserCollection(handle.value, { page, size: COLLECTION_SIZE })
    collection.value.items = payload?.items || []
    collection.value.total = payload?.total ?? collection.value.items.length
    collection.value.page = page
  } catch (e) {
    /* 403 : la collection vient d'être masquée entre-temps — la section se tait. */
    collection.value.items = []
    collection.value.total = 0
    collection.value.error = e.status === 403 ? "" : e.message
  } finally {
    collection.value.loading = false
  }
}

async function loadHistory(page = 1) {
  history.value.loading = true
  history.value.error = ""
  try {
    const payload = await getUserHistory(handle.value, page, HISTORY_SIZE)
    history.value.items = payload?.items || []
    history.value.total = payload?.total ?? history.value.items.length
    history.value.page = page
  } catch (e) {
    history.value.items = []
    history.value.total = 0
    history.value.error = e.status === 403 ? "" : e.message
  } finally {
    history.value.loading = false
  }
}

function goCollection(next) {
  if (next < 1 || next > collectionPages.value || collection.value.loading) return
  loadCollection(next)
}

function goHistory(next) {
  if (next < 1 || next > historyPages.value || history.value.loading) return
  loadHistory(next)
}

async function load() {
  loading.value = true
  error.value = ""
  notFound.value = false
  followError.value = ""
  collection.value = { items: [], total: 0, page: 1, loading: false, error: "" }
  history.value = { items: [], total: 0, page: 1, loading: false, error: "" }
  try {
    profile.value = await getPublicProfile(handle.value)
    applySeo({
      title: `${profile.value.handle} — Profil de joueur`,
      description: `Profil Riftbound de ${profile.value.handle} sur Riftarium : hauts faits, duels, collection et decks.`,
      path: route.path,
      /* Bêta fermée : un profil public reste hors des moteurs de recherche. */
      noindex: true
    })
    if (shows("show_collection")) loadCollection(1)
    if (shows("show_stats")) loadHistory(1)
  } catch (e) {
    profile.value = null
    if (e.status === 404) {
      notFound.value = true
      /* La page rendue est la 404 du site : le titre et les métadonnées doivent le
         dire, sinon le profil précédent reste inscrit dans l'onglet et l'historique. */
      applySeo({
        title: "Profil introuvable",
        description: "Ce profil de joueur n'existe pas ou n'est pas public.",
        path: route.path,
        noindex: true
      })
    } else error.value = e.message
  } finally {
    loading.value = false
  }
}

/* Bascule optimiste : l'état et le compteur suivent le clic, et reviennent en
   arrière si l'API refuse — sans quoi le bouton paraît inerte le temps du aller-retour. */
async function toggleFollow() {
  if (followBusy.value || !profile.value) return
  followBusy.value = true
  followError.value = ""
  const wasFollowed = Boolean(profile.value.is_followed)
  const step = wasFollowed ? -1 : 1
  profile.value.is_followed = !wasFollowed
  profile.value.followers_count = Math.max(0, (profile.value.followers_count || 0) + step)
  try {
    await (wasFollowed ? unfollowUser(handle.value) : followUser(handle.value))
  } catch (e) {
    profile.value.is_followed = wasFollowed
    profile.value.followers_count = Math.max(0, (profile.value.followers_count || 0) - step)
    followError.value = e.message
  } finally {
    followBusy.value = false
  }
}

/* Pas de `watch` sur le pseudo : App.vue clef la RouterView sur le chemin, donc
   passer d'un profil à l'autre remonte le composant (onMounted refait le travail). */
onMounted(load)
</script>

<template>
  <NotFoundView v-if="notFound" />

  <template v-else>
    <PageBanner :art="BANNERS.auth" :title="handle ? `Profil de ${handle}` : 'Profil de joueur'" />

    <section>
      <div class="wrap profile-public">
        <p v-if="error" class="error">{{ error }}</p>
        <p v-else-if="loading" class="muted">Chargement du profil…</p>

        <template v-else-if="profile">
          <div class="panel profile-hero">
            <UserAvatar :src="profile.avatar_url" :handle="profile.handle" :size="96" />
            <div class="profile-hero-body">
              <h1>{{ profile.handle }}</h1>
              <p v-if="profile.bio" class="profile-bio">{{ profile.bio }}</p>
              <p v-else class="muted mono">Pas encore de bio.</p>
              <p class="muted mono profile-since">
                <span v-if="memberSince">Membre depuis {{ memberSince }}</span>
                <span class="profile-follow-counts">
                  {{ profile.followers_count || 0 }} abonné(s) · {{ profile.following_count || 0 }} suivi(s)
                </span>
              </p>
            </div>
            <div class="profile-hero-actions">
              <RouterLink v-if="profile.is_me" class="btn btn-ghost btn-sm" to="/profil">
                Modifier mon profil
              </RouterLink>
              <button
                v-else-if="canFollow"
                type="button"
                class="btn btn-sm"
                :class="profile.is_followed ? 'btn-ghost' : 'btn-gold'"
                :aria-pressed="Boolean(profile.is_followed)"
                :disabled="followBusy"
                @click="toggleFollow"
              >
                {{ profile.is_followed ? "Ne plus suivre" : "Suivre" }}
              </button>
              <RouterLink v-else-if="!session.token" class="btn btn-ghost btn-sm" to="/connexion">
                Se connecter pour suivre
              </RouterLink>
            </div>
          </div>
          <p v-if="followError" class="error">{{ followError }}</p>

          <!-- Hauts faits : seuls les débloqués sont publiés. -->
          <div class="panel profile-section">
            <h2>Hauts faits</h2>
            <template v-if="shows('show_achievements')">
              <ul v-if="achievements.length" class="medal-grid">
                <li v-for="item in achievements" :key="item.key" class="medal" :class="`tier-${item.tier || 'bronze'}`">
                  <AchievementMedal :achievement-key="item.key" :icon="item.icon" :tier="item.tier" />
                  <span class="medal-body">
                    <b>{{ item.title }}</b>
                    <span class="muted">{{ item.description }}</span>
                    <span class="mono medal-meta">
                      {{ tierLabel(item.tier) }}
                      <template v-if="formatUnlockedAt(item.unlocked_at)">
                        · {{ formatUnlockedAt(item.unlocked_at) }}
                      </template>
                    </span>
                  </span>
                </li>
              </ul>
              <p v-else class="muted">Aucun haut fait débloqué pour l'instant.</p>
            </template>
            <p v-else class="muted profile-hidden">
              Masqué par ce joueur.
              <RouterLink v-if="profile.is_me" to="/profil">Modifier ma confidentialité</RouterLink>
            </p>
          </div>

          <!-- Duels : totaux, meilleures légendes, puis l'historique paginé. -->
          <div class="panel profile-section">
            <h2>Duels</h2>
            <template v-if="shows('show_stats')">
              <div v-if="totals" class="stat-row">
                <div class="stat">
                  Parties jouées
                  <b>{{ totals.played || 0 }}</b>
                </div>
                <div class="stat">
                  Victoires
                  <b>{{ totals.won || 0 }}</b>
                </div>
                <div class="stat">
                  Défaites
                  <b>{{ totals.lost || 0 }}</b>
                </div>
                <div class="stat">
                  Taux de victoire
                  <b>{{ formatWinRate(totals.win_rate ?? rateOf(totals)) }}</b>
                </div>
              </div>
              <p v-else class="muted">Aucune partie suivie pour l'instant.</p>

              <ul v-if="byLegend.length" class="play-legend-list">
                <li v-for="row in byLegend" :key="row.card_id">
                  <img
                    v-if="row.image_url"
                    class="play-legend-thumb"
                    :src="cardThumb(row.image_url, 72)"
                    :alt="`Légende : ${row.name}`"
                    width="72"
                    height="72"
                    loading="lazy"
                    decoding="async"
                  />
                  <span v-else class="play-legend-thumb empty" aria-hidden="true"></span>
                  <span class="play-legend-name">{{ row.name }}</span>
                  <span class="play-bar">
                    <span class="play-bar-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
                  </span>
                  <span class="mono play-legend-record">
                    {{ row.won }} V / {{ row.lost }} D · {{ formatWinRate(rateOf(row)) }}
                  </span>
                </li>
              </ul>

              <p v-if="history.error" class="error">{{ history.error }}</p>
              <ol v-if="history.items.length" class="play-history profile-history">
                <MatchRow
                  v-for="item in history.items"
                  :key="item.match_id"
                  :item="item"
                  :self="{ handle: profile.handle, avatar_url: profile.avatar_url }"
                />
              </ol>
              <div v-if="historyPages > 1" class="pager">
                <button class="btn btn-ghost btn-sm" :disabled="history.page <= 1" @click="goHistory(history.page - 1)">
                  ← Précédent
                </button>
                <span>page {{ history.page }} / {{ historyPages }}</span>
                <button
                  class="btn btn-ghost btn-sm"
                  :disabled="history.page >= historyPages"
                  @click="goHistory(history.page + 1)"
                >
                  Suivant →
                </button>
              </div>
            </template>
            <p v-else class="muted profile-hidden">
              Masqué par ce joueur.
              <RouterLink v-if="profile.is_me" to="/profil">Modifier ma confidentialité</RouterLink>
            </p>
          </div>

          <!-- Collection : résumé par set, puis la grille paginée. -->
          <div class="panel profile-section">
            <h2>Collection</h2>
            <template v-if="shows('show_collection')">
              <div v-if="summary" class="stat-row">
                <div class="stat">
                  Cartes uniques
                  <b>{{ summary.unique_cards || 0 }}</b>
                </div>
                <div class="stat">
                  Exemplaires
                  <b>{{ summary.total_cards || 0 }}</b>
                </div>
              </div>
              <ul v-if="summary?.sets?.length" class="profile-sets">
                <li v-for="row in summary.sets" :key="row.set_id" class="progress-row">
                  <span class="progress-name">{{ row.name }}</span>
                  <span class="progress-bar"><i :style="{ width: `${setPercent(row)}%` }"></i></span>
                  <span class="progress-count">{{ row.owned }} / {{ row.total }}</span>
                  <span class="progress-missing">{{ setPercent(row) }} %</span>
                </li>
              </ul>

              <p v-if="collection.error" class="error">{{ collection.error }}</p>
              <p v-else-if="collection.loading" class="muted">Chargement de la collection…</p>
              <div v-if="collection.items.length" class="grid-cards profile-cards">
                <CardTile
                  v-for="item in collection.items"
                  :key="item.card.id"
                  :card="{ ...item.card, owned_qty: item.total_qty }"
                />
              </div>
              <div v-if="collectionPages > 1" class="pager">
                <button
                  class="btn btn-ghost btn-sm"
                  :disabled="collection.page <= 1"
                  @click="goCollection(collection.page - 1)"
                >
                  ← Précédent
                </button>
                <span>page {{ collection.page }} / {{ collectionPages }}</span>
                <button
                  class="btn btn-ghost btn-sm"
                  :disabled="collection.page >= collectionPages"
                  @click="goCollection(collection.page + 1)"
                >
                  Suivant →
                </button>
              </div>
            </template>
            <p v-else class="muted profile-hidden">
              Masqué par ce joueur.
              <RouterLink v-if="profile.is_me" to="/profil">Modifier ma confidentialité</RouterLink>
            </p>
          </div>

          <!-- Decks publics : mêmes boîtes que la communauté, sans action. -->
          <div class="panel profile-section">
            <h2>Decks publics</h2>
            <template v-if="shows('show_decks')">
              <div v-if="decks.length" class="deck-boxes">
                <DeckBox v-for="deck in decks" :key="deck.id" readonly :deck="deck" :to="`/decks/${deck.id}`" />
              </div>
              <p v-else class="muted">Aucun deck public pour l'instant.</p>
            </template>
            <p v-else class="muted profile-hidden">
              Masqué par ce joueur.
              <RouterLink v-if="profile.is_me" to="/profil">Modifier ma confidentialité</RouterLink>
            </p>
          </div>
        </template>
      </div>
    </section>
  </template>
</template>
