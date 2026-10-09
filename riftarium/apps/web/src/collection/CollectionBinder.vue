<script setup>
import { computed, onBeforeUnmount, onMounted, watch } from "vue"
import { RouterLink } from "vue-router"
import { cardThumb, session } from "../api.js"
import { isFoil } from "../cardText.js"
import { PRICE_NOTE, formatEur, missingCardsText as missingText } from "../prices.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import QuickAddPref from "./QuickAddPref.vue"
import QuickCount from "./QuickCount.vue"
import { useQuickAdd } from "./useQuickAdd.js"
import { GHOST_FILTERS, useCollectionBinder } from "./useCollectionBinder.js"

/* Classeur de la collection : onglets de sets, double page de 3×3 pochettes,
   cartes manquantes en fantôme. La logique vit dans useCollectionBinder. */
const props = defineProps({
  progress: { type: Object, default: null }, // { sets: [...], overall }
  active: { type: Boolean, default: true },
  /* Incrémentée par la page quand les données ont changé : la double page est rechargée. */
  version: { type: Number, default: 0 },
  /* Message d'échec du chargement de la progression : remplace le squelette sans fin. */
  progressError: { type: String, default: "" }
})

const emit = defineEmits(["changed"])

const {
  binderSet,
  binderPage,
  binderOwned,
  binderLoading,
  binderError,
  spread,
  turnDir,
  leftCards,
  rightCards,
  selectSet,
  setGhostFilter,
  turnPage,
  loadBinder,
  invalidate,
  onKeydown
} = useCollectionBinder({
  active: () => props.active,
  isBlocked: () => document.body.classList.contains("nav-locked")
})

/* Saisie rapide (membres) : un compteur sur chaque pochette, pleine ou fantôme. */
const { quickOn, toggleQuick, defaults: quickDefaults, setDefaults: setQuickDefaults } = useQuickAdd()

/* La pochette suit le compteur sans recharger la double page : un fantôme devient plein
   à 1 exemplaire, une pochette pleine redevient fantôme à 0. La page recharge la progression. */
function onQuickChange({ id, owned_qty }) {
  const item = spread.value?.items.find((card) => card.id === id)
  if (item) item.owned_qty = owned_qty
  /* La page a tourné pendant l'écriture : la double page affichée vient d'une lecture
     peut-être antérieure à la mutation. On la recharge sans voile pour ne laisser aucune
     pochette périmée. */
  else loadBinder({ silent: true })
  emit("changed")
}

const sets = computed(() => props.progress?.sets || [])
const currentSet = computed(() => sets.value.find((row) => row.set_id === binderSet.value) || null)
/* Classeur vide : l'état vide remplace tout, sauf en saisie rapide (sinon retirer la dernière
   carte ferait disparaître les compteurs, et un membre ne pourrait pas commencer ici). */
const isEmptyCollection = computed(() => !!props.progress && props.progress.overall?.owned === 0 && !quickOn.value)

function percentOf(row) {
  if (!row.total) return 0
  return Math.round((row.owned / row.total) * 100)
}

/* Set ouvert par défaut : le premier incomplet, celui qu'on a envie de finir. Rien à ouvrir
   tant que l'état vide est affiché (collection à 0, hors saisie rapide). */
function openDefaultSet() {
  const progress = props.progress
  if (!binderSet.value && progress?.sets?.length && !isEmptyCollection.value) {
    binderSet.value = (progress.sets.find((row) => row.missing) || progress.sets[0]).set_id
  }
}
watch(() => [props.progress, quickOn.value], openDefaultSet, { immediate: true })

watch(
  () => props.active,
  (active) => {
    if (active && !spread.value) loadBinder()
  },
  { immediate: true }
)

watch(
  () => props.version,
  () => {
    invalidate()
    if (props.active) loadBinder()
  }
)

/* Les boutons de set n'ont aucune flèche native (contrairement à un tablist) :
   les flèches feuillettent partout, sauf dans un champ (géré par onKeydown). */
onMounted(() => window.addEventListener("keydown", onKeydown))
onBeforeUnmount(() => window.removeEventListener("keydown", onKeydown))
</script>

<template>
  <div class="classeur">
    <RiftEmpty v-if="isEmptyCollection" title="Votre classeur est vide">
      <RiftButton to="/cartes">Parcourir les cartes</RiftButton>
      <RiftChip v-if="session.token" label="Saisie rapide" :selected="quickOn" @toggle="toggleQuick" />
    </RiftEmpty>

    <p v-else-if="!progress && progressError" class="classeur-error" role="alert">
      Impossible de charger le classeur : {{ progressError }}
    </p>

    <template v-else>
      <div v-if="progress" class="classeur-tabs" role="group" aria-label="Sets du classeur">
        <button
          v-for="row in sets"
          :key="row.set_id"
          type="button"
          class="classeur-tab"
          :class="{ active: row.set_id === binderSet, done: !row.missing }"
          :aria-pressed="row.set_id === binderSet"
          :title="missingText(row)"
          @click="selectSet(row.set_id)"
        >
          <span class="classeur-tab-top">
            <span>{{ row.name }}</span>
            <span v-if="!row.missing" class="classeur-tab-pct">
              <span aria-hidden="true">✓</span><span class="sr-only"> set complet</span>
            </span>
            <span v-else class="classeur-tab-pct">{{ percentOf(row) }} %</span>
          </span>
          <span class="classeur-tab-bar" aria-hidden="true"><b :style="{ width: `${percentOf(row)}%` }"></b></span>
        </button>
      </div>

      <p v-if="binderError" class="classeur-error" role="alert">{{ binderError }}</p>

      <header class="classeur-head">
        <div>
          <h2 class="classeur-title">{{ currentSet ? currentSet.name : "Classeur" }}</h2>
          <p v-if="currentSet" class="classeur-sub" :title="PRICE_NOTE">
            {{ currentSet.owned }}/{{ currentSet.total }} · {{ percentOf(currentSet) }} % ·
            {{ missingText(currentSet) }}
          </p>
        </div>
        <div class="classeur-head-actions">
          <RiftChip v-if="session.token" label="Saisie rapide" :selected="quickOn" @toggle="toggleQuick" />
          <div class="classeur-chips" role="group" aria-label="Filtrer les pochettes">
            <RiftChip
              v-for="chip in GHOST_FILTERS"
              :key="chip.value"
              :label="chip.label"
              :selected="binderOwned === chip.value"
              @toggle="setGhostFilter(chip.value)"
            />
          </div>
        </div>
      </header>

      <QuickAddPref v-if="quickOn" :defaults="quickDefaults" @update="setQuickDefaults" />

      <div class="classeur-stage" :class="{ loading: binderLoading }">
        <Transition
          :name="turnDir < 0 ? 'classeur-prev' : 'classeur-next'"
          mode="out-in"
          :duration="{ leave: 90, enter: 110 }"
        >
          <div v-if="spread && spread.items.length" :key="spread.key" class="classeur-spread">
            <div v-for="(page, side) in [leftCards, rightCards]" :key="side" class="classeur-page-wrap">
              <div class="classeur-page">
                <template v-for="(card, i) in page" :key="card ? card.id : `${side}-${i}`">
                  <RouterLink
                    v-if="card"
                    class="classeur-pocket"
                    :class="{
                      ghost: !card.owned_qty,
                      foil: isFoil(card),
                      quick: quickOn,
                      landscape: card.orientation === 'landscape'
                    }"
                    :to="`/cartes/${card.id}`"
                    :title="card.owned_qty ? card.name : `Carte manquante : ${card.name}`"
                  >
                    <img
                      :src="cardThumb(card.image_url, 320)"
                      :alt="card.owned_qty ? `Carte Riftbound : ${card.name}` : `Carte manquante : ${card.name}`"
                      loading="lazy"
                      decoding="async"
                    />
                    <span v-if="card.owned_qty && !quickOn" class="classeur-qty">×{{ card.owned_qty }}</span>
                    <template v-else>
                      <span class="classeur-num">{{ (card.riftbound_id || "").toUpperCase() }}</span>
                      <span v-if="formatEur(card.price_eur)" class="classeur-price" :title="PRICE_NOTE">
                        {{ formatEur(card.price_eur) }}
                      </span>
                    </template>
                    <span class="classeur-sheen" aria-hidden="true"></span>
                    <QuickCount v-if="quickOn" :card="card" :defaults="quickDefaults" @change="onQuickChange" />
                  </RouterLink>
                  <span v-else class="classeur-pocket blank" aria-hidden="true"></span>
                </template>
              </div>
              <div v-if="side === 0" class="classeur-spine" aria-hidden="true"><i></i><i></i><i></i></div>
            </div>
          </div>

          <RiftEmpty
            v-else-if="spread"
            key="empty"
            :title="
              binderOwned === '0'
                ? 'Rien ne manque ici'
                : binderOwned === '1'
                  ? 'Aucune carte possédée dans ce set'
                  : 'Classeur vide'
            "
            :text="
              binderOwned === '0'
                ? 'Vous avez toutes les cartes de ce set.'
                : 'Ouvrez une fiche carte pour remplir les pochettes.'
            "
          />

          <div v-else key="skeleton" class="classeur-spread" aria-hidden="true">
            <div v-for="side in 2" :key="side" class="classeur-page-wrap">
              <div class="classeur-page">
                <span v-for="n in 9" :key="n" class="classeur-pocket blank shimmer"></span>
              </div>
              <div v-if="side === 1" class="classeur-spine"><i></i><i></i><i></i></div>
            </div>
          </div>
        </Transition>
      </div>

      <div v-if="spread && spread.pages > 1" class="classeur-nav">
        <RiftButton
          variant="ghost"
          size="sm"
          :disabled="binderPage <= 1 || binderLoading"
          aria-label="Double page précédente"
          @click="turnPage(-1)"
        >
          ← Tourner
        </RiftButton>
        <span class="classeur-count" aria-live="polite">{{ spread.page }} / {{ spread.pages }}</span>
        <RiftButton
          variant="ghost"
          size="sm"
          :disabled="binderPage >= spread.pages || binderLoading"
          aria-label="Double page suivante"
          @click="turnPage(1)"
        >
          Tourner →
        </RiftButton>
      </div>
    </template>
  </div>
</template>

<style scoped>
.classeur {
  display: grid;
  gap: var(--space-4);
}
.classeur-error {
  color: var(--blood-text);
}

/* Onglets de sets */
.classeur-tabs {
  display: flex;
  gap: var(--space-2);
  overflow-x: auto;
  padding-bottom: var(--space-1);
}
.classeur-tab {
  flex: 0 0 auto;
  display: grid;
  gap: 6px;
  min-width: 140px;
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--line);
  background: var(--bg-sunken);
  color: var(--ink-muted);
  font-family: var(--font-label);
  text-align: left;
  cursor: pointer;
  box-shadow: none;
}
.classeur-tab:hover {
  color: var(--ink);
  border-color: var(--bronze);
}
.classeur-tab.active {
  color: var(--ink);
  border-color: var(--bronze-light);
  background: var(--bg-raised);
}
.classeur-tab-top {
  display: flex;
  justify-content: space-between;
  gap: var(--space-2);
  font-size: 13px;
  font-weight: 600;
}
.classeur-tab-pct {
  color: var(--bronze-light);
  font-variant-numeric: tabular-nums;
}
.classeur-tab-bar {
  display: block;
  height: 3px;
  background: var(--line);
}
.classeur-tab-bar b {
  display: block;
  height: 100%;
  background: var(--bronze);
}
.classeur-tab.done .classeur-tab-bar b {
  background: var(--bronze-light);
}

/* En-tête */
.classeur-head {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--space-3);
}
.classeur-title {
  margin: 0;
  font-family: var(--font-display);
  font-size: 24px;
  font-weight: 700;
  line-height: 1.2;
  color: var(--ink);
  letter-spacing: 0;
  text-transform: none;
}
.classeur-sub {
  margin: var(--space-1) 0 0;
  color: var(--ink-muted);
  font-size: 13px;
  font-variant-numeric: tabular-nums;
}
.classeur-head-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.classeur-chips {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

/* Double page */
.classeur-stage {
  transition: opacity 0.15s;
}
.classeur-stage.loading {
  opacity: 0.7;
}
.classeur-spread {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4);
}
.classeur-page-wrap {
  position: relative;
  min-width: 0;
}
.classeur-page {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
  padding: var(--space-3);
  background: var(--bg-sunken);
  border-top: 2px solid var(--bronze);
  clip-path: polygon(
    var(--cut) 0,
    100% 0,
    100% calc(100% - var(--cut)),
    calc(100% - var(--cut)) 100%,
    0 100%,
    0 var(--cut)
  );
}
.classeur-spine {
  position: absolute;
  top: 50%;
  right: calc(var(--space-4) / -2);
  transform: translate(50%, -50%);
  display: grid;
  gap: 28px;
  z-index: 1;
}
.classeur-spine i {
  display: block;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 2px solid var(--bronze);
  background: var(--bg);
}

/* Pochettes */
.classeur-pocket {
  position: relative;
  display: block;
  aspect-ratio: 5 / 7;
  overflow: hidden;
  border: 1px solid var(--line);
  background: var(--bg);
  border-radius: var(--radius-s);
}
/* Une pochette est étroite (≈ 96 px à 375 px, ≈ 92 px à 721 px, deux pages côte à côte) : le
   compteur rapide perd son retrait et se resserre (≈ 77 px au lieu de ~114). */
.classeur-pocket .quick-count {
  padding-inline: 0;
}
.classeur-pocket .quick-count :deep(.rift-stepper--sm) {
  --stepper-size: 28px;
  gap: var(--space-1);
}
.classeur-pocket .quick-count :deep(.rift-stepper--sm .rift-stepper-plus) {
  width: var(--stepper-size);
}
.classeur-pocket img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
/* Carte paysage : l'image pivotée occupe exactement la pochette (5/7). */
.classeur-pocket.landscape img {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 140%;
  height: 71.4%;
  transform: translate(-50%, -50%) rotate(90deg);
}
.classeur-pocket:hover,
.classeur-pocket:focus-visible {
  border-color: var(--bronze-light);
}
.classeur-pocket.blank {
  background: transparent;
  border-style: dashed;
}
.classeur-pocket.blank:hover {
  border-color: var(--line);
}
.classeur-pocket.ghost img {
  filter: grayscale(1);
  opacity: 0.28;
}
.classeur-pocket.ghost:hover img,
.classeur-pocket.ghost:focus-visible img {
  opacity: 0.5;
}
.classeur-qty,
.classeur-num,
.classeur-price {
  position: absolute;
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  padding: 3px 5px;
  background: rgba(0, 0, 0, 0.72);
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.classeur-qty {
  top: 4px;
  right: 4px;
  color: var(--bronze-light);
}
.classeur-num {
  left: 4px;
  bottom: 4px;
  color: var(--ink-muted);
}
.classeur-price {
  right: 4px;
  bottom: 4px;
  color: var(--bronze-light);
}
/* Saisie rapide : le compteur occupe le bas de la pochette, le code et le prix passent en haut. */
.classeur-pocket.quick .classeur-num {
  top: 4px;
  bottom: auto;
}
.classeur-pocket.quick .classeur-price {
  top: 4px;
  right: 4px;
  bottom: auto;
}
.classeur-sheen {
  position: absolute;
  inset: 0;
  background: linear-gradient(115deg, transparent 35%, rgba(255, 255, 255, 0.28) 50%, transparent 65%);
  background-size: 250% 100%;
  background-position: 120% 0;
  opacity: 0;
  pointer-events: none;
}
.classeur-pocket.foil:not(.ghost):hover .classeur-sheen,
.classeur-pocket.foil:not(.ghost):focus-visible .classeur-sheen {
  opacity: 1;
  background-position: -20% 0;
  transition: background-position 0.6s ease-out;
}
.classeur-pocket.shimmer {
  background: linear-gradient(100deg, var(--bg-sunken) 40%, var(--bg-raised) 50%, var(--bg-sunken) 60%);
  background-size: 220% 100%;
  animation: classeur-shimmer 1.4s linear infinite;
}
@keyframes classeur-shimmer {
  from {
    background-position: 120% 0;
  }
  to {
    background-position: -120% 0;
  }
}

/* Navigation */
.classeur-nav {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-4);
}
.classeur-count {
  font-family: var(--font-label);
  font-variant-numeric: tabular-nums;
  color: var(--ink-muted);
}

/* Tournage : fondu + glissement de 12 px (200 ms au total) */
.classeur-next-leave-active,
.classeur-prev-leave-active {
  transition:
    opacity 90ms ease-in,
    transform 90ms ease-in;
}
.classeur-next-enter-active,
.classeur-prev-enter-active {
  transition:
    opacity 110ms ease-out,
    transform 110ms ease-out;
}
.classeur-next-leave-to,
.classeur-prev-enter-from {
  opacity: 0;
  transform: translateX(-12px);
}
.classeur-next-enter-from,
.classeur-prev-leave-to {
  opacity: 0;
  transform: translateX(12px);
}

@media (max-width: 720px) {
  .classeur-spread {
    grid-template-columns: 1fr;
  }
  .classeur-spine {
    display: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .classeur-next-leave-active,
  .classeur-prev-leave-active,
  .classeur-next-enter-active,
  .classeur-prev-enter-active,
  .classeur-stage,
  .classeur-pocket.foil .classeur-sheen {
    transition: none;
  }
  .classeur-pocket.shimmer {
    animation: none;
  }
  .classeur-next-leave-to,
  .classeur-prev-enter-from,
  .classeur-next-enter-from,
  .classeur-prev-leave-to {
    transform: none;
  }
}
</style>
