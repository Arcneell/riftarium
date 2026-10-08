<script setup>
import { computed, ref, watch } from "vue"
import { cardThumb, session } from "../api.js"
import CardFilters from "../cards/CardFilters.vue"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { formatEur } from "../prices.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import { pluralWord } from "../ui/french.js"

/* Galerie de l'éditeur de deck : toutes les cartes du jeu, possédées en couleur,
   manquantes grisées mais ajoutables. Composant de présentation : l'état des filtres
   (useQuerySyncedFilters) et les règles du deck (useDeckRules) restent dans la page. */
const props = defineProps({
  gallery: { type: Object, required: true },
  result: { type: Object, required: true },
  loading: { type: Boolean, default: false },
  activeCount: { type: Number, default: 0 },
  pageCount: { type: Number, default: 1 },
  sets: { type: Array, default: () => [] },
  inDeckQty: { type: Function, required: true },
  offDomain: { type: Function, required: true },
  tournament: { type: Boolean, default: false },
  shakes: { type: Object, required: true }
})
/* `page` : numéro de page voulu (borné entre 1 et pageCount) ; la page de l'éditeur écrit gallery.page
   (update passerait par setFilter, qui ramène à la page 1). */
const emit = defineEmits(["update", "reset", "add", "tile-pointerdown", "preview", "hide-preview", "page"])

const breakpoint = useBreakpoint()
const desktop = computed(() => breakpoint.value === "desktop")
const facetsOpen = ref(false)
const sheetOpen = ref(false)

watch(desktop, (isDesktop) => {
  if (isDesktop) sheetOpen.value = false
})

const OWNED_OPTIONS = [
  { value: "", label: "Toutes" },
  { value: "1", label: "Possédées" },
  { value: "0", label: "Manquantes" }
]

const isOwned = (card) => !session.token || (card.owned_qty ?? 0) > 0

function openFilters() {
  if (desktop.value) facetsOpen.value = !facetsOpen.value
  else sheetOpen.value = true
}

function goPage(delta) {
  const next = Math.min(Math.max(props.gallery.page + delta, 1), props.pageCount)
  if (next !== props.gallery.page) emit("page", next)
}

/* La page branche useGridMeasure sur la grille. */
const grid = ref(null)
defineExpose({ grid })
</script>

<template>
  <div class="galerie">
    <div class="galerie-bar">
      <div class="galerie-search">
        <RiftField
          search
          hide-label
          label="Rechercher une carte"
          placeholder="Jinx, ogn-202, reaction…"
          :model-value="gallery.q"
          inputmode="search"
          enterkeyhint="search"
          autocapitalize="off"
          autocorrect="off"
          spellcheck="false"
          @update:model-value="emit('update', 'q', $event)"
        />
      </div>
      <div class="galerie-actions">
        <RiftButton
          variant="secondary"
          size="sm"
          :aria-expanded="desktop ? String(facetsOpen) : undefined"
          :aria-controls="desktop && facetsOpen ? 'galerie-facets' : undefined"
          @click="openFilters"
        >
          Filtres<template v-if="activeCount"> ({{ activeCount }})</template>
        </RiftButton>
        <RiftChoice
          v-if="session.token"
          label="Filtrer par possession"
          :options="OWNED_OPTIONS"
          :model-value="gallery.owned"
          @update:model-value="emit('update', 'owned', $event)"
        />
        <RiftButton v-if="activeCount" variant="ghost" size="sm" @click="emit('reset')">Réinitialiser</RiftButton>
      </div>
    </div>

    <div v-if="desktop && facetsOpen" id="galerie-facets" class="galerie-facets">
      <CardFilters hide-search :state="gallery" :sets="sets" @update="(key, value) => emit('update', key, value)" />
    </div>

    <p class="galerie-count" aria-live="polite">
      {{ result.total }} {{ pluralWord(result.total, "carte", "cartes")
      }}<template v-if="loading"> · chargement…</template>
    </p>

    <div ref="grid" class="galerie-grid">
      <div v-for="card in result.items" :key="card.id" class="galerie-slot">
        <button
          type="button"
          class="galerie-card"
          :class="{
            unowned: !isOwned(card),
            indeck: inDeckQty(card) > 0,
            offdomain: tournament && offDomain(card),
            landscape: card.orientation === 'landscape',
            shake: shakes.has(card.id)
          }"
          :aria-label="`Ajouter ${card.name} au deck`"
          @click="emit('add', card)"
          @pointerdown="emit('tile-pointerdown', card, $event)"
          @mouseenter="emit('preview', card, $event)"
          @mouseleave="emit('hide-preview')"
          @focusin="emit('preview', card, $event)"
          @focusout="emit('hide-preview')"
        >
          <img
            class="galerie-img"
            :src="cardThumb(card.image_url, 320)"
            alt=""
            loading="lazy"
            decoding="async"
            draggable="false"
          />
          <!-- Rien pour les cartes manquantes : la vignette grisée suffit. -->
          <span v-if="session.token && card.owned_qty > 0" class="galerie-owned">×{{ card.owned_qty }}</span>
          <span v-if="inDeckQty(card)" class="galerie-indeck">{{ inDeckQty(card) }}</span>
          <span v-if="formatEur(card.price_eur)" class="galerie-price">{{ formatEur(card.price_eur) }}</span>
          <span class="galerie-add" aria-hidden="true">+</span>
        </button>
        <!-- Visible au tactile seulement : ouvre la fiche sans ajouter la carte. Sorti du
             bouton (un lien dans un bouton est du HTML invalide). -->
        <RouterLink
          class="galerie-info"
          :to="`/cartes/${card.id}`"
          :aria-label="`Voir la fiche de ${card.name}`"
          @pointerdown.stop
          >ℹ</RouterLink
        >
      </div>
    </div>

    <RiftEmpty v-if="!loading && !result.items.length" title="Aucune carte ne correspond aux filtres">
      <RiftButton v-if="activeCount" variant="secondary" size="sm" @click="emit('reset')">Réinitialiser</RiftButton>
    </RiftEmpty>

    <nav v-if="pageCount > 1" class="galerie-pager" aria-label="Pagination">
      <RiftButton variant="ghost" size="sm" :disabled="gallery.page <= 1" @click="goPage(-1)">← Précédent</RiftButton>
      <span>page {{ gallery.page }} / {{ pageCount }}</span>
      <RiftButton variant="ghost" size="sm" :disabled="gallery.page >= pageCount" @click="goPage(1)">
        Suivant →
      </RiftButton>
    </nav>

    <RiftSheet v-if="sheetOpen && !desktop" title="Filtres" @close="sheetOpen = false">
      <CardFilters hide-search :state="gallery" :sets="sets" @update="(key, value) => emit('update', key, value)" />
      <div class="galerie-sheet-foot">
        <RiftButton block @click="sheetOpen = false">
          {{ result.total ? `Voir les ${result.total} cartes` : "Aucune carte" }}
        </RiftButton>
      </div>
    </RiftSheet>
  </div>
</template>

<style scoped>
.galerie {
  display: grid;
  gap: var(--space-3);
  align-content: start;
}
.galerie-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.galerie-search {
  flex: 1 1 240px;
  min-width: 0;
}
.galerie-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}
.galerie-facets {
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.galerie-count {
  margin: 0;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.galerie-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(var(--tile-min, 150px), 1fr));
  gap: 14px;
}
/* Le bouton « ℹ » est un frère du bouton d'ajout : il se place sur ce calque. */
.galerie-slot {
  position: relative;
  display: grid;
}
/* Bouton redéfini ici : fond, filet et curseur ne viennent pas du style de base. */
.galerie-card {
  position: relative;
  display: block;
  padding: 0;
  border: none;
  border-radius: var(--radius-card);
  background: none;
  box-shadow: none;
  text-align: left;
  cursor: grab;
  transition: transform var(--t-base);
}
.galerie-card:hover {
  transform: translateY(-4px);
  z-index: 2;
}
.galerie-card:active {
  cursor: grabbing;
}
.galerie-card:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.galerie-img {
  display: block;
  width: 100%;
  aspect-ratio: 744 / 1039;
  object-fit: cover;
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-deep);
  transition:
    filter var(--t-base),
    opacity var(--t-base);
  -webkit-user-drag: none;
  user-select: none;
}
.galerie-card.landscape .galerie-img {
  aspect-ratio: 1038 / 744;
}
/* Carte absente de la collection : grisée mais toujours ajoutable. */
.galerie-card.unowned .galerie-img {
  filter: grayscale(0.8);
  opacity: 0.45;
}
.galerie-card.unowned:hover .galerie-img {
  opacity: 0.8;
}
.galerie-card.indeck .galerie-img {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
/* Hors domaine en tournoi : estompée et hachurée. */
.galerie-card.offdomain .galerie-img {
  opacity: 0.35;
}
.galerie-card.offdomain::after {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: var(--radius-card);
  background: repeating-linear-gradient(135deg, transparent 0 6px, rgba(0, 0, 0, 0.55) 6px 9px);
  pointer-events: none;
}
.galerie-owned {
  z-index: 1;
  position: absolute;
  left: 7px;
  bottom: 7px;
  padding: 2px 8px;
  background: rgba(13, 13, 15, 0.92);
  box-shadow: inset 0 0 0 1px var(--bronze);
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.04em;
  pointer-events: none;
}
.galerie-indeck {
  z-index: 1;
  position: absolute;
  top: 7px;
  right: 7px;
  min-width: 26px;
  height: 26px;
  padding: 0 6px;
  display: grid;
  place-items: center;
  background: var(--blood);
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 14px;
  font-weight: 700;
  pointer-events: none;
}
.galerie-price {
  z-index: 1;
  position: absolute;
  right: 7px;
  bottom: 7px;
  padding: 2px 6px;
  background: rgba(13, 13, 15, 0.92);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 13px;
  pointer-events: none;
}
.galerie-add {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  font-size: 2rem;
  font-weight: 300;
  color: var(--ink);
  text-shadow: 0 2px 12px rgba(0, 0, 0, 0.9);
  background: radial-gradient(closest-side, rgba(0, 0, 0, 0.45), transparent 75%);
  border-radius: var(--radius-card);
  opacity: 0;
  transition: opacity var(--t-fast);
  pointer-events: none;
}
.galerie-card:hover .galerie-add,
.galerie-card:focus-visible .galerie-add {
  opacity: 1;
}
.galerie-card.shake {
  animation: galerie-shake 300ms;
}
@keyframes galerie-shake {
  20% {
    transform: translateX(-6px);
  }
  40% {
    transform: translateX(5px);
  }
  60% {
    transform: translateX(-4px);
  }
  80% {
    transform: translateX(3px);
  }
}
.galerie-info {
  display: none;
}
@media (hover: none) {
  .galerie-info {
    position: absolute;
    top: 6px;
    left: 6px;
    display: grid;
    place-items: center;
    width: 44px;
    height: 44px;
    border-radius: 50%;
    background: rgba(13, 13, 15, 0.92);
    box-shadow: inset 0 0 0 1px var(--bronze);
    color: var(--ink);
    font-family: var(--font-label);
    font-size: 15px;
    text-decoration: none;
  }
  .galerie-info:focus-visible {
    outline: 2px solid var(--bronze-light);
  }
}
.galerie-pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  font-family: var(--font-label);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.galerie-sheet-foot {
  position: sticky;
  bottom: 0;
  margin-top: var(--space-4);
  padding-top: var(--space-3);
  background: var(--bg-raised);
}
@media (prefers-reduced-motion: reduce) {
  .galerie-card,
  .galerie-img,
  .galerie-add {
    transition: none;
  }
  .galerie-card.shake {
    animation: none;
  }
  .galerie-card:hover {
    transform: none;
  }
}
</style>
