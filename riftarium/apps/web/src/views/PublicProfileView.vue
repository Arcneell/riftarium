<script setup>
import { computed, onMounted, ref } from "vue"
import { useRoute } from "vue-router"
import { session } from "../api.js"
import DeckCard from "../decks/DeckCard.vue"
import MatchRow from "../play/MatchRow.vue"
import ProfileAchievements from "../social/ProfileAchievements.vue"
import ProfileHero from "../social/ProfileHero.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import RiftStat from "../ui/RiftStat.vue"
import { formatWinRate } from "../play.js"
import { applySeo } from "../seo.js"
import {
  followUser,
  formatMemberSince,
  getPublicProfile,
  getUserHistory,
  groupAchievements,
  setPercent,
  unfollowUser,
  unlockedFirst
} from "../social.js"

/* Les derniers duels seulement : l'historique complet reste sur /historique (le sien). */
const HISTORY_SIZE = 10

const route = useRoute()
const handle = computed(() => String(route.params.handle || ""))

const profile = ref(null)
const loading = ref(true)
const error = ref("")
const notFound = ref(false)

const followBusy = ref(false)
const followError = ref("")

const history = ref({ items: [], error: "" })

const visibility = computed(() => profile.value?.visibility || {})
const shows = (key) => Boolean(visibility.value[key])

const memberSince = computed(() => formatMemberSince(profile.value?.created_at))
const achievementGroups = computed(() => groupAchievements(unlockedFirst(profile.value?.achievements)))
const totals = computed(() => profile.value?.stats?.totals || null)
const summary = computed(() => profile.value?.collection_summary || null)
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

async function loadHistory() {
  history.value = { items: [], error: "" }
  try {
    const payload = await getUserHistory(handle.value, 1, HISTORY_SIZE)
    history.value.items = payload?.items || []
  } catch (e) {
    /* 403 : les duels viennent d'être masqués entre-temps — la section se tait. */
    history.value.error = e.status === 403 ? "" : e.message
  }
}

async function load() {
  loading.value = true
  error.value = ""
  notFound.value = false
  followError.value = ""
  history.value = { items: [], error: "" }
  try {
    profile.value = await getPublicProfile(handle.value)
    applySeo({
      title: `${profile.value.handle} — Profil de joueur`,
      description: `Profil Riftbound de ${profile.value.handle} sur Riftarium : hauts faits, duels, collection et decks.`,
      path: route.path,
      /* Bêta fermée : un profil public reste hors des moteurs de recherche. */
      noindex: true
    })
    if (shows("show_stats")) loadHistory()
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

        <p v-if="history.error" class="profil-erreur" role="alert">{{ history.error }}</p>
        <ol v-if="history.items.length" class="profil-duels">
          <MatchRow
            v-for="item in history.items"
            :key="item.match_id"
            :item="item"
            :self="{ handle: profile.handle, avatar_url: profile.avatar_url }"
          />
        </ol>
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
