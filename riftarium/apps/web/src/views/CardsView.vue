<script setup>
import { computed, onMounted, ref, watch } from "vue"
import { api } from "../api.js"
import ActiveFilters from "../cards/ActiveFilters.vue"
import CardFilters from "../cards/CardFilters.vue"
import { cardsQuery } from "../cardText.js"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { useScrollMemory } from "../composables/useScrollMemory.js"
import CardTile from "../ui/CardTile.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

/* Cartothèque Forgée : filtres en panneau (feuille sur petit écran), filtres actifs en
   puces, grille de vignettes. L'état des filtres vit dans l'URL. */
const { restoreScroll } = useScrollMemory()
const breakpoint = useBreakpoint()
const desktop = computed(() => breakpoint.value === "desktop")

const grid = ref(null)
const { tileMin, size } = useGridMeasure(grid)
let firstLoad = true

const { state, result, loading, error, activeCount, pageCount, setFilter, reset, load, scheduleLoad } =
  useQuerySyncedFilters(
    {
      q: { kind: "text" },
      set_id: { kind: "list", param: "set" },
      type: { kind: "list" },
      domain: { kind: "list" },
      rarity: { kind: "list" },
      energy: { kind: "list" },
      page: { kind: "page" }
    },
    {
      fetcher: (filters) => api(`/api/cards?${cardsQuery(filters, size.value)}`),
      pageSize: size,
      onLoaded: () => {
        if (firstLoad) {
          firstLoad = false
          restoreScroll()
        }
      }
    }
  )

const sets = ref([])
const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))
const panelOpen = ref(true)
const sheetOpen = ref(false)

/* La saisie de `q` passe aussi par setFilter : l’état change, le watcher de signature du composable
   débounce le chargement et ramène à la page 1. */
function update(key, value) {
  setFilter(key, value)
}

watch(size, () => {
  if (state.page > pageCount.value) state.page = 1
  else scheduleLoad()
})

onMounted(async () => {
  load()
  try {
    sets.value = await api("/api/sets")
  } catch {
    /* filtre des sets indisponible : les autres facettes restent utilisables */
  }
})
</script>

<template>
  <section class="cards-page" :class="{ 'with-panel': desktop && panelOpen }">
    <header class="cards-head">
      <div>
        <h1>Cartes</h1>
        <p class="cards-count">{{ result.total }} carte{{ result.total > 1 ? "s" : "" }}</p>
      </div>
      <RiftButton v-if="desktop" variant="ghost" size="sm" @click="panelOpen = !panelOpen">
        {{ panelOpen ? "Masquer les filtres" : "Filtres" }}
      </RiftButton>
      <RiftButton v-else variant="secondary" size="sm" @click="sheetOpen = true">
        Filtres<template v-if="activeCount"> ({{ activeCount }})</template>
      </RiftButton>
    </header>

    <aside v-if="desktop && panelOpen" class="filters-panel" aria-label="Filtres">
      <CardFilters :state="state" :sets="setOptions" @update="update" />
    </aside>

    <div class="cards-main">
      <ActiveFilters :state="state" :sets="setOptions" @update="update" @reset="reset" />
      <p v-if="error" class="cards-error" role="alert">{{ error }}</p>

      <div v-if="loading && !result.items.length" class="cards-grid" :style="{ '--tile-min': `${tileMin}px` }">
        <RiftSkeleton v-for="n in 12" :key="n" block />
      </div>
      <div
        v-show="result.items.length"
        ref="grid"
        class="cards-grid"
        :class="{ reloading: loading }"
        :style="{ '--tile-min': `${tileMin}px` }"
      >
        <CardTile v-for="card in result.items" :key="card.id" :card="card" />
      </div>

      <RiftEmpty v-if="!loading && !error && !result.items.length" title="Aucune carte ne correspond aux filtres">
        <RiftButton v-if="activeCount" variant="secondary" size="sm" @click="reset">
          Réinitialiser les filtres
        </RiftButton>
      </RiftEmpty>

      <nav v-if="pageCount > 1" class="cards-pager" aria-label="Pagination">
        <RiftButton variant="ghost" size="sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</RiftButton>
        <span>page {{ state.page }} / {{ pageCount }}</span>
        <RiftButton variant="ghost" size="sm" :disabled="state.page >= pageCount" @click="state.page++">
          Suivant →
        </RiftButton>
      </nav>
    </div>
  </section>

  <RiftSheet v-if="sheetOpen && !desktop" title="Filtres" @close="sheetOpen = false">
    <CardFilters :state="state" :sets="setOptions" @update="update" />
    <div class="sheet-foot">
      <RiftButton block @click="sheetOpen = false">Voir les {{ result.total }} cartes</RiftButton>
    </div>
  </RiftSheet>
</template>

<style scoped>
.cards-page {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  grid-template-areas: "head" "main";
  gap: var(--space-5);
  padding: var(--space-6);
}
.cards-page.with-panel {
  grid-template-columns: 280px minmax(0, 1fr);
  grid-template-areas: "head head" "panel main";
}
.cards-head {
  grid-area: head;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--space-4);
}
.cards-head h1 {
  margin: 0;
  font-size: clamp(28px, 4vw, 40px);
  text-transform: uppercase;
  background: none;
  color: var(--ink);
  animation: none;
}
.cards-count {
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.filters-panel {
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
.cards-main {
  grid-area: main;
  display: grid;
  gap: var(--space-4);
  align-content: start;
}
.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(var(--tile-min, 180px), 1fr));
  gap: var(--space-4);
  transition: opacity var(--t-base);
}
.cards-grid.reloading {
  opacity: 0.55;
}
.cards-error {
  color: var(--blood-text);
}
.cards-pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  font-family: var(--font-label);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.sheet-foot {
  position: sticky;
  bottom: 0;
  margin-top: var(--space-4);
  padding-top: var(--space-3);
  background: var(--bg-raised);
}
@media (max-width: 767px) {
  .cards-page {
    padding: var(--space-4);
  }
}
</style>
