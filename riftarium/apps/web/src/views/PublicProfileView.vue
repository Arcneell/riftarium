<script setup>
import { computed, onMounted, ref } from "vue"
import { useRoute } from "vue-router"
import { cardThumb, session } from "../api.js"
import DeckCard from "../decks/DeckCard.vue"
import MatchRow from "../play/MatchRow.vue"
import ProfileAchievements from "../social/ProfileAchievements.vue"
import ProfileHero from "../social/ProfileHero.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import RiftStat from "../ui/RiftStat.vue"
import CardTile from "../ui/CardTile.vue"
import { formatWinRate, winRatePercent } from "../play.js"
import { applySeo } from "../seo.js"
import {
  followUser,
  formatMemberSince,
  getPublicProfile,
  getUserCollection,
  getUserHistory,
  groupAchievements,
  setPercent,
  unfollowUser,
  unlockedFirst
} from "../social.js"

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
const achievementGroups = computed(() => groupAchievements(unlockedFirst(profile.value?.achievements)))
const totals = computed(() => profile.value?.stats?.totals || null)
const summary = computed(() => profile.value?.collection_summary || null)
const byLegend = computed(() => profile.value?.stats?.by_legend || [])
const decks = computed(() => profile.value?.decks || [])

/* Mentions sous la bio : ancienneté puis compteurs (qui bougent avec le suivi optimiste). */
const heroMeta = computed(() => [
  memberSince.value ? `Membre depuis ${memberSince.value}` : "",
  `${profile.value?.followers_count || 0} abonné(s)`,
  `${profile.value?.following_count || 0} suivi(s)`
])

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
    /* 403 : les duels viennent d'être masqués entre-temps — la section se tait. */
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
      /* Le titre et les métadonnées doivent dire « introuvable », sinon le profil
         précédent reste inscrit dans l'onglet et l'historique. */
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
   arrière si l'API refuse — sans quoi le bouton paraît inerte le temps du aller-retour.
   `followBusy` écarte le double clic : une seule requête part. */
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
  <div class="wrap cards-wrap profil-public">
    <p v-if="error" class="profil-erreur" role="alert">{{ error }}</p>

    <div v-else-if="loading" class="profil-squelette" role="status">
      <span class="sr-only">Chargement du profil…</span>
      <RiftSkeleton block />
      <RiftSkeleton :lines="4" />
    </div>

    <RiftEmpty
      v-else-if="notFound"
      title="Profil introuvable"
      text="Ce profil de joueur n'existe pas ou n'est pas public."
    >
      <RiftButton variant="secondary" size="sm" to="/">Retour à l'accueil</RiftButton>
    </RiftEmpty>

    <template v-else-if="profile">
      <ProfileHero
        :handle="profile.handle"
        :avatar-url="profile.avatar_url || ''"
        :bio="profile.bio || ''"
        :meta="heroMeta"
      >
        <template #actions>
          <RiftButton v-if="profile.is_me" variant="secondary" size="sm" to="/profil">Modifier mon profil</RiftButton>
          <RiftButton
            v-else-if="canFollow"
            :variant="profile.is_followed ? 'ghost' : 'primary'"
            size="sm"
            :aria-pressed="Boolean(profile.is_followed)"
            :disabled="followBusy"
            @click="toggleFollow"
          >
            {{ profile.is_followed ? "Ne plus suivre" : "Suivre" }}
          </RiftButton>
          <RiftButton v-else-if="!session.token" variant="secondary" size="sm" to="/connexion">
            Se connecter pour suivre
          </RiftButton>
        </template>
      </ProfileHero>
      <p v-if="followError" class="profil-erreur" role="alert">{{ followError }}</p>

      <!-- Une section masquée par le joueur n'apparaît pas du tout. -->
      <ProfileAchievements
        v-if="shows('show_achievements')"
        data-section="hauts-faits"
        :groups="achievementGroups"
        empty-text="Aucun haut fait débloqué pour l'instant."
      />

      <RiftPanel v-if="shows('show_stats')" data-section="duels" title="Duels">
        <div v-if="totals" class="profil-stats">
          <RiftStat label="Parties jouées" :value="totals.played || 0" />
          <RiftStat label="Victoires" :value="totals.won || 0" />
          <RiftStat label="Défaites" :value="totals.lost || 0" />
          <RiftStat label="Taux de victoire" :value="formatWinRate(totals.win_rate ?? rateOf(totals))" />
        </div>
        <p v-else class="profil-texte">Aucune partie suivie pour l'instant.</p>

        <ul v-if="byLegend.length" class="profil-legendes">
          <li v-for="row in byLegend" :key="row.card_id" class="profil-legende">
            <img
              v-if="row.image_url"
              class="profil-legende-vignette"
              :src="cardThumb(row.image_url, 72)"
              :alt="`Légende : ${row.name}`"
              width="36"
              height="36"
              loading="lazy"
              decoding="async"
            />
            <span v-else class="profil-legende-vignette" aria-hidden="true"></span>
            <span class="profil-legende-nom">{{ row.name }}</span>
            <span class="profil-set-barre" aria-hidden="true">
              <span class="profil-set-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
            </span>
            <span class="profil-legende-bilan">
              {{ row.won }} V / {{ row.lost }} D · {{ formatWinRate(rateOf(row)) }}
            </span>
          </li>
        </ul>

        <p v-if="history.error" class="profil-erreur" role="alert">{{ history.error }}</p>
        <ol v-if="history.items.length" class="profil-duels">
          <MatchRow
            v-for="item in history.items"
            :key="item.match_id"
            :item="item"
            :self="{ handle: profile.handle, avatar_url: profile.avatar_url }"
          />
        </ol>
        <div v-if="historyPages > 1" class="profil-pager">
          <RiftButton variant="ghost" size="sm" :disabled="history.page <= 1" @click="goHistory(history.page - 1)">
            ← Précédent
          </RiftButton>
          <span class="profil-page">page {{ history.page }} / {{ historyPages }}</span>
          <RiftButton
            variant="ghost"
            size="sm"
            :disabled="history.page >= historyPages"
            @click="goHistory(history.page + 1)"
          >
            Suivant →
          </RiftButton>
        </div>
      </RiftPanel>

      <RiftPanel v-if="shows('show_collection')" data-section="collection" title="Collection">
        <div v-if="summary" class="profil-stats">
          <RiftStat label="Cartes uniques" :value="summary.unique_cards || 0" />
          <RiftStat label="Exemplaires" :value="summary.total_cards || 0" />
        </div>
        <ul v-if="summary?.sets?.length" class="profil-sets">
          <li v-for="row in summary.sets" :key="row.set_id" class="profil-set">
            <span class="profil-set-nom">{{ row.name }}</span>
            <span class="profil-set-barre" aria-hidden="true">
              <span
                class="profil-set-fill"
                :class="{ 'profil-set-fill--complet': setPercent(row) >= 100 }"
                :style="{ width: `${setPercent(row)}%` }"
              ></span>
            </span>
            <span class="profil-set-compte">{{ row.owned }} / {{ row.total }}</span>
            <span class="profil-set-pct">{{ setPercent(row) }} %</span>
          </li>
        </ul>
        <p v-else-if="!summary" class="profil-texte">Aucune carte enregistrée pour l'instant.</p>

        <p v-if="collection.error" class="profil-erreur" role="alert">{{ collection.error }}</p>
        <p v-else-if="collection.loading" class="profil-texte" role="status">Chargement de la collection…</p>
        <div v-if="collection.items.length" class="profil-cartes">
          <CardTile
            v-for="item in collection.items"
            :key="item.card.id"
            :card="{ ...item.card, owned_qty: item.total_qty }"
          />
        </div>
        <div v-if="collectionPages > 1" class="profil-pager">
          <RiftButton
            variant="ghost"
            size="sm"
            :disabled="collection.page <= 1"
            @click="goCollection(collection.page - 1)"
          >
            ← Précédent
          </RiftButton>
          <span class="profil-page">page {{ collection.page }} / {{ collectionPages }}</span>
          <RiftButton
            variant="ghost"
            size="sm"
            :disabled="collection.page >= collectionPages"
            @click="goCollection(collection.page + 1)"
          >
            Suivant →
          </RiftButton>
        </div>
      </RiftPanel>

      <RiftPanel v-if="shows('show_decks')" data-section="decks" title="Decks publics">
        <div v-if="decks.length" class="profil-decks-grid">
          <DeckCard v-for="deck in decks" :key="deck.id" readonly :deck="deck" :to="`/decks/${deck.id}`" />
        </div>
        <p v-else class="profil-texte">Aucun deck public pour l'instant.</p>
      </RiftPanel>
    </template>
  </div>
</template>

<style scoped>
.profil-public {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
.profil-public p {
  margin: 0;
}
.profil-erreur {
  color: var(--blood-text);
}
.profil-texte {
  color: var(--ink-muted);
}
.profil-squelette {
  display: grid;
  gap: var(--space-3);
}
.profil-squelette :deep(.rift-skeleton-block) {
  height: 120px;
}
.profil-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: var(--space-3);
}
.profil-duels {
  display: grid;
  gap: var(--space-3);
  margin: var(--space-4) 0 0;
  padding: 0;
  list-style: none;
}

/* ---------- Progression par set (barres du classeur) ---------- */
.profil-sets {
  display: grid;
  gap: var(--space-3);
  margin: var(--space-4) 0 0;
  padding: 0;
  list-style: none;
}
.profil-set {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(80px, 2fr) auto 3.5em;
  align-items: center;
  gap: var(--space-3);
}
.profil-set-nom {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--ink);
}
.profil-set-barre {
  display: block;
  height: 6px;
  background: var(--line);
}
.profil-set-fill {
  display: block;
  height: 100%;
  background: var(--bronze);
}
.profil-set-fill--complet {
  background: var(--bronze-light);
}
.profil-set-compte,
.profil-set-pct {
  font-variant-numeric: tabular-nums;
  color: var(--ink-muted);
}
.profil-set-pct {
  text-align: right;
  color: var(--bronze-light);
}

.profil-legendes {
  display: grid;
  gap: var(--space-3);
  margin: var(--space-4) 0 0;
  padding: 0;
  list-style: none;
}
.profil-legende {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr) minmax(80px, 1fr) auto;
  align-items: center;
  gap: var(--space-3);
}
.profil-legende-vignette {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  object-fit: cover;
  background: var(--bg-sunken);
}
.profil-legende-nom {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--ink);
}
.profil-legende-bilan {
  font-size: 13px;
  color: var(--ink-muted);
}
.profil-cartes {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: var(--space-3);
  margin-top: var(--space-4);
}
.profil-pager {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  margin-top: var(--space-4);
}
.profil-page {
  font-family: var(--font-label);
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}

.profil-decks-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--space-4);
}

@media (max-width: 559px) {
  .profil-set {
    grid-template-columns: minmax(0, 1fr) auto 3.5em;
  }
  .profil-set-barre {
    grid-column: 1 / -1;
    order: 4;
  }
}
</style>
