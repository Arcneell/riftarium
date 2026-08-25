<script setup>
import { computed, onMounted, ref, watch } from "vue"
import { api } from "../api.js"
import {
  cardsQuery,
  domainFilterOptions,
  energyFilterOptions,
  rarityFilterOptions,
  typeFilterOptions
} from "../cardText.js"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { useScrollMemory } from "../useScrollMemory.js"
import { BANNERS } from "../banners.js"
import CardTile from "../components/CardTile.vue"
import FilterSelect from "../components/FilterSelect.vue"
import PageBanner from "../components/PageBanner.vue"

const { restoreScroll } = useScrollMemory()

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
const domainOptions = computed(() => domainFilterOptions())
const typeOptions = computed(() => typeFilterOptions())
const rarityOptions = computed(() => rarityFilterOptions())
const energyOptions = computed(() => energyFilterOptions())
const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))

/* La taille de page suit la grille : on recharge, sauf si la page courante n'existe plus. */
watch(size, () => {
  if (state.page > pageCount.value) state.page = 1
  else scheduleLoad()
})

onMounted(async () => {
  load()
  try {
    sets.value = await api("/api/sets")
  } catch {
    /* filtre sets indisponible */
  }
})
</script>

<template>
  <PageBanner :art="BANNERS.cards" title="Toutes les cartes du jeu" />

  <section>
    <div class="wrap cards-wrap">
      <div class="filter-board">
        <label class="search filter-search">
          <Icon name="search" :size="18" />
          <input
            type="search"
            inputmode="search"
            enterkeyhint="search"
            autocapitalize="off"
            autocorrect="off"
            spellcheck="false"
            v-model="state.q"
            placeholder="Jinx, ogn-202, reaction…"
            aria-label="Rechercher une carte"
          />
        </label>
        <FilterSelect
          label="Domaines"
          :options="domainOptions"
          :model-value="state.domain"
          @update:model-value="setFilter('domain', $event)"
        />
        <FilterSelect
          label="Types"
          :options="typeOptions"
          :model-value="state.type"
          @update:model-value="setFilter('type', $event)"
        />
        <FilterSelect
          label="Raretés"
          :options="rarityOptions"
          :model-value="state.rarity"
          @update:model-value="setFilter('rarity', $event)"
        />
        <FilterSelect
          label="Coût"
          :options="energyOptions"
          :model-value="state.energy"
          @update:model-value="setFilter('energy', $event)"
        />
        <FilterSelect
          label="Sets"
          :options="setOptions"
          :model-value="state.set_id"
          @update:model-value="setFilter('set_id', $event)"
        />
        <button v-if="activeCount" class="btn btn-ghost btn-sm" @click="reset">
          Réinitialiser ({{ activeCount }})
        </button>
      </div>

      <p class="muted mono" style="font-size: 0.82rem; margin-bottom: 18px">
        {{ result.total }} carte(s) <span v-if="loading">— chargement…</span>
      </p>
      <p v-if="error" class="error">{{ error }}</p>

      <div ref="grid" class="grid-cards" :style="{ '--tile-min': `${tileMin}px` }">
        <CardTile v-for="card in result.items" :key="card.id" :card="card" />
      </div>

      <div class="pager" v-if="pageCount > 1">
        <button class="btn btn-ghost btn-sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</button>
        <span>page {{ state.page }} / {{ pageCount }}</span>
        <button class="btn btn-ghost btn-sm" :disabled="state.page >= pageCount" @click="state.page++">
          Suivant →
        </button>
      </div>
    </div>
  </section>
</template>
