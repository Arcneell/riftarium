<script setup>
import { computed, onMounted, ref, watch } from "vue"
import { useRouter } from "vue-router"
import { api, session } from "../api.js"
import { csvJoin } from "../cardText.js"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import CommunityFilters from "../decks/CommunityFilters.vue"
import DeckCard from "../decks/DeckCard.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

const SORT_VALUES = ["likes", "views", "recent"]

const router = useRouter()
const size = 20
const breakpoint = useBreakpoint()
const desktop = computed(() => breakpoint.value === "desktop")

const { state, result, loading, error, activeCount, pageCount, setFilter, reset, load } = useQuerySyncedFilters(
  {
    q: { kind: "text" },
    legend: { kind: "list" },
    domain: { kind: "list" },
    format: { kind: "list" },
    /* Le tri n'est pas un filtre : hors compteur et épargné par la remise à zéro. */
    sort: { kind: "enum", values: SORT_VALUES, default: "likes", reset: false },
    liked: { kind: "flag" },
    buildable: { kind: "flag" },
    page: { kind: "page" }
  },
  {
    fetcher: () => api(`/api/community/decks?${communityQuery()}`),
    pageSize: size
  }
)

const legends = ref([])
const grid = ref(null)
const sheetOpen = ref(false)

const sheetLabel = computed(() => {
  if (!result.value.total) return "Aucun deck"
  return result.value.total === 1 ? "Voir le deck" : `Voir les ${result.value.total} decks`
})

watch(desktop, (isDesktop) => {
  if (isDesktop) sheetOpen.value = false
})

/* Retour en haut de la grille au changement de page. */
watch(
  () => state.page,
  () => grid.value?.scrollIntoView?.({ block: "start" })
)

function communityQuery() {
  const params = new URLSearchParams({ page: String(state.page), size: String(size), sort: state.sort })
  if (state.q) params.set("q", state.q)
  if (state.legend.length) params.set("legend", csvJoin(state.legend))
  if (state.domain.length) params.set("domain", csvJoin(state.domain))
  if (state.format.length) params.set("format", csvJoin(state.format))
  if (state.liked) params.set("liked", "1")
  if (state.buildable) params.set("buildable", "1")
  return params
}

function toggleLiked() {
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: "/communaute?liked=1" } })
    return
  }
  setFilter("liked", !state.liked)
}

/* Un like par deck à la fois : sans cette garde, deux clics rapides envoyaient
   deux POST qui s'annulaient l'un l'autre. */
const likeBusy = ref(new Set())

async function toggleLike(deck) {
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: "/communaute" } })
    return
  }
  if (likeBusy.value.has(deck.id)) return
  likeBusy.value = new Set(likeBusy.value).add(deck.id)
  try {
    const payload = await api(`/api/decks/${deck.id}/like`, { method: "POST" })
    deck.likes = payload.likes
    deck.liked_by_me = payload.liked_by_me
    if (state.liked && !payload.liked_by_me) {
      result.value.items = result.value.items.filter((item) => item.id !== deck.id)
      result.value.total = Math.max(0, result.value.total - 1)
    }
  } catch (e) {
    error.value = e.message
  } finally {
    const next = new Set(likeBusy.value)
    next.delete(deck.id)
    likeBusy.value = next
  }
}

onMounted(async () => {
  load()
  try {
    legends.value = await api("/api/community/legends")
  } catch {
    /* filtre légendes indisponible */
  }
})
</script>

<template>
  <div class="communaute" :class="{ 'communaute--panel': desktop }">
    <header class="communaute-head">
      <h1 class="communaute-title">Decks de la communauté</h1>
    </header>

    <aside v-if="desktop" class="communaute-filters" aria-label="Filtres">
      <CommunityFilters
        :state="state"
        :legends="legends"
        :signed-in="Boolean(session.token)"
        @update="setFilter"
        @liked="toggleLiked"
      />
    </aside>

    <div class="communaute-main">
      <div class="communaute-bar">
        <p class="communaute-count" aria-live="polite">
          <template v-if="!(loading && !result.items.length)">{{ result.total }} deck(s)</template>
        </p>
        <div class="communaute-bar-actions">
          <RiftButton v-if="activeCount" variant="ghost" size="sm" @click="reset">Réinitialiser</RiftButton>
          <RiftButton v-if="!desktop" variant="secondary" size="sm" @click="sheetOpen = true">
            Filtres<template v-if="activeCount"> ({{ activeCount }})</template>
          </RiftButton>
        </div>
      </div>

      <p v-if="error" class="communaute-error" role="alert">{{ error }}</p>

      <div ref="grid" class="communaute-grid" :class="{ 'communaute-grid--reloading': loading && result.items.length }">
        <template v-if="loading && !result.items.length">
          <RiftSkeleton v-for="n in 6" :key="n" class="communaute-skeleton" block />
        </template>
        <template v-else>
          <DeckCard
            v-for="deck in result.items"
            :key="deck.id"
            community
            :deck="deck"
            :like-busy="likeBusy.has(deck.id)"
            :to="`/decks/${deck.id}`"
            @like="toggleLike"
          />
        </template>
      </div>

      <RiftEmpty v-if="!loading && !error && !result.items.length" title="Aucun deck ne correspond">
        <RiftButton v-if="activeCount" variant="secondary" size="sm" @click="reset">
          Réinitialiser les filtres
        </RiftButton>
        <RiftButton variant="primary" size="sm" to="/decks">Créer un deck</RiftButton>
      </RiftEmpty>

      <nav v-if="pageCount > 1" class="communaute-pager" aria-label="Pagination">
        <RiftButton variant="ghost" size="sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</RiftButton>
        <span>page {{ state.page }} / {{ pageCount }}</span>
        <RiftButton variant="ghost" size="sm" :disabled="state.page >= pageCount" @click="state.page++">
          Suivant →
        </RiftButton>
      </nav>
    </div>
  </div>

  <RiftSheet v-if="sheetOpen && !desktop" title="Filtres" @close="sheetOpen = false">
    <CommunityFilters
      :state="state"
      :legends="legends"
      :signed-in="Boolean(session.token)"
      @update="setFilter"
      @liked="toggleLiked"
    />
    <div class="communaute-sheet-foot">
      <RiftButton block @click="sheetOpen = false">{{ sheetLabel }}</RiftButton>
    </div>
  </RiftSheet>
</template>

<style scoped>
.communaute {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  grid-template-areas: "head" "main";
  gap: var(--space-4);
  padding: var(--space-6);
}
.communaute--panel {
  grid-template-columns: 280px minmax(0, 1fr);
  grid-template-areas: "head head" "panel main";
}
.communaute-head {
  grid-area: head;
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.communaute-title {
  margin: 0;
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 700;
  text-transform: uppercase;
  background: none;
  color: var(--ink);
  animation: none;
}
.communaute-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}
.communaute-count {
  margin: 0;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.communaute-bar-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: var(--space-2);
}
.communaute-filters {
  grid-area: panel;
  position: sticky;
  top: calc(var(--topbar-h) + var(--space-4));
  align-self: start;
  max-height: calc(100dvh - var(--topbar-h) - var(--space-6));
  overflow-y: auto;
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.communaute-main {
  grid-area: main;
  display: grid;
  gap: var(--space-4);
  align-content: start;
}
.communaute-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: var(--space-4);
  transition: opacity var(--t-base);
}
.communaute-grid--reloading {
  opacity: 0.55;
}
@media (max-width: 560px) {
  .communaute-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
.communaute-skeleton :deep(.rift-skeleton-block) {
  height: auto;
  aspect-ratio: 5 / 7;
}
.communaute-error {
  margin: 0;
  color: var(--blood-text);
}
.communaute-pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  font-family: var(--font-label);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.communaute-sheet-foot {
  position: sticky;
  bottom: 0;
  margin-top: var(--space-4);
  padding-top: var(--space-3);
  background: var(--bg-raised);
}
@media (max-width: 767px) {
  .communaute {
    padding: var(--space-4);
  }
}
</style>
