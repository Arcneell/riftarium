<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue"
import { api, session, CONDITIONS, LANGS } from "../api.js"
import {
  cardsQuery,
  domainFilterOptions,
  energyFilterOptions,
  rarityFilterOptions,
  typeFilterOptions
} from "../cardText.js"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import { useScrollMemory } from "../useScrollMemory.js"
import { BANNERS } from "../banners.js"
import CardTile from "../components/CardTile.vue"
import FilterSelect from "../components/FilterSelect.vue"
import ModalDialog from "../components/ModalDialog.vue"
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
      sort: { kind: "text" },
      page: { kind: "page" }
    },
    {
      fetcher: (filters) => api(`/api/collection?${cardsQuery(filters, size.value)}`),
      initialResult: { total: 0, total_cards: 0, unique_cards: 0, value_eur: null, items: [] },
      pageSize: size,
      onLoaded: (data) => {
        if (state.page > 1 && !data.items.length) state.page = 1
        if (firstLoad) {
          firstLoad = false
          restoreScroll()
        }
      }
    }
  )

const sets = ref([])

/* Progression par set : chargée à part, la grille n'attend pas ce calcul. */
const progress = ref(null) // { sets: [...], overall: {...} } — null tant que rien n'est chargé
const progressLoading = ref(false)

async function loadProgress() {
  progressLoading.value = true
  try {
    const data = await api("/api/collection/sets")
    if (data && Array.isArray(data.sets) && data.overall) progress.value = data
  } catch {
    /* progression indisponible : la section reste masquée */
  } finally {
    progressLoading.value = false
  }
}

function percentOf(row) {
  if (!row.total) return 0
  return Math.round((row.owned / row.total) * 100)
}

function missingText(row) {
  if (!row.missing) return "set complet ✓"
  const cost = formatEur(row.missing_cost_eur)
  return `il manque ${row.missing} carte(s)${cost ? ` (~${cost})` : ""}`
}

/* Clic sur un set : la grille se filtre dessus, comme via le sélecteur Sets. */
function filterBySet(setId) {
  setFilter("set_id", [setId])
}

/* Mode sélection : le clic coche la carte au lieu d'ouvrir sa fiche. */
const selectMode = ref(false)
const selected = ref(new Set())
const bulk = reactive({ condition: "", lang: "", busy: false })
const pendingRemove = ref(false)
const removeError = ref("")

const domainOptions = computed(() => domainFilterOptions())
const typeOptions = computed(() => typeFilterOptions())
const rarityOptions = computed(() => rarityFilterOptions())
const energyOptions = computed(() => energyFilterOptions())
const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))
/* Tri à choix unique, même habillage que les autres filtres. */
const SORT_OPTIONS = [
  { value: "price_desc", label: "Prix décroissant" },
  { value: "price_asc", label: "Prix croissant" }
]

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

/* La taille de page suit la grille : on recharge, sauf si la page courante n'existe plus. */
watch(size, () => {
  if (state.page > pageCount.value) state.page = 1
  else scheduleLoad()
})

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
  <PageBanner :art="BANNERS.collection" title="Mon inventaire" />

  <section>
    <div class="wrap cards-wrap">
      <div class="stat-row">
        <div class="stat" v-reveal>
          Cartes<b>{{ result.total_cards }}</b>
        </div>
        <div class="stat" v-reveal="1">
          Uniques<b>{{ result.unique_cards }}</b>
        </div>
        <div class="stat" v-reveal="2" :title="PRICE_NOTE">
          Valeur estimée<b>{{ formatEur(result.value_eur) || "—" }}</b>
        </div>
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
          label="Sets"
          :options="setOptions"
          :model-value="state.set_id"
          @update:model-value="setFilter('set_id', $event)"
        />
        <FilterSelect
          label="Trier"
          single
          :options="SORT_OPTIONS"
          :model-value="state.sort ? [state.sort] : []"
          @update:model-value="setFilter('sort', $event[0] || '')"
        />
        <button v-if="activeCount" class="btn btn-ghost btn-sm" @click="reset">
          Réinitialiser ({{ activeCount }})
        </button>
        <button class="btn btn-sm" :class="selectMode ? '' : 'btn-ghost'" @click="toggleSelectMode">
          {{ selectMode ? "Terminer la sélection" : "Sélectionner" }}
        </button>
        <RouterLink class="btn btn-ghost btn-sm scan-entry" to="/scan">Scanner une carte</RouterLink>
        <!-- Téléchargement direct : le navigateur gère le CSV, aucun fetch. -->
        <a v-if="session.token" class="btn btn-ghost btn-sm" href="/api/collection/export.csv" download>
          Exporter (CSV)
        </a>
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
            <span v-if="formatEur(item.value_eur)" class="price-lot" :title="PRICE_NOTE">
              {{ formatEur(item.value_eur) }}
            </span>
            <span>×{{ item.total_qty }}</span>
          </div>
        </div>
      </div>

      <p v-if="!loading && !result.items.length && !result.unique_cards" class="muted">
        Votre collection est encore vide — ouvrez une <RouterLink to="/cartes">fiche carte</RouterLink> et notez combien
        d'exemplaires vous possédez.
      </p>
      <p v-else-if="!loading && !result.items.length" class="muted">Aucune carte ne correspond aux filtres.</p>

      <div class="pager" v-if="pageCount > 1">
        <button class="btn btn-ghost btn-sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</button>
        <span>page {{ state.page }} / {{ pageCount }}</span>
        <button class="btn btn-ghost btn-sm" :disabled="state.page >= pageCount" @click="state.page++">
          Suivant →
        </button>
      </div>

      <!-- Repliée par défaut : consultable à la demande, sans encombrer la page. -->
      <details v-if="progress || progressLoading" class="progress-fold" v-reveal>
        <summary class="progress-summary">
          Progression par set
          <span v-if="progress" class="muted mono">
            {{ progress.overall.owned }}/{{ progress.overall.total }} · {{ percentOf(progress.overall) }} %
          </span>
        </summary>
        <div class="progress-panel">
          <p v-if="progressLoading && !progress" class="muted mono progress-loading">Calcul de votre progression…</p>
          <template v-if="progress">
            <div class="progress-row progress-overall">
              <span class="progress-name">Tous sets confondus</span>
              <div
                class="progress-bar"
                role="img"
                :aria-label="`${progress.overall.owned} cartes possédées sur ${progress.overall.total}`"
              >
                <i :style="{ width: `${percentOf(progress.overall)}%` }"></i>
              </div>
              <span class="progress-count">
                {{ progress.overall.owned }}/{{ progress.overall.total }} · {{ percentOf(progress.overall) }} %
              </span>
              <span class="progress-missing" :class="{ done: !progress.overall.missing }" :title="PRICE_NOTE">
                {{ missingText(progress.overall) }}
              </span>
            </div>
            <button
              v-for="row in progress.sets"
              :key="row.set_id"
              type="button"
              class="progress-row"
              :title="`Filtrer la collection sur ${row.name}`"
              @click="filterBySet(row.set_id)"
            >
              <span class="progress-name">{{ row.name }}</span>
              <div class="progress-bar" role="img" :aria-label="`${row.owned} cartes possédées sur ${row.total}`">
                <i :style="{ width: `${percentOf(row)}%` }"></i>
              </div>
              <span class="progress-count">{{ row.owned }}/{{ row.total }} · {{ percentOf(row) }} %</span>
              <span class="progress-missing" :class="{ done: !row.missing }" :title="PRICE_NOTE">
                {{ missingText(row) }}
              </span>
            </button>
          </template>
        </div>
      </details>
    </div>
  </section>

  <ModalDialog v-if="pendingRemove" title="Retirer de la collection" @close="cancelRemove">
    <p>{{ selected.size }} carte(s) seront retirées de votre inventaire, sans retour en arrière possible.</p>
    <p v-if="removeError" class="error">{{ removeError }}</p>
    <div class="modal-actions">
      <button type="button" class="btn btn-ghost" :disabled="bulk.busy" @click="cancelRemove">Annuler</button>
      <button type="button" class="btn btn-danger" :disabled="bulk.busy" @click="applyBulk({ remove: true })">
        {{ bulk.busy ? "Retrait…" : "Retirer" }}
      </button>
    </div>
  </ModalDialog>
</template>
