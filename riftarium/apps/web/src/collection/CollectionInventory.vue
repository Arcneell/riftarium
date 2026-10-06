<script setup>
import { computed, nextTick, onMounted, reactive, ref, unref, watch } from "vue"
import { api, session, CONDITIONS, LANGS } from "../api.js"
import ActiveFilters from "../cards/ActiveFilters.vue"
import CardFilters from "../cards/CardFilters.vue"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import CardTile from "../ui/CardTile.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftModal from "../ui/RiftModal.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

/* Inventaire de la collection : filtres en feuille, tri par prix, grille des cartes
   possédées avec leurs lots, sélection et opérations de masse. L'état des filtres
   (et le chargement) vit dans la page, via useQuerySyncedFilters ; la grille, elle,
   est mesurée ici : la taille de page calculée remonte à la page par `page-size`. */
const props = defineProps({
  filters: { type: Object, required: true },
  sets: { type: Array, default: () => [] }
})
/* `changed` : une opération de masse a réussi, la page rafraîchit statistiques et classeur. */
const emit = defineEmits(["page-size", "changed"])

/* L'erreur de page est partagée avec la page (ref de useQuerySyncedFilters). */
const { state, setFilter, reset, load, error: errorRef } = props.filters
const result = computed(() => unref(props.filters.result))
const loading = computed(() => unref(props.filters.loading))
const error = computed(() => unref(errorRef))
const activeCount = computed(() => unref(props.filters.activeCount))
const pageCount = computed(() => unref(props.filters.pageCount))
/* Le tri a ses propres puces : le badge ne compte que les filtres de la feuille. */
const filterCount = computed(() => activeCount.value - (state.sort ? 1 : 0))

function setPageError(message) {
  errorRef.value = message
}

const grid = ref(null)
const { tileMin, size } = useGridMeasure(grid)

/* La page lit ce nombre dans son fetcher : on le lui donne dès la première mesure,
   puis à chaque changement. */
onMounted(() => emit("page-size", size.value))
/* La page décide s'il faut recharger (taille différente de la dernière requête). */
watch(size, (next) => emit("page-size", next))

/* ---------- Tri et filtres ---------- */

const SORT_OPTIONS = [
  { value: "price_desc", label: "Prix décroissant" },
  { value: "price_asc", label: "Prix croissant" }
]

function toggleSort(value) {
  setFilter("sort", state.sort === value ? "" : value)
}

const sheetOpen = ref(false)
const sheetLabel = computed(() => {
  const total = result.value.total
  if (!total) return "Aucune carte"
  return total === 1 ? "Voir la carte" : `Voir les ${total} cartes`
})

/* ---------- Sélection et opérations de masse ---------- */

const selectMode = ref(false)
const selected = ref(new Set())
const bulk = reactive({ condition: "", lang: "", busy: false })
const pendingRemove = ref(false)
const removeError = ref("")
const endButton = ref(null)

function lotsTitle(item) {
  return item.entries.map((entry) => `${entry.qty}× ${entry.condition} ${entry.lang}`).join(", ")
}

function toggleSelectMode() {
  selectMode.value = !selectMode.value
  if (!selectMode.value) selected.value = new Set()
}

function toggleItem(item) {
  const next = new Set(selected.value)
  if (next.has(item.card.id)) next.delete(item.card.id)
  else next.add(item.card.id)
  selected.value = next
}

/* En sélection, un clic (y compris celui du lien de la vignette) coche la carte : rien ne navigue. */
function onPickClick(event, item) {
  event.preventDefault()
  event.stopPropagation()
  toggleItem(item)
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

/* Entrée : le clavier répété (touche maintenue) ne doit pas recocher en boucle. */
function onPickEnter(event, item) {
  if (event.repeat) return
  toggleItem(item)
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

/* En cas d'échec, la sélection est conservée : on peut relancer sans tout recocher. */
async function applyBulk(payload) {
  if (!selected.value.size || bulk.busy) return
  bulk.busy = true
  setPageError("")
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
    emit("changed")
    /* La modale ferme et rend le focus à « Retirer » (désormais désactivé) : on le pose sur
       « Terminer la sélection », seule action utile restante. */
    if (payload.remove) {
      await nextTick()
      endButton.value?.$el?.focus()
    }
  } catch (e) {
    if (payload.remove) removeError.value = e.message
    else setPageError(e.message)
  } finally {
    bulk.busy = false
  }
}
</script>

<template>
  <div class="inventaire">
    <div class="inventaire-toolbar">
      <RiftButton variant="secondary" size="sm" @click="sheetOpen = true">
        Filtres<template v-if="filterCount"> ({{ filterCount }})</template>
      </RiftButton>
      <div class="inventaire-sort" role="group" aria-label="Trier par prix">
        <RiftChip
          v-for="option in SORT_OPTIONS"
          :key="option.value"
          :label="option.label"
          :selected="state.sort === option.value"
          @toggle="toggleSort(option.value)"
        />
      </div>
      <div class="inventaire-actions">
        <RiftButton ref="endButton" variant="ghost" size="sm" @click="toggleSelectMode">
          {{ selectMode ? "Terminer la sélection" : "Sélectionner" }}
        </RiftButton>
        <!-- Téléchargement direct : le navigateur gère le CSV, aucun fetch. -->
        <RiftButton v-if="session.token" variant="ghost" size="sm" href="/api/collection/export.csv" download>
          Exporter (CSV)
        </RiftButton>
      </div>
    </div>

    <ActiveFilters :state="state" :sets="sets" @update="setFilter" @reset="reset" />

    <div v-if="selectMode" class="inventaire-bulk" role="group" aria-label="Opérations sur la sélection">
      <span class="inventaire-count" aria-live="polite">{{ selected.size }} carte(s)</span>
      <RiftButton variant="ghost" size="sm" @click="selectPage">Toute la page</RiftButton>
      <span class="inventaire-sep" aria-hidden="true"></span>
      <RiftButton
        variant="ghost"
        size="sm"
        :disabled="!selected.size || bulk.busy"
        title="Ajoute 1 exemplaire à chaque lot des cartes sélectionnées"
        @click="applyBulk({ qty_delta: 1 })"
      >
        +1 par lot
      </RiftButton>
      <RiftButton
        variant="ghost"
        size="sm"
        :disabled="!selected.size || bulk.busy"
        title="Retire 1 exemplaire de chaque lot des cartes sélectionnées"
        @click="applyBulk({ qty_delta: -1 })"
      >
        −1 par lot
      </RiftButton>
      <span class="inventaire-sep" aria-hidden="true"></span>
      <select v-model="bulk.condition" aria-label="État à appliquer">
        <option value="">État…</option>
        <option v-for="(label, code) in CONDITIONS" :key="code" :value="code">{{ code }} · {{ label }}</option>
      </select>
      <RiftButton
        variant="ghost"
        size="sm"
        :disabled="!selected.size || !bulk.condition || bulk.busy"
        @click="applyBulk({ condition: bulk.condition })"
      >
        Appliquer l'état
      </RiftButton>
      <select v-model="bulk.lang" aria-label="Langue à appliquer">
        <option value="">Langue…</option>
        <option v-for="(label, code) in LANGS" :key="code" :value="code">{{ code }} · {{ label }}</option>
      </select>
      <RiftButton
        variant="ghost"
        size="sm"
        :disabled="!selected.size || !bulk.lang || bulk.busy"
        @click="applyBulk({ lang: bulk.lang })"
      >
        Appliquer la langue
      </RiftButton>
      <span class="inventaire-sep" aria-hidden="true"></span>
      <RiftButton
        variant="ghost"
        size="sm"
        class="inventaire-danger"
        :disabled="!selected.size || bulk.busy"
        @click="askRemove"
      >
        Retirer de la collection
      </RiftButton>
    </div>

    <p class="inventaire-total" aria-live="polite">
      {{ result.total }} carte(s) unique(s) <span v-if="loading">— chargement…</span>
    </p>
    <p v-if="error" class="inventaire-error" role="alert">{{ error }}</p>

    <div
      ref="grid"
      class="inventaire-grid"
      :class="{ reloading: loading && result.items.length }"
      :style="{ '--tile-min': `${tileMin}px` }"
    >
      <template v-if="loading && !result.items.length">
        <RiftSkeleton v-for="n in 12" :key="n" block />
      </template>
      <div
        v-for="item in result.items"
        :key="item.card.id"
        class="inventaire-cell"
        :class="{
          selected: selected.has(item.card.id),
          landscape: item.card.orientation === 'landscape'
        }"
      >
        <button
          v-if="selectMode"
          type="button"
          class="inventaire-pick"
          :class="{ selected: selected.has(item.card.id) }"
          :aria-label="item.card.name"
          :aria-pressed="selected.has(item.card.id)"
          @click.capture="onPickClick($event, item)"
          @keydown.enter.prevent="onPickEnter($event, item)"
        >
          <!-- inert : le lien de la vignette n'est ni cliquable ni exposé, le bouton porte tout. -->
          <span inert><CardTile :card="{ ...item.card, owned_qty: item.total_qty }" :preview="false" /></span>
        </button>
        <CardTile v-else :card="{ ...item.card, owned_qty: item.total_qty }" :preview="false" />
        <div class="inventaire-meta">
          <span v-if="item.entries.length === 1"> {{ item.entries[0].condition }} · {{ item.entries[0].lang }} </span>
          <span v-else :title="lotsTitle(item)">{{ item.entries.length }} lots</span>
          <span v-if="formatEur(item.value_eur)" class="inventaire-value" :title="PRICE_NOTE">
            {{ formatEur(item.value_eur) }}
          </span>
          <span>×{{ item.total_qty }}</span>
        </div>
      </div>
    </div>

    <RiftEmpty
      v-if="!loading && !error && !result.items.length && !result.unique_cards"
      title="Votre vitrine est encore vide"
      text="Notez vos exemplaires depuis une fiche carte."
    >
      <RiftButton to="/cartes">Parcourir les cartes</RiftButton>
    </RiftEmpty>
    <RiftEmpty v-else-if="!loading && !error && !result.items.length" title="Aucune carte ne correspond aux filtres">
      <RiftButton variant="secondary" size="sm" @click="reset">Réinitialiser les filtres</RiftButton>
    </RiftEmpty>

    <nav v-if="pageCount > 1" class="inventaire-pager" aria-label="Pagination">
      <RiftButton variant="ghost" size="sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</RiftButton>
      <span>page {{ state.page }} / {{ pageCount }}</span>
      <RiftButton variant="ghost" size="sm" :disabled="state.page >= pageCount" @click="state.page++">
        Suivant →
      </RiftButton>
    </nav>
  </div>

  <RiftSheet v-if="sheetOpen" title="Filtres" @close="sheetOpen = false">
    <CardFilters :state="state" :sets="sets" @update="setFilter" />
    <div class="inventaire-sheet-foot">
      <RiftButton block @click="sheetOpen = false">{{ sheetLabel }}</RiftButton>
    </div>
  </RiftSheet>

  <RiftModal v-if="pendingRemove" title="Retirer de la collection" @close="cancelRemove">
    <p>{{ selected.size }} carte(s) seront retirées de votre inventaire, sans retour en arrière possible.</p>
    <p v-if="removeError" class="inventaire-error" role="alert">{{ removeError }}</p>
    <div class="inventaire-modal-actions">
      <RiftButton variant="ghost" :disabled="bulk.busy" @click="cancelRemove">Annuler</RiftButton>
      <RiftButton :disabled="bulk.busy" @click="applyBulk({ remove: true })">
        {{ bulk.busy ? "Retrait…" : "Retirer" }}
      </RiftButton>
    </div>
  </RiftModal>
</template>

<style scoped>
.inventaire {
  display: grid;
  gap: var(--space-4);
  align-content: start;
}
.inventaire-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.inventaire-sort {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
.inventaire-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-left: auto;
}
.inventaire-bulk {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-3);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
  border-top: 2px solid var(--blood);
}
.inventaire-count {
  font-family: var(--font-label);
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
/* Action destructive : bordure et texte en rouge sang. */
.inventaire-bulk .inventaire-danger {
  border: 1px solid var(--blood-text);
  color: var(--blood-text);
}
.inventaire-sep {
  width: 1px;
  align-self: stretch;
  background: var(--line);
}
/* Neutralise l'habillage hérité des select (ombre de focus, fond, bordure). */
.inventaire-bulk select {
  width: auto;
  min-width: 0;
  min-height: 32px;
  padding: 0 var(--space-2);
  border: 1px solid var(--line);
  border-radius: 0;
  background: var(--bg-sunken);
  color: var(--ink);
  font: inherit;
  font-size: 13px;
  box-shadow: none;
}
.inventaire-bulk select:focus,
.inventaire-bulk select:focus-visible {
  box-shadow: none;
  border-color: var(--bronze-light);
  outline: 2px solid var(--bronze-light);
  outline-offset: 1px;
}
/* Sous 560 px, 16 px minimum : iOS zoomerait sur le champ sinon. */
@media (max-width: 560px) {
  .inventaire-bulk select {
    font-size: 16px;
  }
}
.inventaire-total {
  margin: 0;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.08em;
  color: var(--ink-muted);
}
.inventaire-error {
  margin: 0;
  color: var(--blood-text);
}
.inventaire-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(var(--tile-min, 180px), 1fr));
  gap: var(--space-4);
  transition: opacity var(--t-base);
}
.inventaire-grid.reloading {
  opacity: 0.55;
}
.inventaire-grid :deep(.rift-skeleton-block) {
  height: auto;
  aspect-ratio: 0.716;
}
.inventaire-cell {
  display: grid;
  gap: var(--space-1);
  align-content: start;
  min-width: 0;
}
.inventaire-cell.landscape {
  grid-column: span 2;
}
.inventaire-pick {
  display: block;
  width: 100%;
  padding: 0;
  border: 0;
  background: none;
  color: inherit;
  text-align: left;
  font: inherit;
  cursor: pointer;
}
.inventaire-pick:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.inventaire-pick.selected :deep(.rift-tile) {
  box-shadow: inset 0 0 0 2px var(--bronze-light);
  background: color-mix(in srgb, var(--bg-raised), var(--bronze-light) 12%);
}
.inventaire-pick.selected :deep(.tile-art)::after {
  content: "✓";
  position: absolute;
  top: var(--space-1);
  left: var(--space-1);
  display: grid;
  place-items: center;
  width: 24px;
  height: 24px;
  background: var(--bronze-light);
  color: var(--bg-sunken);
  font-weight: 700;
}
.inventaire-meta {
  display: flex;
  justify-content: space-between;
  gap: var(--space-2);
  padding: 0 var(--space-1);
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.inventaire-value {
  color: var(--bronze-light);
}
.inventaire-pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  font-family: var(--font-label);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.inventaire-sheet-foot {
  position: sticky;
  bottom: 0;
  margin-top: var(--space-4);
  padding-top: var(--space-3);
  background: var(--bg-raised);
}
.inventaire-modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-2);
  margin-top: var(--space-4);
}
</style>
