<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, CONDITIONS, LANGS, TYPES, RARITIES } from "../api.js"
import { cardsQuery, csvSplit, domainFilterOptions, glyphUrl } from "../cardText.js"
import { useScrollMemory } from "../useScrollMemory.js"
import CardTile from "../components/CardTile.vue"
import FilterSelect from "../components/FilterSelect.vue"
import ModalDialog from "../components/ModalDialog.vue"

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
const result = ref({ total: 0, total_cards: 0, unique_cards: 0, items: [] })
const sets = ref([])
const loading = ref(false)
const error = ref("")
const grid = ref(null)
const tileMin = ref(190)
const size = ref(30)
let timer = null
let resizeTimer = null
let observer = null

/* Mode sélection : le clic coche la carte au lieu d'ouvrir sa fiche. */
const selectMode = ref(false)
const selected = ref(new Set())
const bulk = reactive({ condition: "", lang: "", busy: false })
const pendingRemove = ref(false)
const removeError = ref("")

const domainOptions = computed(() => domainFilterOptions())
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
    result.value = await api(`/api/collection?${cardsQuery(state, size.value)}`)
    if (state.page > 1 && !result.value.items.length) state.page = 1
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

function lotsTitle(item) {
  return item.entries.map((entry) => `${entry.qty}× ${entry.condition} ${entry.lang}`).join(", ")
}

function toggleSelectMode() {
  selectMode.value = !selectMode.value
  if (!selectMode.value) selected.value = new Set()
}

function onTileClick(event, item) {
  if (!selectMode.value) return
  event.preventDefault()
  event.stopPropagation()
  const next = new Set(selected.value)
  if (next.has(item.card.id)) next.delete(item.card.id)
  else next.add(item.card.id)
  selected.value = next
}

function selectPage() {
  const next = new Set(selected.value)
  const allSelected = result.value.items.every((item) => next.has(item.card.id))
  for (const item of result.value.items) {
    if (allSelected) next.delete(item.card.id)
    else next.add(item.card.id)
  }
  selected.value = next
}

function askRemove() {
  if (!selected.value.size || bulk.busy) return
  pendingRemove.value = true
  removeError.value = ""
}

function cancelRemove() {
  if (bulk.busy) return
  pendingRemove.value = false
  removeError.value = ""
}

async function applyBulk(payload) {
  if (!selected.value.size || bulk.busy) return
  bulk.busy = true
  error.value = ""
  removeError.value = ""
  try {
    await api("/api/collection/bulk", {
      method: "POST",
      body: { card_ids: [...selected.value], ...payload }
    })
    if (payload.remove) {
      selected.value = new Set()
      pendingRemove.value = false
    }
    await load()
  } catch (e) {
    if (payload.remove) removeError.value = e.message
    else error.value = e.message
  } finally {
    bulk.busy = false
  }
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
  <div
    class="page-banner"
    style="
      --banner: url(&quot;https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/2282ecab240f601b611ae89b5ade895e1b6b2de4-4676x2630.jpg?auto=format&w=1600&quot;);
    "
  >
    <div class="wrap">
      <p class="eyebrow">Collection</p>
      <h2>Mon inventaire</h2>
      <p class="lead">Vos cartes, leurs états, leurs langues. L'estimation Cardmarket et le scan arrivent.</p>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </div>

  <section style="padding-top: 40px">
    <div class="wrap cards-wrap">
      <div class="stat-row">
        <div class="stat" v-reveal>
          Cartes<b>{{ result.total_cards }}</b>
        </div>
        <div class="stat" v-reveal="1">
          Uniques<b>{{ result.unique_cards }}</b>
        </div>
        <div class="stat" v-reveal="2">Valeur estimée<b>—</b></div>
      </div>

      <div class="filter-board">
        <label class="search filter-search">
          <Icon name="search" :size="18" />
          <input
            type="search"
            v-model="state.q"
            placeholder="Jinx, ogn-202, reaction…"
            aria-label="Rechercher dans ma collection"
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
        <button class="btn btn-sm" :class="selectMode ? '' : 'btn-ghost'" @click="toggleSelectMode">
          {{ selectMode ? "Terminer la sélection" : "Sélectionner" }}
        </button>
      </div>

      <div v-if="selectMode" class="bulk-bar" role="toolbar" aria-label="Opérations sur la sélection">
        <span class="mono">{{ selected.size }} carte(s)</span>
        <button class="btn btn-ghost btn-sm" @click="selectPage">Toute la page</button>
        <span class="bulk-sep"></span>
        <button
          class="btn btn-ghost btn-sm"
          :disabled="!selected.size || bulk.busy"
          title="Ajoute 1 exemplaire à chaque lot des cartes sélectionnées"
          @click="applyBulk({ qty_delta: 1 })"
        >
          +1 par lot
        </button>
        <button
          class="btn btn-ghost btn-sm"
          :disabled="!selected.size || bulk.busy"
          title="Retire 1 exemplaire de chaque lot des cartes sélectionnées"
          @click="applyBulk({ qty_delta: -1 })"
        >
          −1 par lot
        </button>
        <span class="bulk-sep"></span>
        <select v-model="bulk.condition" aria-label="État à appliquer">
          <option value="">État…</option>
          <option v-for="(label, code) in CONDITIONS" :key="code" :value="code">{{ code }} · {{ label }}</option>
        </select>
        <button
          class="btn btn-ghost btn-sm"
          :disabled="!selected.size || !bulk.condition || bulk.busy"
          @click="applyBulk({ condition: bulk.condition })"
        >
          Appliquer l'état
        </button>
        <select v-model="bulk.lang" aria-label="Langue à appliquer">
          <option value="">Langue…</option>
          <option v-for="(label, code) in LANGS" :key="code" :value="code">{{ code }} · {{ label }}</option>
        </select>
        <button
          class="btn btn-ghost btn-sm"
          :disabled="!selected.size || !bulk.lang || bulk.busy"
          @click="applyBulk({ lang: bulk.lang })"
        >
          Appliquer la langue
        </button>
        <span class="bulk-sep"></span>
        <button class="btn btn-ghost btn-sm bulk-danger" :disabled="!selected.size || bulk.busy" @click="askRemove">
          Retirer de la collection
        </button>
      </div>

      <p class="muted mono" style="font-size: 0.82rem; margin-bottom: 18px">
        {{ result.total }} carte(s) unique(s) <span v-if="loading">— chargement…</span>
      </p>
      <p v-if="error" class="error">{{ error }}</p>

      <div ref="grid" class="grid-cards" :style="{ '--tile-min': `${tileMin}px` }">
        <div
          v-for="item in result.items"
          :key="item.card.id"
          class="col-cell"
          :class="{ selectable: selectMode, selected: selected.has(item.card.id) }"
          @click.capture="onTileClick($event, item)"
        >
          <CardTile :card="{ ...item.card, owned_qty: item.total_qty }" :preview="false" />
          <div class="t-meta col-state">
            <span v-if="item.entries.length === 1"> {{ item.entries[0].condition }} · {{ item.entries[0].lang }} </span>
            <span v-else :title="lotsTitle(item)">{{ item.entries.length }} lots</span>
            <span>×{{ item.total_qty }}</span>
          </div>
        </div>
      </div>

      <p v-if="!loading && !result.items.length && !result.unique_cards" class="muted">
        Collection vide. Ouvrez une <RouterLink to="/cartes">fiche carte</RouterLink> et notez combien d'exemplaires
        vous possédez.
      </p>
      <p v-else-if="!loading && !result.items.length" class="muted">Aucune carte ne correspond aux filtres.</p>

      <div class="pager" v-if="pageCount > 1">
        <button class="btn btn-ghost btn-sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</button>
        <span>page {{ state.page }} / {{ pageCount }}</span>
        <button class="btn btn-ghost btn-sm" :disabled="state.page >= pageCount" @click="state.page++">
          Suivant →
        </button>
      </div>
    </div>
  </section>

  <ModalDialog v-if="pendingRemove" title="Retirer de la collection" @close="cancelRemove">
    <p>{{ selected.size }} carte(s) seront retirées de votre inventaire. Cette action est irréversible.</p>
    <p v-if="removeError" class="error">{{ removeError }}</p>
    <div class="modal-actions">
      <button type="button" class="btn btn-ghost" :disabled="bulk.busy" @click="cancelRemove">Annuler</button>
      <button type="button" class="btn btn-danger" :disabled="bulk.busy" @click="applyBulk({ remove: true })">
        {{ bulk.busy ? "Retrait…" : "Retirer" }}
      </button>
    </div>
  </ModalDialog>
</template>
