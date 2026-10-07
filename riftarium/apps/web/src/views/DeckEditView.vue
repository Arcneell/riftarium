<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, cardThumb, TYPES, RARITIES, session } from "../api.js"
import { cardsQuery } from "../cardText.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftModal from "../ui/RiftModal.vue"
import RiftSegments from "../ui/RiftSegments.vue"
import RiftText from "../ui/RiftText.vue"
import DeckEditorBar from "../decks/DeckEditorBar.vue"
import DeckExportBar from "../decks/DeckExportBar.vue"
import DeckGallery from "../decks/DeckGallery.vue"
import DeckList from "../decks/DeckList.vue"
import DeckMissingModal from "../decks/DeckMissingModal.vue"
import DeckStatsPanel from "../decks/DeckStatsPanel.vue"
import DeckView from "../decks/DeckView.vue"
import { useDeckDrag } from "../decks/useDeckDrag.js"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { useDeckAutosave } from "../composables/useDeckAutosave.js"
import { useDeckRules } from "../composables/useDeckRules.js"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { formatLabel } from "../deckDisplay.js"
import { formatEur } from "../prices.js"
import { applySeo, pageUrl } from "../seo.js"

const route = useRoute()
const router = useRouter()
const deck = ref(null)
const error = ref("")
const limitMessage = ref("")
const showExport = ref(false)

const finePointer = typeof window !== "undefined" && window.matchMedia("(hover: hover) and (pointer: fine)").matches
const reducedMotion = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches

/* ---------- Sauvegarde automatique ---------- */

const snapshot = () =>
  JSON.stringify({
    name: deck.value.name,
    description: deck.value.description,
    format: deck.value.format,
    is_public: deck.value.is_public,
    cards: deck.value.cards.map((entry) => [entry.card.id, entry.qty])
  })

async function persistDeck() {
  const fresh = await api(`/api/decks/${deck.value.id}`, {
    method: "PUT",
    body: {
      name: deck.value.name,
      description: deck.value.description,
      format: deck.value.format,
      is_public: deck.value.is_public,
      cards: deck.value.cards.map((entry) => ({ card_id: entry.card.id, qty: entry.qty }))
    }
  })
  /* On ne remplace pas l'état local (l'utilisateur tape peut-être) : on rapatrie le calculé. */
  deck.value.checks = fresh.checks
  deck.value.moderation_status = fresh.moderation_status
  deck.value.updated_at = fresh.updated_at
}

/* Monté en premier : son save de secours part avant les autres démontages. */
const { saveState, sessionExpired, save, markSaved } = useDeckAutosave(deck, persistDeck, {
  snapshot,
  canEdit: () => canEdit.value,
  error
})

/* Session expirée pendant l'édition : on garde le brouillon affiché et modifiable localement. */
const canEdit = computed(() =>
  Boolean(deck.value && (sessionExpired.value || (session.handle && session.handle === deck.value.owner)))
)

/* La barre d'édition ne touche pas au deck : la page applique ce qu'elle émet.
   Un deck a toujours un format : une valeur vide garde le format courant. */
function setFormat(value) {
  deck.value.format = value || deck.value.format
}

/* ---------- Mise en page : trois zones, onglets sur téléphone ---------- */

const breakpoint = useBreakpoint()
const isMobile = computed(() => breakpoint.value === "mobile")
const tab = ref("cards") // cards | deck | stats
/* Hors onglet Deck sur téléphone, le plafond s'affiche en toast : la région live reste montée. */
const toastText = computed(() => (isMobile.value && tab.value !== "deck" ? limitMessage.value : ""))

const totalCards = computed(() => (deck.value?.cards || []).reduce((total, entry) => total + entry.qty, 0))
const failingRule = computed(() => (deck.value?.checks || []).some((item) => !item.ok))
const tabs = computed(() => [
  { value: "cards", label: "Cartes" },
  { value: "deck", label: "Deck", badge: totalCards.value },
  {
    value: "stats",
    label: "Analyse",
    badge: failingRule.value ? "✕" : null,
    badgeLabel: "règle non respectée"
  }
])

/* Sur téléphone seulement, chaque zone devient un panneau d'onglet (toujours monté). */
function paneAttrs(name) {
  if (!isMobile.value) return {}
  return { role: "tabpanel", id: `atelier-panel-${name}`, "aria-labelledby": `atelier-tab-${name}` }
}
const paneShown = (name) => !isMobile.value || tab.value === name

/* ---------- Retour visuel des mutations ---------- */

const flashes = reactive(new Set())
const shakes = reactive(new Set())
let limitTimer = null
const pulseTimers = new Set()

function pulse(set, key, duration = 600) {
  set.add(key)
  const timer = setTimeout(() => {
    set.delete(key)
    pulseTimers.delete(timer)
  }, duration)
  pulseTimers.add(timer)
}

function notify(message) {
  limitMessage.value = message
  clearTimeout(limitTimer)
  limitTimer = setTimeout(() => (limitMessage.value = ""), 2600)
}

/* ---------- Règles de construction (zones, plafonds, identité de domaines) ---------- */

const {
  ZONES,
  LIST_ZONES,
  grouped,
  zoneCounts,
  inDeckQty,
  legendEntry,
  legendRunes,
  offDomain,
  addCard,
  setQty,
  removeOne
} = useDeckRules(deck, {
  canEdit,
  onLimit: (message, cardId) => {
    pulse(shakes, cardId, 500)
    notify(message)
  },
  onNotice: notify,
  onAdded: (card) => pulse(flashes, card.id)
})

const missingInDeck = computed(() =>
  (deck.value?.cards || []).reduce((total, entry) => total + Math.max(0, entry.qty - (entry.card.owned_qty ?? 0)), 0)
)

/* ---------- Galerie filtrable ---------- */

/* DeckGallery expose sa grille : la mesure suit le nœud courant. */
const galleryRef = ref(null)
const { tileMin, size, measure, observe } = useGridMeasure(
  computed(() => galleryRef.value?.grid),
  {
    tileMin: 150,
    size: 24,
    maxSize: 60,
    tileFloor: 112,
    debounce: 160,
    gap: () => 14,
    minCol: () => 132,
    rows: (height) => (height >= 1000 ? 5 : 4),
    fallbackWidth: () => 720
  }
)

const {
  state: gallery,
  result,
  loading,
  activeCount,
  pageCount,
  setFilter,
  reset: resetFilters,
  load: loadGallery,
  scheduleLoad: scheduleGallery
} = useQuerySyncedFilters(
  {
    q: { kind: "text" },
    set_id: { kind: "list" },
    type: { kind: "list" },
    domain: { kind: "list" },
    rarity: { kind: "list" },
    energy: { kind: "list" },
    owned: { kind: "text" },
    page: { kind: "page" }
  },
  {
    /* Pas de synchronisation d'URL : la barre d'adresse reste celle du deck. */
    syncUrl: false,
    fetcher: (filters) => api(`/api/cards?${cardsQuery(filters, size.value)}`),
    pageSize: size,
    enabled: () => canEdit.value,
    error,
    clearErrorOnLoad: false
  }
)

const sets = ref([])
/* CardFilters attend des options { value, label } : on adapte la réponse de /api/sets. */
const setOptions = computed(() => sets.value.map((s) => ({ value: s.set_id, label: s.name })))

/* La taille de page suit la grille : on recharge, sauf si la page courante
   n'existe plus après un agrandissement. */
watch(size, () => {
  if (gallery.page > pageCount.value) gallery.page = 1
  else scheduleGallery()
})

/* La légende vient d'être choisie : on rouvre la galerie sur toutes les cartes. */
watch(legendEntry, (next, previous) => {
  if (next && !previous && gallery.type.length === 1 && gallery.type[0] === "Legend") {
    gallery.type = []
    gallery.page = 1
  }
})

/* « Voir les légendes » : sur téléphone, la galerie est dans un autre onglet. */
function showLegends() {
  setFilter("type", ["Legend"])
  if (isMobile.value) tab.value = "cards"
}

/* ---------- Aperçu lisible au survol ---------- */

const preview = ref(null) // { card, x, y, large }

function showPreview(card, event, width = 320) {
  if (!finePointer || drag.active) return
  const rect = event.currentTarget.getBoundingClientRect()
  const rightSpace = window.innerWidth - rect.right
  const x = rightSpace > width + 28 ? rect.right + 14 : Math.max(10, rect.left - width - 14)
  const y = Math.min(Math.max(12, rect.top - 40), Math.max(12, window.innerHeight - (width > 320 ? 620 : 480)))
  preview.value = { card, x, y, large: width > 320 }
}

function hidePreview() {
  preview.value = null
}

/* ---------- Glisser-déposer façon table de jeu ---------- */

/* DeckList expose la racine de la liste : relue à chaque mouvement par useDeckDrag. */
const deckListRef = ref(null)
const {
  drag,
  onTilePointerDown,
  suppressClick,
  dispose: disposeDrag
} = useDeckDrag({
  enabled: () => canEdit.value,
  finePointer,
  reducedMotion,
  panel: computed(() => deckListRef.value?.panel),
  onDropAdd: (card) => addCard(card),
  onDropRemove: (cardId) => removeOne(cardId),
  onStart: hidePreview
})

const ghostHint = computed(() => {
  if (drag.from === "deck") return drag.overDeck ? "" : "Relâchez pour retirer"
  return drag.overDeck ? "Ajouter au deck" : ""
})

function onTileClick(card) {
  if (suppressClick()) return
  addCard(card)
}

/* ---------- Like ---------- */

const likeBusy = ref(false)

async function toggleLike() {
  if (!deck.value || likeBusy.value) return
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: `/decks/${deck.value.id}` } })
    return
  }
  likeBusy.value = true
  try {
    const payload = await api(`/api/decks/${deck.value.id}/like`, { method: "POST" })
    deck.value.likes = payload.likes
    deck.value.liked_by_me = payload.liked_by_me
  } catch (e) {
    error.value = e.message
  } finally {
    likeBusy.value = false
  }
}

/* ---------- Cartes manquantes ---------- */

const showMissing = ref(false)
const missing = ref(null)
const missingError = ref("")

async function openMissing() {
  showMissing.value = true
  missing.value = null
  missingError.value = ""
  await save()
  try {
    missing.value = await api(`/api/decks/${deck.value.id}/missing`)
  } catch (e) {
    missingError.value = e.message
  }
}

function closeMissing() {
  hidePreview()
  showMissing.value = false
}

/* ---------- Cycle de vie ---------- */

/* Jeton de séquence : deux chargements rapprochés (variantes de l'URL, retour
   arrière) doivent laisser l'autosave travailler sur le dernier deck, pas sur
   une réponse en retard. */
let loadSeq = 0

async function load() {
  const mine = ++loadSeq
  try {
    const loaded = await api(`/api/decks/${route.params.id}`)
    if (mine !== loadSeq) return
    deck.value = loaded
    sessionExpired.value = false
    markSaved()
    const hasLegend = deck.value.cards.some((entry) => entry.card.type === "Legend")
    /* Sur téléphone : on ouvre sur le deck s'il a sa légende, sinon sur les cartes pour la choisir. */
    tab.value = hasLegend ? "deck" : "cards"
    if (canEdit.value && !hasLegend) gallery.type = ["Legend"]
    if (!canEdit.value && deck.value.is_public && deck.value.moderation_status === "published") {
      try {
        const seen = await api(`/api/decks/${deck.value.id}/view`, { method: "POST" })
        if (mine !== loadSeq) return
        deck.value.views = seen.views
      } catch {
        /* compteur de vues non bloquant */
      }
    }
    const publicDeck = deck.value.is_public && deck.value.moderation_status === "published"
    applySeo({
      title: `${deck.value.name} — Deck Riftbound`,
      description:
        (deck.value.description || "").trim().slice(0, 160) ||
        `Deck Riftbound « ${deck.value.name} » (${formatLabel(deck.value.format)}) sur Riftarium.`,
      path: route.path,
      noindex: !publicDeck,
      /* Image de partage dessinée par l'API (les robots, eux, passent par /preview). */
      image: publicDeck ? pageUrl(`/api/decks/${deck.value.id}/og.png`) : undefined
    })
  } catch (e) {
    if (mine === loadSeq) error.value = e.message
  }
}

watch(
  () => route.params.id,
  async () => {
    /* Transition sortante : l'id devient undefined, on ne vide pas le deck avant le save de secours. */
    if (!route.params.id) return
    deck.value = null
    await load()
  },
  { immediate: true }
)

onMounted(async () => {
  window.addEventListener("scroll", hidePreview, { passive: true })
  try {
    sets.value = await api("/api/sets")
  } catch {
    /* filtre sets indisponible */
  }
})

watch(canEdit, async (edit) => {
  if (!edit) return
  loadGallery()
  await nextTick()
  measure()
  observe()
})

onBeforeUnmount(() => {
  /* Le save de rattrapage part avant : useDeckAutosave a été monté en premier. */
  clearTimeout(limitTimer)
  for (const timer of pulseTimers) clearTimeout(timer)
  pulseTimers.clear()
  window.removeEventListener("scroll", hidePreview)
  /* Démontage en plein glisser : écouteurs de window et classe du body retirés. */
  disposeDrag()
})
</script>

<template>
  <!-- Deck absent : l'erreur est portée par la branche v-else en bas de ce fichier. -->
  <DeckView v-if="deck && !canEdit" :deck="deck" :like-busy="likeBusy" @like="toggleLike" />
  <div v-else-if="deck" class="atelier-page">
    <h1 class="sr-only">Édition du deck {{ deck.name }}</h1>
    <DeckEditorBar
      :deck="deck"
      :can-edit="canEdit"
      :save-state="saveState"
      :error="error"
      :like-busy="likeBusy"
      @like="toggleLike"
      @export="showExport = true"
      @update:name="deck.name = $event"
      @update:format="setFormat"
      @update:public="deck.is_public = $event"
    />
    <p v-if="deck.moderation_status === 'pending'" class="atelier-moderation" role="status">
      En attente de modération : ce deck n'est pas visible publiquement.
    </p>

    <RiftSegments v-if="isMobile" v-model="tab" :items="tabs" label="Zones de l'éditeur" id-base="atelier" />

    <div class="atelier">
      <div
        v-show="paneShown('cards')"
        class="atelier-pane atelier-pane--cards"
        v-bind="paneAttrs('cards')"
        :style="{ '--tile-min': `${tileMin}px` }"
      >
        <DeckGallery
          ref="galleryRef"
          :gallery="gallery"
          :result="result"
          :loading="loading"
          :active-count="activeCount"
          :page-count="pageCount"
          :sets="setOptions"
          :in-deck-qty="inDeckQty"
          :off-domain="offDomain"
          :tournament="deck.format === 'tournament'"
          :shakes="shakes"
          @update="setFilter"
          @reset="resetFilters"
          @add="onTileClick"
          @tile-pointerdown="(card, event) => onTilePointerDown(card, 'gallery', event)"
          @preview="showPreview"
          @hide-preview="hidePreview"
          @page="gallery.page = $event"
        />
      </div>

      <div v-show="paneShown('deck')" class="atelier-pane atelier-pane--deck" v-bind="paneAttrs('deck')">
        <DeckList
          ref="deckListRef"
          :deck="deck"
          :can-edit="canEdit"
          :zones="ZONES"
          :list-zones="LIST_ZONES"
          :grouped="grouped"
          :zone-counts="zoneCounts"
          :legend-entry="legendEntry"
          :legend-runes="legendRunes"
          :flashes="flashes"
          :limit-message="limitMessage"
          :missing-in-deck="missingInDeck"
          :drag="drag"
          :fine-pointer="finePointer"
          :signed-in="Boolean(session.token)"
          @set-qty="setQty"
          @remove-one="removeOne"
          @show-legends="showLegends"
          @row-pointerdown="(card, event) => onTilePointerDown(card, 'deck', event)"
          @preview="showPreview"
          @hide-preview="hidePreview"
        />
      </div>

      <div v-show="paneShown('stats')" class="atelier-pane atelier-pane--stats" v-bind="paneAttrs('stats')">
        <DeckStatsPanel :cards="deck.cards" :checks="deck.checks" :prices="deck.prices">
          <template #actions>
            <div class="atelier-actions">
              <RiftButton size="sm" @click="openMissing">Trouver les cartes manquantes</RiftButton>
              <textarea
                v-model="deck.description"
                class="atelier-desc"
                placeholder="Plan de jeu, forces, faiblesses…"
                aria-label="Description du deck"
              ></textarea>
            </div>
          </template>
        </DeckStatsPanel>
      </div>
    </div>

    <!-- Téléphone : la liste (et son message) est dans un autre onglet, le plafond s'affiche en toast. -->
    <p
      class="atelier-toast"
      :class="{ 'atelier-toast--empty': !toastText, 'atelier-toast--raised': saveState }"
      role="status"
    >
      {{ toastText }}
    </p>

    <!-- Fantôme de glisser -->
    <Teleport to="body">
      <div
        v-if="drag.active && drag.card"
        class="atelier-ghost"
        :class="{
          'atelier-ghost--over': drag.overDeck,
          'atelier-ghost--removing': drag.from === 'deck' && !drag.overDeck
        }"
        :style="{ transform: `translate(${drag.x - 55}px, ${drag.y - 78}px) rotate(4deg)` }"
        aria-hidden="true"
      >
        <img class="atelier-ghost-img" :src="cardThumb(drag.card.image_url, 220)" alt="" draggable="false" />
        <span v-if="ghostHint" class="atelier-ghost-hint">{{ ghostHint }}</span>
      </div>
    </Teleport>

    <!-- Aperçu lisible -->
    <Teleport to="body">
      <div
        v-if="preview"
        class="atelier-preview"
        :class="{ 'atelier-preview--large': preview.large }"
        :style="{ left: `${preview.x}px`, top: `${preview.y}px` }"
        aria-hidden="true"
      >
        <div
          class="atelier-preview-art"
          :class="{ 'atelier-preview-art--landscape': preview.card.orientation === 'landscape' }"
        >
          <img class="atelier-preview-img" :src="cardThumb(preview.card.image_url, preview.large ? 720 : 460)" alt="" />
        </div>
        <div v-if="!preview.large" class="atelier-preview-copy">
          <h3 class="atelier-preview-name">{{ preview.card.name }}</h3>
          <p class="atelier-preview-meta">
            {{ TYPES[preview.card.type] || preview.card.type }} ·
            {{ RARITIES[preview.card.rarity] || preview.card.rarity }}
            <template v-if="formatEur(preview.card.price_eur)"> · {{ formatEur(preview.card.price_eur) }}</template>
            <template v-if="session.token"> · possédée ×{{ preview.card.owned_qty ?? 0 }}</template>
            <template v-if="inDeckQty(preview.card)"> · dans le deck ×{{ inDeckQty(preview.card) }}</template>
          </p>
          <RiftText v-if="preview.card.text" tag="p" class="atelier-preview-text" :text="preview.card.text" />
        </div>
      </div>
    </Teleport>

    <!-- Cartes manquantes -->
    <DeckMissingModal
      v-if="showMissing"
      :missing="missing"
      :error="missingError"
      :missing-eur="deck.prices?.missing_eur ?? null"
      :deck-id="deck.id"
      @close="closeMissing"
      @preview="showPreview"
      @hide-preview="hidePreview"
    />

    <RiftModal v-if="showExport" title="Exporter le deck" wide @close="showExport = false">
      <DeckExportBar :deck="deck" />
    </RiftModal>
  </div>

  <div v-else class="atelier-page">
    <p v-if="error" class="atelier-state-error" role="alert">{{ error }}</p>
    <p v-else class="atelier-state-text">Chargement du deck…</p>
  </div>
</template>

<style scoped>
.atelier-page {
  display: grid;
  gap: var(--space-4);
  max-width: min(1680px, 100%);
  margin-inline: auto;
  padding: var(--space-5) var(--space-6) var(--space-7);
}
@media (max-width: 767px) {
  .atelier-page {
    padding-inline: var(--space-4);
  }
}
/* Les onglets restent visibles sous la barre du haut, elle aussi collante. */
.atelier-page > .rift-segments {
  top: var(--topbar-h);
}
.atelier-moderation {
  margin: 0;
  padding: var(--space-2) var(--space-3);
  box-shadow: inset 0 0 0 1px var(--blood);
  font-size: 14px;
  color: var(--blood-text);
}

/* Trois zones. Bureau large : galerie | liste | analyse. */
.atelier {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 340px 300px;
  grid-template-areas: "cards deck stats";
  align-items: start;
  gap: var(--space-5);
}
.atelier-pane {
  min-width: 0;
}
.atelier-pane--cards {
  grid-area: cards;
}
.atelier-pane--deck {
  grid-area: deck;
}
.atelier-pane--stats {
  grid-area: stats;
}
/* Liste et analyse collantes, avec un défilement interne borné à la fenêtre. La barre
   du haut de la coquille est elle-même collante : on se cale sous elle. */
.atelier-pane--deck,
.atelier-pane--stats {
  position: sticky;
  top: calc(var(--topbar-h) + var(--space-4));
  max-height: calc(100dvh - var(--topbar-h) - 2 * var(--space-4));
}
.atelier-pane--deck {
  display: flex;
  flex-direction: column;
}
.atelier-pane--deck > .decklist {
  flex: 1 1 auto;
  min-height: 0;
}
.atelier-pane--stats {
  overflow-y: auto;
}

.atelier-actions {
  display: grid;
  gap: var(--space-3);
  margin-top: var(--space-4);
}
/* Textarea neutralisé localement : main.css stylise `textarea` globalement. */
.atelier-desc {
  width: 100%;
  min-height: 96px;
  margin: 0;
  padding: var(--space-3);
  border: none;
  border-radius: 0;
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  font-family: inherit;
  font-size: 14px;
  line-height: 1.5;
  resize: vertical;
  outline: none;
  transition: box-shadow var(--t-fast);
}
.atelier-desc:focus {
  box-shadow: inset 0 0 0 1px var(--bronze-light);
}

/* Tablette et petit bureau : l'analyse passe sous la liste, dans la colonne de droite. */
@media (max-width: 1279px) {
  .atelier {
    grid-template-columns: minmax(0, 1fr) 340px;
    grid-template-areas:
      "cards deck"
      "cards stats";
  }
  .atelier-pane--deck,
  .atelier-pane--stats {
    position: static;
    max-height: none;
  }
  .atelier-pane--stats {
    overflow: visible;
  }
}

/* Téléphone : une zone à la fois (onglets). */
@media (max-width: 767px) {
  .atelier {
    grid-template-columns: minmax(0, 1fr);
    grid-template-areas: none;
  }
  .atelier-pane--cards,
  .atelier-pane--deck,
  .atelier-pane--stats {
    grid-area: auto;
  }
}

/* Message de plafond hors de l'onglet Deck : toast au-dessus des onglets du bas. */
.atelier-toast {
  position: fixed;
  left: var(--space-3);
  right: var(--space-3);
  bottom: calc(var(--shell-bottom, env(safe-area-inset-bottom, 0px)) + var(--space-3));
  z-index: calc(var(--z-overlay) - 1);
  margin: 0;
  padding: var(--space-3) var(--space-4);
  background: var(--bg-raised);
  box-shadow:
    inset 0 0 0 1px var(--blood),
    var(--shadow-deep);
  font-size: 14px;
  text-align: center;
  color: var(--blood-text);
}
/* Vide : la région live reste montée (annonce fiable) mais disparaît à l'écran. */
.atelier-toast--empty {
  position: absolute;
  width: 1px;
  height: 1px;
  min-height: 0;
  margin: -1px;
  padding: 0;
  overflow: hidden;
  clip-path: inset(50%);
  box-shadow: none;
  white-space: nowrap;
}
/* Mention d'enregistrement visible au même endroit : le toast de plafond monte d'un cran. */
.atelier-toast--raised {
  bottom: calc(var(--shell-bottom, env(safe-area-inset-bottom, 0px)) + var(--space-3) + 64px);
}

/* Fantôme suivi du curseur pendant le glisser (téléporté dans le body). */
.atelier-ghost {
  position: fixed;
  left: 0;
  top: 0;
  z-index: calc(var(--z-overlay) + 2);
  width: 110px;
  pointer-events: none;
  filter: drop-shadow(0 18px 30px rgba(0, 0, 0, 0.6));
  transition: width var(--t-fast);
}
.atelier-ghost-img {
  display: block;
  width: 100%;
  border-radius: var(--radius-card);
}
.atelier-ghost--over {
  width: 126px;
}
.atelier-ghost--over .atelier-ghost-img {
  outline: 3px solid var(--bronze-light);
  outline-offset: -1px;
}
.atelier-ghost--removing .atelier-ghost-img {
  outline: 3px solid var(--blood);
  outline-offset: -1px;
  opacity: 0.8;
}
.atelier-ghost-hint {
  position: absolute;
  left: 50%;
  bottom: -28px;
  transform: translateX(-50%);
  white-space: nowrap;
  padding: 3px 10px;
  background: rgba(13, 13, 15, 0.94);
  box-shadow: inset 0 0 0 1px var(--bronze);
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

/* Aperçu lisible au survol (téléporté dans le body, au-dessus de la modale des manquantes). */
.atelier-preview {
  position: fixed;
  z-index: calc(var(--z-overlay) + 1);
  width: 320px;
  padding: var(--space-3);
  background: var(--bg-raised);
  box-shadow:
    inset 0 0 0 1px var(--bronze),
    var(--shadow-deep);
  pointer-events: none;
  animation: atelier-preview-in 180ms ease-out;
}
@keyframes atelier-preview-in {
  from {
    opacity: 0;
    transform: scale(0.96);
  }
}
.atelier-preview--large {
  width: 400px;
  padding: var(--space-2);
}
.atelier-preview-art {
  margin: 0;
}
.atelier-preview-img {
  display: block;
  width: 100%;
  aspect-ratio: 744 / 1039;
  object-fit: contain;
  border-radius: var(--radius-card);
}
.atelier-preview-art--landscape .atelier-preview-img {
  aspect-ratio: 1038 / 744;
}
.atelier-preview-copy {
  margin-top: var(--space-3);
}
/* h3 neutralisé localement : marges, taille et couleur explicites. */
.atelier-preview-name {
  margin: 0 0 2px;
  font-family: var(--font-display);
  font-size: 16px;
  font-weight: 700;
  line-height: 1.25;
  color: var(--ink);
}
.atelier-preview-meta {
  margin: 0;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.04em;
  color: var(--ink-muted);
}
.atelier-preview-text {
  margin: var(--space-2) 0 0;
  font-size: 13px;
  line-height: 1.45;
  color: var(--ink);
}
@media (hover: none) {
  .atelier-preview {
    display: none;
  }
}

.atelier-state-error {
  margin: 0;
  color: var(--blood-text);
}
.atelier-state-text {
  margin: 0;
  color: var(--ink-muted);
}

@media (prefers-reduced-motion: reduce) {
  .atelier-desc,
  .atelier-ghost {
    transition: none;
  }
  .atelier-preview {
    animation: none;
  }
}
</style>
