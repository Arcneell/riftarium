<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, DOMAINS, TYPES, RARITIES } from "../api.js"
import { cardsQuery, csvSplit, glyphUrl } from "../cardText.js"
import { useScrollMemory } from "../useScrollMemory.js"
import CardTile from "../components/CardTile.vue"
import FilterSelect from "../components/FilterSelect.vue"

const route = useRoute()
const router = useRouter()
const { restoreScroll } = useScrollMemory()
const ENERGIES = ["0", "1", "2", "3", "4", "5", "6", "7+"]

function fromQuery(query) {
  return {
    q: query.q || "",
    set_id: csvSplit(query.set),
    type: csvSplit(query.type),
    domain: csvSplit(query.domain),
    rarity: csvSplit(query.rarity),
    energy: csvSplit(query.energy),
    page: Math.max(1, Number(query.page) || 1)
  }
}

const state = reactive(fromQuery(route.query))
const result = ref({ total: 0, items: [] })
const sets = ref([])
const loading = ref(false)
const error = ref("")
const grid = ref(null)
const tileMin = ref(190)
const size = ref(30)
let timer = null
let resizeTimer = null
let observer = null

const domainOptions = computed(() =>
  Object.entries(DOMAINS)
    .filter(([key]) => key !== "Colorless")
    .map(([value, domain]) => ({ value, label: domain.label, color: domain.color }))
)
const typeOptions = computed(() => Object.entries(TYPES).map(([value, label]) => ({ value, label })))
const rarityOptions = computed(() => Object.entries(RARITIES).map(([value, label]) => ({ value, label })))
const energyOptions = computed(() =>
  ENERGIES.map((cost) => ({
    value: cost,
    label: cost === "7+" ? "7 et plus" : String(cost),
    glyph: glyphUrl(`energy_${cost === "7+" ? "7" : cost}`),
    glyphKind: "energy"
  }))
)
const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))

const activeCount = computed(
  () =>
    (state.q ? 1 : 0) +
    state.set_id.length +
    state.type.length +
    state.domain.length +
    state.rarity.length +
    state.energy.length
)

const pageCount = computed(() => Math.max(1, Math.ceil(result.value.total / size.value)))

function toQuery() {
  const query = {}
  if (state.q) query.q = state.q
  if (state.set_id.length) query.set = state.set_id.join(",")
  if (state.type.length) query.type = state.type.join(",")
  if (state.domain.length) query.domain = state.domain.join(",")
  if (state.rarity.length) query.rarity = state.rarity.join(",")
  if (state.energy.length) query.energy = state.energy.join(",")
  if (state.page > 1) query.page = String(state.page)
  return query
}

/* Colonnes qui tiennent vraiment dans le conteneur : sinon minmax déborde et les cartes sont coupées. */
function measure() {
  const viewport = window.innerWidth || 1280
  const height = window.innerHeight || 800
  const width = grid.value?.clientWidth || Math.max(280, viewport - 56)
  const gap = viewport < 560 ? 12 : viewport < 900 ? 16 : 24
  const minCol = viewport < 560 ? 148 : viewport < 900 ? 160 : viewport < 1400 ? 176 : 188
  const columns = Math.max(2, Math.floor((width + gap) / (minCol + gap)))
  tileMin.value = Math.max(132, Math.floor((width - gap * (columns - 1)) / columns) - 1)
  const rows = height >= 1100 ? 6 : height >= 820 ? 5 : 4
  size.value = Math.min(100, columns * rows)
}

function scheduleMeasure() {
  clearTimeout(resizeTimer)
  resizeTimer = setTimeout(measure, 180)
}

let firstLoad = true

async function load() {
  loading.value = true
  error.value = ""
  try {
    result.value = await api(`/api/cards?${cardsQuery(state, size.value)}`)
    if (firstLoad) {
      firstLoad = false
      restoreScroll()
    }
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

function scheduleLoad() {
  clearTimeout(timer)
  timer = setTimeout(load, 180)
}

function setFilter(key, values) {
  state[key] = values
  state.page = 1
}

function reset() {
  state.q = ""
  state.set_id = []
  state.type = []
  state.domain = []
  state.rarity = []
  state.energy = []
  state.page = 1
}

watch(
  () => [
    state.q,
    state.set_id.join(),
    state.type.join(),
    state.domain.join(),
    state.rarity.join(),
    state.energy.join(),
    state.page
  ],
  () => {
    const query = toQuery()
    if (JSON.stringify(route.query) !== JSON.stringify(query)) router.replace({ query })
    scheduleLoad()
  }
)

watch(size, () => {
  if (state.page > pageCount.value) state.page = 1
  else scheduleLoad()
})

watch(
  () => route.query,
  (query) => {
    const next = fromQuery(query)
    if (
      next.q === state.q &&
      next.page === state.page &&
      next.set_id.join() === state.set_id.join() &&
      next.type.join() === state.type.join() &&
      next.domain.join() === state.domain.join() &&
      next.rarity.join() === state.rarity.join() &&
      next.energy.join() === state.energy.join()
    ) {
      return
    }
    Object.assign(state, next)
  }
)

onMounted(async () => {
  measure()
  load()
  window.addEventListener("resize", scheduleMeasure)
  if (typeof ResizeObserver !== "undefined" && grid.value) {
    observer = new ResizeObserver(scheduleMeasure)
    observer.observe(grid.value)
  }
  try {
    sets.value = await api("/api/sets")
  } catch {
    /* filtre sets indisponible */
  }
})

onBeforeUnmount(() => {
  clearTimeout(timer)
  clearTimeout(resizeTimer)
  window.removeEventListener("resize", scheduleMeasure)
  observer?.disconnect()
})
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Cartothèque</p>
      <h2>Toutes les cartes du jeu</h2>
      <p class="lead">Cumulez les filtres : domaine, type, rareté, coût. Cherchez aussi par nom, code ou texte.</p>
    </div>
  </div>

  <section style="padding-top: 40px">
    <div class="wrap cards-wrap">
      <div class="filter-board">
        <label class="search filter-search">
          <Icon name="search" :size="18" />
          <input
            type="search"
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
          v-if="setOptions.length"
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
