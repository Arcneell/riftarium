<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue"
import { api, CONDITIONS, LANGS, session } from "../api.js"
import ActiveFilters from "../cards/ActiveFilters.vue"
import CardFilters from "../cards/CardFilters.vue"
import { cardsQuery } from "../cardText.js"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { useScrollMemory } from "../composables/useScrollMemory.js"
import { readDefaults, writeDefaults } from "../collection/collectionDefaults.js"
import QuickCount from "../collection/QuickCount.vue"
import CardTile from "../ui/CardTile.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftChoice from "../ui/RiftChoice.vue"
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
/* Taille de page du dernier chargement lancé : la mesure initiale de la grille change `size`
   avant le premier chargement, ce qui ne doit pas en déclencher un second. */
let loadedSize = null

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
      fetcher: (filters) => {
        loadedSize = size.value
        return api(`/api/cards?${cardsQuery(filters, size.value)}`)
      },
      pageSize: size,
      onLoaded: () => {
        if (firstLoad) {
          firstLoad = false
          restoreScroll()
        }
      }
    }
  )

/* Saisie rapide (membres) : compteur sur chaque vignette. L'interrupteur est mémorisé pour la
   session ; les préférences d'ajout sont un objet réactif unique, passé à tous les compteurs,
   pour que le prochain « + » de n'importe quelle vignette suive le choix de la feuille. */
const QUICK_KEY = "riftarium_quick_add"
function readQuick() {
  try {
    return sessionStorage.getItem(QUICK_KEY) === "1"
  } catch {
    return false
  }
}
const quick = ref(readQuick())
const quickOn = computed(() => quick.value && !!session.token)
function toggleQuick() {
  quick.value = !quick.value
  try {
    sessionStorage.setItem(QUICK_KEY, quick.value ? "1" : "0")
  } catch {
    /* stockage bloqué : l'interrupteur ne survit pas au rechargement */
  }
}
const quickDefaults = reactive(readDefaults())
function setQuickDefaults(patch) {
  Object.assign(quickDefaults, patch)
  writeDefaults({ condition: quickDefaults.condition, lang: quickDefaults.lang })
}
const toOptions = (labels) => Object.entries(labels).map(([value, title]) => ({ value, label: value, title }))
const conditionOptions = toOptions(CONDITIONS)
const langOptions = toOptions(LANGS)
const quickPref = computed(() => `${quickDefaults.condition} · ${LANGS[quickDefaults.lang] ?? quickDefaults.lang}`)
const prefOpen = ref(false)
function onQuickChange({ id, owned_qty }) {
  const item = result.value.items.find((card) => card.id === id)
  if (item) item.owned_qty = owned_qty
}

const sets = ref([])
const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))
/* Libellé du bouton de la feuille, accordé au nombre de résultats. */
const sheetLabel = computed(() => {
  if (!result.value.total) return "Aucune carte"
  return result.value.total === 1 ? "Voir la carte" : `Voir les ${result.value.total} cartes`
})
const panelOpen = ref(true)
const sheetOpen = ref(false)

watch(desktop, (isDesktop) => {
  if (isDesktop) sheetOpen.value = false
})

watch(size, (next) => {
  if (next === loadedSize) return
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
        <p class="cards-count" aria-live="polite">
          <template v-if="!(loading && !result.items.length)">
            {{ result.total }} carte{{ result.total > 1 ? "s" : "" }}
          </template>
        </p>
      </div>
      <div class="cards-head-actions">
        <RiftChip v-if="session.token" label="Saisie rapide" :selected="quickOn" @toggle="toggleQuick" />
        <RiftButton
          v-if="desktop"
          variant="ghost"
          size="sm"
          :aria-expanded="panelOpen"
          aria-controls="filters-panel"
          @click="panelOpen = !panelOpen"
        >
          {{ panelOpen ? "Masquer les filtres" : "Filtres" }}
        </RiftButton>
        <RiftButton v-else variant="secondary" size="sm" @click="sheetOpen = true">
          Filtres<template v-if="activeCount"> ({{ activeCount }})</template>
        </RiftButton>
      </div>
    </header>

    <aside v-if="desktop && panelOpen" id="filters-panel" class="filters-panel" aria-label="Filtres">
      <CardFilters :state="state" :sets="setOptions" @update="setFilter" />
    </aside>

    <div class="cards-main">
      <p v-if="quickOn" class="quick-pref-line">
        Ajouts en
        <button type="button" class="quick-pref" @click="prefOpen = true">{{ quickPref }} · changer</button>
      </p>
      <ActiveFilters :state="state" :sets="setOptions" @update="setFilter" @reset="reset" />
      <p v-if="error" class="cards-error" role="alert">{{ error }}</p>

      <div
        ref="grid"
        class="cards-grid"
        :class="{ reloading: loading && result.items.length }"
        :style="{ '--tile-min': `${tileMin}px` }"
      >
        <template v-if="loading && !result.items.length">
          <RiftSkeleton v-for="n in 12" :key="n" block />
        </template>
        <template v-else>
          <CardTile v-for="card in result.items" :key="card.id" :card="card">
            <template v-if="quickOn" #overlay>
              <QuickCount :card="card" :defaults="quickDefaults" @change="onQuickChange" />
            </template>
          </CardTile>
        </template>
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

  <RiftSheet v-if="prefOpen" title="Ajouts par défaut" @close="prefOpen = false">
    <div class="quick-sheet">
      <RiftChoice
        label="État par défaut"
        :model-value="quickDefaults.condition"
        :options="conditionOptions"
        @update:model-value="setQuickDefaults({ condition: $event })"
      />
      <RiftChoice
        label="Langue par défaut"
        :model-value="quickDefaults.lang"
        :options="langOptions"
        @update:model-value="setQuickDefaults({ lang: $event })"
      />
      <RiftButton block @click="prefOpen = false">Fermer</RiftButton>
    </div>
  </RiftSheet>

  <RiftSheet v-if="sheetOpen && !desktop" title="Filtres" @close="sheetOpen = false">
    <CardFilters :state="state" :sets="setOptions" @update="setFilter" />
    <div class="sheet-foot">
      <RiftButton block @click="sheetOpen = false">{{ sheetLabel }}</RiftButton>
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
  font-weight: 700;
  text-transform: uppercase;
  background: none;
  color: var(--ink);
  animation: none;
}
.cards-head-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: var(--space-2);
}
.quick-pref-line {
  margin: 0;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.08em;
  color: var(--ink-muted);
}
/* Bouton neutralisé localement : main.css stylise `button` globalement. */
.quick-pref {
  min-height: 0;
  padding: 0;
  border: 0;
  border-bottom: 1px dotted var(--bronze);
  border-radius: 0;
  background: none;
  color: var(--bronze-light);
  font: inherit;
  letter-spacing: inherit;
  text-transform: none;
  cursor: pointer;
}
.quick-pref:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.quick-sheet {
  display: grid;
  gap: var(--space-4);
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
/* Les squelettes prennent le ratio d'une vignette plutôt que la hauteur par défaut du bloc. */
.cards-grid :deep(.rift-skeleton-block) {
  height: auto;
  aspect-ratio: 0.716;
}
/* Un terrain (paysage) occupe deux colonnes de la grille. */
.cards-grid :deep(.card-hover.landscape) {
  grid-column: span 2;
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
