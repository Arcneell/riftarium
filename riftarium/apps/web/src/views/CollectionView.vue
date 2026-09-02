<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { api, cardThumb, session, CONDITIONS, LANGS } from "../api.js"
import {
  cardsQuery,
  domainFilterOptions,
  energyFilterOptions,
  isFoil,
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
      page: { kind: "page" },
      /* Deux affichages : le classeur (par défaut) et l'inventaire à plat.
         Synchronisé à l'URL comme un filtre, épargné par « Réinitialiser ». */
      vue: { kind: "enum", values: ["classeur", "inventaire"], default: "classeur", reset: false }
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

/* Progression par set : nourrit la stat « Complétion » et les onglets du classeur. */
const progress = ref(null) // { sets: [...], overall: {...} } — null tant que rien n'est chargé
const progressLoading = ref(false)

async function loadProgress() {
  progressLoading.value = true
  try {
    const data = await api("/api/collection/sets")
    if (data && Array.isArray(data.sets) && data.overall) progress.value = data
  } catch {
    /* progression indisponible : le classeur attend, la stat reste masquée */
  } finally {
    progressLoading.value = false
  }
}

function percentOf(row) {
  if (!row.total) return 0
  return Math.round((row.owned / row.total) * 100)
}

function missingText(row) {
  if (!row.missing) return "set complet"
  const cost = formatEur(row.missing_cost_eur)
  return `il manque ${row.missing} carte(s)${cost ? ` (~${cost})` : ""}`
}

/* ---------- Classeur : double page de 9 pochettes, cartes manquantes en fantôme ---------- */

const SPREAD_SIZE = 18 // 2 pages de 3×3 : une double page = une page d'API

const binderSet = ref("")
const binderPage = ref(1)
const binderOwned = ref("") // "" tout · "1" possédées · "0" manquantes
const binderLoading = ref(false)
const binderError = ref("")
/* Instantané affiché : remplacé seulement quand la réponse arrive, pour que
   l'animation de tournage parte d'une page pleine vers une page pleine. */
const spread = ref(null) // { key, items, page, pages, total }
const turnDir = ref(1) // 1 : on avance (ou change de set), -1 : on recule

let binderSeq = 0

async function loadBinder() {
  if (!binderSet.value || state.vue !== "classeur") return
  const seq = ++binderSeq
  binderLoading.value = true
  binderError.value = ""
  try {
    const params = new URLSearchParams({
      set_id: binderSet.value,
      page: String(binderPage.value),
      size: String(SPREAD_SIZE)
    })
    if (binderOwned.value) params.set("owned", binderOwned.value)
    const data = await api(`/api/cards?${params}`)
    if (seq !== binderSeq) return
    spread.value = {
      key: `${binderSet.value}|${data.page}|${binderOwned.value}`,
      items: data.items,
      page: data.page,
      pages: Math.max(1, Math.ceil(data.total / SPREAD_SIZE)),
      total: data.total
    }
  } catch (e) {
    if (seq === binderSeq) binderError.value = e.message
  } finally {
    if (seq === binderSeq) binderLoading.value = false
  }
}

watch([binderSet, binderPage, binderOwned], loadBinder)
/* Retour au classeur : charge la double page si elle n'existe pas encore. */
watch(
  () => state.vue,
  (mode) => {
    if (mode === "classeur" && !spread.value) loadBinder()
  }
)

const currentSet = computed(() => progress.value?.sets.find((row) => row.set_id === binderSet.value) || null)

function selectSet(setId) {
  if (setId === binderSet.value) return
  turnDir.value = 1
  binderSet.value = setId
  binderPage.value = 1
}

function setGhostFilter(value) {
  if (value === binderOwned.value) return
  turnDir.value = 1
  binderOwned.value = value
  binderPage.value = 1
}

function turnPage(delta) {
  const next = binderPage.value + delta
  if (next < 1 || (spread.value && next > spread.value.pages)) return
  turnDir.value = delta
  binderPage.value = next
}

/* Flèches gauche/droite : on feuillette le classeur au clavier, sauf quand
   le focus est dans un champ de saisie. */
function onBinderKeydown(event) {
  if (state.vue !== "classeur" || !spread.value) return
  if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return
  const target = event.target
  if (target && (/^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName) || target.isContentEditable)) return
  if (event.key === "ArrowRight") {
    event.preventDefault()
    turnPage(1)
  } else if (event.key === "ArrowLeft") {
    event.preventDefault()
    turnPage(-1)
  }
}

/* Une page de classeur = 9 pochettes, complétées par des pochettes vides. */
function padPage(list) {
  const out = [...list]
  while (out.length < 9) out.push(null)
  return out
}
const leftCards = computed(() => padPage(spread.value ? spread.value.items.slice(0, 9) : []))
const rightCards = computed(() => padPage(spread.value ? spread.value.items.slice(9, 18) : []))

const GHOST_FILTERS = [
  { value: "", label: "Tout" },
  { value: "1", label: "Possédées" },
  { value: "0", label: "Manquantes" }
]

/* ---------- Inventaire : filtres, sélection et opérations de masse ---------- */

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

onBeforeUnmount(() => window.removeEventListener("keydown", onBinderKeydown))

onMounted(async () => {
  window.addEventListener("keydown", onBinderKeydown)
  load()
  loadProgress().then(() => {
    /* Set ouvert par défaut : le premier incomplet — celui qu'on a envie de finir. */
    if (!binderSet.value && progress.value?.sets?.length) {
      const first = progress.value.sets.find((row) => row.missing) || progress.value.sets[0]
      binderSet.value = first.set_id
    }
  })
  try {
    sets.value = await api("/api/sets")
  } catch {
    /* filtre sets indisponible */
  }
})
</script>

<template>
  <PageBanner :art="BANNERS.collection" title="Ma collection" />

  <section>
    <div class="wrap cards-wrap">
      <div class="stat-row col-stats">
        <div class="stat" v-reveal>
          Cartes<b>{{ result.total_cards }}</b>
        </div>
        <div class="stat" v-reveal="1">
          Uniques<b>{{ result.unique_cards }}</b>
        </div>
        <div class="stat" v-reveal="2" :title="PRICE_NOTE">
          Valeur estimée<b>{{ formatEur(result.value_eur) || "—" }}</b>
        </div>
        <div v-if="progress" class="stat" v-reveal="3" :title="missingText(progress.overall)">
          Complétion<b>{{ percentOf(progress.overall) }} %</b>
        </div>
      </div>

      <div class="view-switch" role="tablist" aria-label="Affichage de la collection">
        <button
          role="tab"
          :aria-selected="state.vue === 'classeur'"
          :class="{ active: state.vue === 'classeur' }"
          @click="state.vue = 'classeur'"
        >
          Classeur
        </button>
        <button
          role="tab"
          :aria-selected="state.vue === 'inventaire'"
          :class="{ active: state.vue === 'inventaire' }"
          @click="state.vue = 'inventaire'"
        >
          Inventaire
        </button>
      </div>

      <!-- ================= Classeur ================= -->
      <template v-if="state.vue === 'classeur'">
        <div v-if="progress" class="binder-tabs" role="tablist" aria-label="Sets du classeur">
          <button
            v-for="row in progress.sets"
            :key="row.set_id"
            type="button"
            role="tab"
            class="binder-tab"
            :class="{ active: row.set_id === binderSet, done: !row.missing }"
            :aria-selected="row.set_id === binderSet"
            :title="missingText(row)"
            @click="selectSet(row.set_id)"
          >
            <span class="tab-top">
              <span class="tab-name">{{ row.name }}</span>
              <span v-if="!row.missing" class="progress-gem" aria-hidden="true">✓</span>
              <span v-else class="tab-pct mono">{{ percentOf(row) }} %</span>
            </span>
            <span class="tab-bar" aria-hidden="true"><b :style="{ width: `${percentOf(row)}%` }"></b></span>
          </button>
        </div>

        <p v-if="binderError" class="error">{{ binderError }}</p>

        <div v-if="progress || progressLoading" class="binder" v-reveal>
          <header class="binder-head">
            <div class="binder-id">
              <h2 class="binder-title">{{ currentSet ? currentSet.name : "Classeur" }}</h2>
              <p v-if="currentSet" class="binder-sub mono" :title="PRICE_NOTE">
                {{ currentSet.owned }}/{{ currentSet.total }} · {{ percentOf(currentSet) }} % —
                {{ missingText(currentSet) }}
              </p>
            </div>
            <div class="binder-chips" role="group" aria-label="Filtrer les pochettes">
              <button
                v-for="chip in GHOST_FILTERS"
                :key="chip.value"
                type="button"
                class="filter"
                :aria-pressed="binderOwned === chip.value"
                @click="setGhostFilter(chip.value)"
              >
                {{ chip.label }}
              </button>
            </div>
          </header>
          <div v-if="currentSet" class="binder-progress" aria-hidden="true">
            <i :style="{ width: `${percentOf(currentSet)}%` }"></i>
          </div>

          <div class="binder-stage" :class="{ loading: binderLoading }">
            <Transition
              :name="turnDir < 0 ? 'turn-prev' : 'turn-next'"
              mode="out-in"
              :duration="{ leave: 280, enter: 320 }"
            >
              <div v-if="spread && spread.items.length" :key="spread.key" class="binder-spread">
                <div class="binder-page">
                  <template v-for="(card, i) in leftCards" :key="card ? card.id : `l-${i}`">
                    <RouterLink
                      v-if="card"
                      class="pocket"
                      :class="{
                        ghost: !card.owned_qty,
                        foil: isFoil(card),
                        landscape: card.orientation === 'landscape'
                      }"
                      :style="{ '--i': i }"
                      :to="`/cartes/${card.id}`"
                      :title="card.owned_qty ? card.name : `Carte manquante : ${card.name}`"
                    >
                      <img
                        :src="cardThumb(card.image_url, 320)"
                        :alt="card.owned_qty ? `Carte Riftbound : ${card.name}` : `Carte manquante : ${card.name}`"
                        loading="lazy"
                        decoding="async"
                      />
                      <span v-if="card.owned_qty" class="pocket-qty">×{{ card.owned_qty }}</span>
                      <template v-else>
                        <span class="pocket-num">{{ card.riftbound_id.toUpperCase() }}</span>
                        <span v-if="formatEur(card.price_eur)" class="pocket-price" :title="PRICE_NOTE">
                          {{ formatEur(card.price_eur) }}
                        </span>
                      </template>
                      <span class="pocket-sheen" aria-hidden="true"></span>
                    </RouterLink>
                    <span v-else class="pocket blank" :style="{ '--i': i }" aria-hidden="true"></span>
                  </template>
                </div>
                <div class="binder-spine" aria-hidden="true"><i></i><i></i><i></i></div>
                <div class="binder-page">
                  <template v-for="(card, i) in rightCards" :key="card ? card.id : `r-${i}`">
                    <RouterLink
                      v-if="card"
                      class="pocket"
                      :class="{
                        ghost: !card.owned_qty,
                        foil: isFoil(card),
                        landscape: card.orientation === 'landscape'
                      }"
                      :style="{ '--i': i + 9 }"
                      :to="`/cartes/${card.id}`"
                      :title="card.owned_qty ? card.name : `Carte manquante : ${card.name}`"
                    >
                      <img
                        :src="cardThumb(card.image_url, 320)"
                        :alt="card.owned_qty ? `Carte Riftbound : ${card.name}` : `Carte manquante : ${card.name}`"
                        loading="lazy"
                        decoding="async"
                      />
                      <span v-if="card.owned_qty" class="pocket-qty">×{{ card.owned_qty }}</span>
                      <template v-else>
                        <span class="pocket-num">{{ card.riftbound_id.toUpperCase() }}</span>
                        <span v-if="formatEur(card.price_eur)" class="pocket-price" :title="PRICE_NOTE">
                          {{ formatEur(card.price_eur) }}
                        </span>
                      </template>
                      <span class="pocket-sheen" aria-hidden="true"></span>
                    </RouterLink>
                    <span v-else class="pocket blank" :style="{ '--i': i + 9 }" aria-hidden="true"></span>
                  </template>
                </div>
              </div>

              <div v-else-if="spread" key="empty" class="binder-empty">
                <p v-if="binderOwned === '0'" class="binder-empty-title">Rien ne manque ici</p>
                <p v-else-if="binderOwned === '1'" class="binder-empty-title">Aucune carte possédée dans ce set</p>
                <p v-else class="binder-empty-title">Classeur vide</p>
                <p class="muted">
                  <template v-if="binderOwned === '0'">Ce set est complet — votre classeur est plein.</template>
                  <template v-else>Ouvrez une fiche carte ou scannez vos cartes pour remplir les pochettes.</template>
                </p>
              </div>

              <div v-else key="skeleton" class="binder-spread">
                <div class="binder-page">
                  <span v-for="n in 9" :key="`sl-${n}`" class="pocket blank shimmer" :style="{ '--i': n - 1 }"></span>
                </div>
                <div class="binder-spine" aria-hidden="true"><i></i><i></i><i></i></div>
                <div class="binder-page">
                  <span v-for="n in 9" :key="`sr-${n}`" class="pocket blank shimmer" :style="{ '--i': n + 8 }"></span>
                </div>
              </div>
            </Transition>
          </div>

          <div v-if="spread && spread.pages > 1" class="binder-nav">
            <button
              class="btn btn-ghost btn-sm"
              :disabled="binderPage <= 1 || binderLoading"
              aria-label="Double page précédente"
              @click="turnPage(-1)"
            >
              ← Tourner
            </button>
            <span class="mono">{{ spread.page }} / {{ spread.pages }}</span>
            <button
              class="btn btn-ghost btn-sm"
              :disabled="binderPage >= spread.pages || binderLoading"
              aria-label="Double page suivante"
              @click="turnPage(1)"
            >
              Tourner →
            </button>
          </div>
        </div>
      </template>

      <!-- ================= Inventaire ================= -->
      <template v-else>
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
          <!-- Actions sur la collection, séparées des filtres de recherche. -->
          <div class="board-actions">
            <button class="btn btn-sm" :class="selectMode ? '' : 'btn-ghost'" @click="toggleSelectMode">
              {{ selectMode ? "Terminer la sélection" : "Sélectionner" }}
            </button>
            <RouterLink
              class="btn btn-ghost btn-sm scan-entry"
              to="/scan"
              title="Identifier une carte avec l'appareil photo"
            >
              <Icon name="camera" :size="16" />
              Scanner
            </RouterLink>
            <!-- Téléchargement direct : le navigateur gère le CSV, aucun fetch. -->
            <a v-if="session.token" class="btn btn-ghost btn-sm" href="/api/collection/export.csv" download>
              Exporter (CSV)
            </a>
          </div>
        </div>

        <div v-if="selectMode" class="bulk-bar" role="toolbar" aria-label="Opérations sur la sélection">
          <span class="mono bulk-count">{{ selected.size }} carte(s)</span>
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
              <span v-if="item.entries.length === 1">
                {{ item.entries[0].condition }} · {{ item.entries[0].lang }}
              </span>
              <span v-else :title="lotsTitle(item)">{{ item.entries.length }} lots</span>
              <span v-if="formatEur(item.value_eur)" class="price-lot" :title="PRICE_NOTE">
                {{ formatEur(item.value_eur) }}
              </span>
              <span>×{{ item.total_qty }}</span>
            </div>
          </div>
        </div>

        <div v-if="!loading && !result.items.length && !result.unique_cards" class="col-empty">
          <p class="col-empty-title">Votre vitrine est encore vide</p>
          <p class="muted">
            Notez vos exemplaires depuis une fiche carte, ou scannez vos cartes pour les ajouter d'un geste.
          </p>
          <div class="col-empty-actions">
            <RouterLink class="btn" to="/cartes">Parcourir les cartes</RouterLink>
            <RouterLink class="btn btn-ghost" to="/scan">Scanner une carte</RouterLink>
          </div>
        </div>
        <div v-else-if="!loading && !result.items.length" class="col-empty">
          <p class="col-empty-title">Aucune carte ne correspond aux filtres</p>
          <div class="col-empty-actions">
            <button class="btn btn-ghost" @click="reset">Réinitialiser les filtres</button>
          </div>
        </div>

        <div class="pager" v-if="pageCount > 1">
          <button class="btn btn-ghost btn-sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</button>
          <span>page {{ state.page }} / {{ pageCount }}</span>
          <button class="btn btn-ghost btn-sm" :disabled="state.page >= pageCount" @click="state.page++">
            Suivant →
          </button>
        </div>
      </template>
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
