<script setup>
import { computed, onMounted, ref } from "vue"
import { api } from "../api.js"
import { cardsQuery } from "../cardText.js"
import CollectionBinder from "../collection/CollectionBinder.vue"
import CollectionInventory from "../collection/CollectionInventory.vue"
import CollectionStats from "../collection/CollectionStats.vue"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { useScrollMemory } from "../composables/useScrollMemory.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import RiftChip from "../ui/RiftChip.vue"

/* Page « Ma collection » : statistiques, commutateur Classeur / Inventaire, puis
   l'affichage choisi. Les filtres de l'inventaire vivent ici (synchronisés à l'URL) ;
   la taille de page remonte de la grille de l'inventaire. */
const { restoreScroll } = useScrollMemory()

const pageSize = ref(30)
let firstLoad = true

const filters = useQuerySyncedFilters(
  {
    q: { kind: "text" },
    set_id: { kind: "list", param: "set" },
    type: { kind: "list" },
    domain: { kind: "list" },
    rarity: { kind: "list" },
    energy: { kind: "list" },
    sort: { kind: "text" },
    page: { kind: "page" },
    /* Deux affichages : le classeur (par défaut) et l'inventaire à plat.
       Synchronisé à l'URL comme un filtre, épargné par « Réinitialiser ». */
    vue: { kind: "enum", values: ["classeur", "inventaire"], default: "classeur", reset: false }
  },
  {
    fetcher: (query) => api(`/api/collection?${cardsQuery(query, pageSize.value)}`),
    initialResult: { total: 0, total_cards: 0, unique_cards: 0, value_eur: null, items: [] },
    pageSize,
    /* La grille filtrée n'existe qu'en mode inventaire : en classeur, un rechargement
       débouncé serait un GET perdu (les statistiques viennent du chargement initial). */
    enabled: () => filters.state.vue === "inventaire",
    onLoaded: (data) => {
      if (filters.state.page > 1 && !data.items.length) filters.state.page = 1
      if (firstLoad) {
        firstLoad = false
        restoreScroll()
      }
    }
  }
)
const { state, result, load } = filters

const sets = ref([])
const progress = ref(null) // { sets: [...], overall: {...} } — null tant que rien n'est chargé

async function loadProgress() {
  try {
    const data = await api("/api/collection/sets")
    if (data && Array.isArray(data.sets) && data.overall) progress.value = data
  } catch {
    /* progression indisponible : la stat reste masquée, le classeur attend */
  }
}

function missingText(row) {
  if (!row.missing) return "set complet"
  const cost = formatEur(row.missing_cost_eur)
  return `il manque ${row.missing} carte(s)${cost ? ` (~${cost})` : ""}`
}

const stats = computed(() => {
  const items = [
    { label: "Cartes", value: result.value.total_cards },
    { label: "Uniques", value: result.value.unique_cards },
    { label: "Valeur estimée", value: formatEur(result.value.value_eur) || null, title: PRICE_NOTE }
  ]
  const overall = progress.value?.overall
  if (overall) {
    const percent = overall.total ? Math.round((overall.owned / overall.total) * 100) : 0
    items.push({ label: "Complétion", value: `${percent} %`, title: missingText(overall) })
  }
  return items
})

const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))

const VIEWS = [
  { value: "classeur", label: "Classeur" },
  { value: "inventaire", label: "Inventaire" }
]

onMounted(async () => {
  load()
  loadProgress()
  try {
    sets.value = await api("/api/sets")
  } catch {
    /* filtre sets indisponible */
  }
})
</script>

<template>
  <section>
    <div class="wrap cards-wrap collection-page">
      <h1 class="collection-page-title">Ma collection</h1>

      <CollectionStats :items="stats" />

      <div class="collection-page-switch" role="group" aria-label="Affichage de la collection">
        <RiftChip
          v-for="view in VIEWS"
          :key="view.value"
          :label="view.label"
          :selected="state.vue === view.value"
          @toggle="state.vue = view.value"
        />
      </div>

      <CollectionBinder v-if="state.vue === 'classeur'" :progress="progress" :active="true" />
      <CollectionInventory v-else :filters="filters" :sets="setOptions" @page-size="pageSize = $event" />
    </div>
  </section>
</template>

<style scoped>
.collection-page {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.collection-page-title {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.collection-page-switch {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
</style>
