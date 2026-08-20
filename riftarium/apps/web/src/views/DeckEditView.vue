<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, cardThumb, DOMAINS, TYPES, RARITIES, session } from "../api.js"
import {
  DOMAIN_RUNE,
  RUNE_LABELS,
  cardsQuery,
  domainFilterOptions,
  energyFilterOptions,
  glyphUrl,
  rarityFilterOptions,
  typeFilterOptions
} from "../cardText.js"
import CardText from "../components/CardText.vue"
import DeckExportBar from "../components/DeckExportBar.vue"
import DeckMissingModal from "../components/DeckMissingModal.vue"
import DeckView from "../components/DeckView.vue"
import FilterSelect from "../components/FilterSelect.vue"
import ModalDialog from "../components/ModalDialog.vue"
import { useDeckAutosave } from "../composables/useDeckAutosave.js"
import { useDeckRules } from "../composables/useDeckRules.js"
import { useDeckStats } from "../composables/useDeckStats.js"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { formatLabel } from "../deckDisplay.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import { applySeo } from "../seo.js"

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

const { saveState, sessionExpired, save, markSaved } = useDeckAutosave(deck, persistDeck, {
  snapshot,
  canEdit: () => canEdit.value,
  error
})

/* Session expirée pendant l'édition : on garde le brouillon affiché et modifiable localement. */
const canEdit = computed(() =>
  Boolean(deck.value && (sessionExpired.value || (session.handle && session.handle === deck.value.owner)))
)

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

const { curve, energyTotal, domainSpread } = useDeckStats(() => deck.value?.cards || [])

const missingInDeck = computed(() =>
  (deck.value?.cards || []).reduce((total, entry) => total + Math.max(0, entry.qty - (entry.card.owned_qty ?? 0)), 0)
)

/* Valeur indicative du deck (deck_out.prices, null si rien de pricé). */
const deckValue = computed(() => formatEur(deck.value?.prices?.total_eur))

/* ---------- Galerie filtrable ---------- */

const grid = ref(null)
const { tileMin, size, measure, observe } = useGridMeasure(grid, {
  tileMin: 150,
  size: 24,
  maxSize: 60,
  tileFloor: 112,
  debounce: 160,
  gap: () => 14,
  minCol: () => 132,
  rows: (height) => (height >= 1000 ? 5 : 4),
  fallbackWidth: () => 720
})

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
const domainOptions = computed(() => domainFilterOptions())
const typeOptions = computed(() => typeFilterOptions())
const rarityOptions = computed(() => rarityFilterOptions())
const energyOptions = computed(() => energyFilterOptions())
const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))

watch(size, scheduleGallery)

/* La légende vient d'être choisie : on rouvre la galerie sur toutes les cartes. */
watch(legendEntry, (next, previous) => {
  if (next && !previous && gallery.type.length === 1 && gallery.type[0] === "Legend") {
    gallery.type = []
    gallery.page = 1
  }
})

const isOwned = (card) => !session.token || (card.owned_qty ?? 0) > 0

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

/* ---------- Drag & drop façon table de jeu ---------- */

const drag = reactive({ active: false, card: null, from: "", x: 0, y: 0, overDeck: false })
const deckPanel = ref(null)
let dragStart = null
let dragMoved = false
let suppressClick = false

async function toggleLike() {
  if (!deck.value) return
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: `/decks/${deck.value.id}` } })
    return
  }
  try {
    const payload = await api(`/api/decks/${deck.value.id}/like`, { method: "POST" })
    deck.value.likes = payload.likes
    deck.value.liked_by_me = payload.liked_by_me
  } catch (e) {
    error.value = e.message
  }
}

function onTilePointerDown(card, from, event) {
  if (!canEdit.value || !finePointer || event.pointerType === "touch" || event.button !== 0) return
  if (event.target.closest(".row-actions")) return
  dragStart = { card, from, x: event.clientX, y: event.clientY }
  dragMoved = false
  window.addEventListener("pointermove", onDragMove)
  window.addEventListener("pointerup", onDragEnd, { once: true })
}

function onDragMove(event) {
  if (!dragStart) return
  if (!drag.active) {
    if (Math.hypot(event.clientX - dragStart.x, event.clientY - dragStart.y) < 8) return
    drag.active = true
    drag.card = dragStart.card
    drag.from = dragStart.from
    hidePreview()
    document.body.classList.add("drag-active")
  }
  dragMoved = true
  drag.x = event.clientX
  drag.y = event.clientY
  const rect = deckPanel.value?.getBoundingClientRect()
  drag.overDeck = Boolean(
    rect &&
    event.clientX >= rect.left &&
    event.clientX <= rect.right &&
    event.clientY >= rect.top &&
    event.clientY <= rect.bottom
  )
}

async function onDragEnd() {
  window.removeEventListener("pointermove", onDragMove)
  const wasActive = drag.active
  const { card, from, overDeck } = { card: drag.card, from: drag.from, overDeck: drag.overDeck }
  dragStart = null
  document.body.classList.remove("drag-active")
  if (!wasActive) return
  suppressClick = dragMoved
  setTimeout(() => (suppressClick = false), 0)
  if (from === "gallery" && overDeck) {
    if (addCard(card)) await flyGhostToRow(card)
  } else if (from === "deck" && !overDeck) {
    removeOne(card.id)
  }
  drag.active = false
  drag.card = null
  drag.overDeck = false
}

/* Le fantôme glisse jusqu'à sa ligne dans le deck (animation FLIP légère). */
async function flyGhostToRow(card) {
  if (reducedMotion) return
  await nextTick()
  const ghost = document.querySelector(".drag-ghost")
  const row = deckPanel.value?.querySelector(`[data-row="${CSS.escape(card.id)}"]`)
  if (!ghost || !row) return
  const target = row.getBoundingClientRect()
  const animation = ghost.animate(
    [
      { transform: `translate(${drag.x - 55}px, ${drag.y - 78}px) rotate(4deg)`, opacity: 1 },
      { transform: `translate(${target.left + 20}px, ${target.top - 10}px) rotate(0deg) scale(0.32)`, opacity: 0.2 }
    ],
    { duration: 260, easing: "cubic-bezier(0.22, 0.8, 0.32, 1)" }
  )
  await animation.finished.catch(() => {})
}

function onTileClick(card) {
  if (suppressClick) return
  addCard(card)
}

/* Tactile : pas de survol pour lire une carte, un petit bouton ouvre sa fiche. */
function openCardPage(card) {
  router.push(`/cartes/${card.id}`)
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

async function load() {
  try {
    deck.value = await api(`/api/decks/${route.params.id}`)
    sessionExpired.value = false
    markSaved()
    if (canEdit.value && !deck.value.cards.some((entry) => entry.card.type === "Legend")) gallery.type = ["Legend"]
    if (!canEdit.value && deck.value.is_public && deck.value.moderation_status === "published") {
      try {
        const seen = await api(`/api/decks/${deck.value.id}/view`, { method: "POST" })
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
      noindex: !publicDeck
    })
  } catch (e) {
    error.value = e.message
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
  window.removeEventListener("pointermove", onDragMove)
})
</script>

<template>
  <p v-if="error && !deck" class="error wrap" style="padding-top: 40px">{{ error }}</p>
  <DeckView v-if="deck && !canEdit" :deck="deck" @like="toggleLike" />
  <section class="dbuilder-page" v-else-if="deck">
    <div class="dbuilder-bar">
      <RouterLink :to="canEdit ? '/decks' : '/communaute'" class="dbuilder-back">
        {{ canEdit ? "← Mes decks" : "← Communauté" }}
      </RouterLink>
      <input
        v-if="canEdit"
        type="text"
        v-model="deck.name"
        class="dbuilder-name"
        maxlength="80"
        aria-label="Nom du deck"
      />
      <h2 v-else class="dbuilder-name">{{ deck.name }}</h2>
      <select v-if="canEdit" v-model="deck.format" aria-label="Format">
        <option value="tournament">Mode tournoi — règles officielles</option>
        <option value="free">Mode libre — format non officiel</option>
      </select>
      <span v-else class="muted mono"> {{ formatLabel(deck.format) }} · par {{ deck.owner }} </span>
      <label v-if="canEdit" class="switch"> <input type="checkbox" v-model="deck.is_public" /><i></i> Public </label>
      <div class="deck-box-stats">
        <button
          v-if="deck.is_public && deck.moderation_status === 'published'"
          type="button"
          class="deck-box-stat"
          :class="{ liked: deck.liked_by_me }"
          :aria-pressed="deck.liked_by_me"
          :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
          @click="toggleLike"
        >
          <Icon name="heart" :size="14" />
          {{ deck.likes }}
        </button>
        <span class="deck-box-stat" :title="`${deck.views ?? 0} vue(s)`">
          <Icon name="eye" :size="14" />
          {{ deck.views ?? 0 }}
        </span>
      </div>
      <button type="button" class="btn btn-ghost btn-sm" @click="showExport = true">Exporter</button>
      <span v-if="canEdit" class="dbuilder-save" :class="saveState">
        <template v-if="saveState === 'saving'">Enregistrement…</template>
        <template v-else-if="saveState === 'saved'">Enregistré ✓</template>
        <template v-else-if="saveState === 'error'">Erreur de sauvegarde</template>
      </span>
      <span v-if="error" class="error">{{ error }}</span>
    </div>
    <p v-if="deck.moderation_status === 'pending'" class="error dbuilder-moderation">
      En attente de modération : ce deck n'est pas visible publiquement.
    </p>

    <div class="dbuilder" :class="{ readonly: !canEdit }">
      <!-- Galerie : toutes les cartes du jeu, façon collection de jeu de cartes -->
      <div v-if="canEdit" class="dbuilder-gallery">
        <div class="filter-board">
          <label class="search filter-search">
            <Icon name="search" :size="18" />
            <input
              type="search"
              v-model="gallery.q"
              placeholder="Jinx, ogn-202, reaction…"
              aria-label="Rechercher une carte"
            />
          </label>
          <FilterSelect
            label="Domaines"
            :options="domainOptions"
            :model-value="gallery.domain"
            @update:model-value="setFilter('domain', $event)"
          />
          <FilterSelect
            label="Types"
            :options="typeOptions"
            :model-value="gallery.type"
            @update:model-value="setFilter('type', $event)"
          />
          <FilterSelect
            label="Raretés"
            :options="rarityOptions"
            :model-value="gallery.rarity"
            @update:model-value="setFilter('rarity', $event)"
          />
          <FilterSelect
            label="Coût"
            :options="energyOptions"
            :model-value="gallery.energy"
            @update:model-value="setFilter('energy', $event)"
          />
          <FilterSelect
            v-if="setOptions.length"
            label="Sets"
            :options="setOptions"
            :model-value="gallery.set_id"
            @update:model-value="setFilter('set_id', $event)"
          />
          <div class="owned-seg" role="group" aria-label="Filtrer par possession" v-if="session.token">
            <button type="button" :class="{ on: gallery.owned === '' }" @click="setFilter('owned', '')">Toutes</button>
            <button type="button" :class="{ on: gallery.owned === '1' }" @click="setFilter('owned', '1')">
              Possédées
            </button>
            <button type="button" :class="{ on: gallery.owned === '0' }" @click="setFilter('owned', '0')">
              Manquantes
            </button>
          </div>
          <button v-if="activeCount" class="btn btn-ghost btn-sm" @click="resetFilters">
            Réinitialiser ({{ activeCount }})
          </button>
        </div>

        <p class="muted mono dbuilder-count">
          {{ result.total }} carte(s) <span v-if="loading">— chargement…</span>
          <span class="dbuilder-hint">{{
            finePointer ? "— cliquez ou glissez une carte vers le deck" : "— touchez une carte pour l'ajouter au deck"
          }}</span>
        </p>

        <div ref="grid" class="dbuilder-grid" :style="{ '--tile-min': `${tileMin}px` }">
          <button
            v-for="card in result.items"
            :key="card.id"
            type="button"
            class="gcard"
            :class="{
              unowned: !isOwned(card),
              indeck: inDeckQty(card) > 0,
              offdomain: deck.format === 'tournament' && offDomain(card),
              landscape: card.orientation === 'landscape',
              shake: shakes.has(card.id)
            }"
            :aria-label="`Ajouter ${card.name} au deck`"
            @click="onTileClick(card)"
            @pointerdown="onTilePointerDown(card, 'gallery', $event)"
            @mouseenter="showPreview(card, $event)"
            @mouseleave="hidePreview"
            @focusin="showPreview(card, $event)"
            @focusout="hidePreview"
          >
            <img :src="cardThumb(card.image_url, 320)" :alt="''" loading="lazy" decoding="async" draggable="false" />
            <span v-if="session.token" class="gcard-owned" :class="{ zero: !(card.owned_qty > 0) }">
              {{ card.owned_qty > 0 ? `×${card.owned_qty}` : "non possédée" }}
            </span>
            <span v-if="inDeckQty(card)" class="gcard-indeck">{{ inDeckQty(card) }}</span>
            <span v-if="formatEur(card.price_eur)" class="gcard-price">{{ formatEur(card.price_eur) }}</span>
            <span class="gcard-add" aria-hidden="true">+</span>
            <!-- Visible uniquement au tactile (CSS hover:none) : ouvre la fiche sans ajouter la carte -->
            <span
              class="gcard-info"
              role="link"
              :aria-label="`Voir la fiche de ${card.name}`"
              @click.stop="openCardPage(card)"
              @pointerdown.stop
              >ℹ</span
            >
          </button>
        </div>
        <p v-if="!loading && !result.items.length" class="muted" style="margin-top: 14px">
          Aucune carte ne correspond aux filtres.
        </p>

        <div class="pager" v-if="pageCount > 1">
          <button class="btn btn-ghost btn-sm" :disabled="gallery.page <= 1" @click="gallery.page--">
            ← Précédent
          </button>
          <span>page {{ gallery.page }} / {{ pageCount }}</span>
          <button class="btn btn-ghost btn-sm" :disabled="gallery.page >= pageCount" @click="gallery.page++">
            Suivant →
          </button>
        </div>
      </div>

      <!-- Le deck : liste compacte façon Hearthstone, zone de dépôt -->
      <aside
        ref="deckPanel"
        class="dbuilder-deck"
        :class="{ 'drop-hot': drag.active && drag.from === 'gallery' && drag.overDeck }"
      >
        <div
          v-if="drag.active && drag.from === 'gallery'"
          class="drop-hint"
          :class="{ hot: drag.overDeck }"
          aria-hidden="true"
        >
          <span>{{ drag.overDeck ? "Déposez pour ajouter au deck" : "Glissez-déposez ici" }}</span>
        </div>

        <!-- Boîte de deck : la légende en vitrine avec ses deux runes -->
        <div
          v-if="legendEntry"
          class="deck-hero"
          :style="{ '--hero-art': `url(${cardThumb(legendEntry.card.image_url, 480)})` }"
          @mouseenter="showPreview(legendEntry.card, $event)"
          @mouseleave="hidePreview"
        >
          <div class="deck-hero-copy">
            <p class="eyebrow">Légende</p>
            <h3>{{ legendEntry.card.name }}</h3>
            <div class="deck-hero-runes">
              <img
                v-for="rune in legendRunes"
                :key="rune.domain"
                :src="rune.src"
                :alt="rune.label"
                :title="rune.label"
                width="26"
                height="26"
              />
            </div>
          </div>
          <button
            v-if="canEdit"
            type="button"
            class="deck-hero-remove"
            aria-label="Retirer la légende du deck"
            @click="removeOne(legendEntry.card.id)"
          >
            ✕
          </button>
        </div>
        <div v-else class="deck-hero empty">
          <p v-if="canEdit"><b>1.</b> Choisissez votre légende : elle fixe les deux domaines du deck.</p>
          <p v-else>Ce deck n'a pas encore de légende.</p>
          <button v-if="canEdit" type="button" class="btn btn-ghost btn-sm" @click="setFilter('type', ['Legend'])">
            Voir les légendes
          </button>
        </div>

        <div class="deck-meters">
          <div
            class="meter"
            v-for="zone in ZONES"
            :key="zone.key"
            :class="{ full: zoneCounts[zone.key] >= zone.target }"
          >
            <b
              >{{ zoneCounts[zone.key] }}<small>/{{ zone.target }}{{ zone.key === "main" ? "+" : "" }}</small></b
            >
            <span>{{ zone.label }}</span>
          </div>
        </div>
        <p v-if="limitMessage" class="deck-limit" role="status">{{ limitMessage }}</p>
        <p v-else-if="missingInDeck" class="deck-limit soft" role="status">
          {{ missingInDeck }} carte(s) du deck manquent à votre collection.
        </p>

        <div class="deck-scroll">
          <template v-for="zone in LIST_ZONES" :key="zone.key">
            <p class="zone-title">
              {{ zone.label }} <small>{{ zoneCounts[zone.key] }}</small>
            </p>
            <TransitionGroup name="deck-row" tag="div" class="deck-rows">
              <div
                v-for="entry in grouped[zone.key]"
                :key="entry.card.id"
                class="deck-row"
                :class="{
                  flash: flashes.has(entry.card.id),
                  lacking: session.token && (entry.card.owned_qty ?? 0) < entry.qty
                }"
                :data-row="entry.card.id"
                :style="{ '--row-art': `url(${cardThumb(entry.card.image_url, 200)})` }"
                @pointerdown="onTilePointerDown(entry.card, 'deck', $event)"
                @mouseenter="showPreview(entry.card, $event)"
                @mouseleave="hidePreview"
              >
                <span class="row-cost" v-if="entry.card.energy != null">{{ entry.card.energy }}</span>
                <span class="row-cost none" v-else></span>
                <span class="row-name">{{ entry.card.name }}</span>
                <span
                  v-if="session.token && (entry.card.owned_qty ?? 0) < entry.qty"
                  class="row-lack"
                  :title="`${entry.qty - (entry.card.owned_qty ?? 0)} exemplaire(s) manquant(s) dans votre collection`"
                  >!</span
                >
                <span class="row-qty">×{{ entry.qty }}</span>
                <span class="row-actions" v-if="canEdit">
                  <button
                    type="button"
                    :aria-label="`Retirer un exemplaire de ${entry.card.name}`"
                    @click.stop="setQty(entry, -1)"
                  >
                    −
                  </button>
                  <button
                    type="button"
                    :aria-label="`Ajouter un exemplaire de ${entry.card.name}`"
                    @click.stop="setQty(entry, 1)"
                  >
                    +
                  </button>
                </span>
              </div>
            </TransitionGroup>
            <p v-if="!grouped[zone.key].length" class="zone-empty">
              <!-- Au tactile le glisser-déposer est désactivé : c'est le tap qui ajoute. -->
              {{
                !canEdit
                  ? "Aucune carte dans cette zone."
                  : finePointer
                    ? "Glissez des cartes ici."
                    : "Touchez une carte de la galerie pour l'ajouter."
              }}
            </p>
          </template>
        </div>
      </aside>
    </div>

    <div class="dbuilder-overview">
      <div class="overview-row">
        <ul class="validator">
          <li v-for="checkItem in deck.checks" :key="checkItem.rule" :class="checkItem.ok ? 'v-ok' : 'v-ko'">
            {{ checkItem.message }}
          </li>
        </ul>
        <button v-if="canEdit" class="btn btn-gold btn-sm missing-btn" @click="openMissing">
          Trouver les cartes manquantes
        </button>
      </div>
      <div class="overview-row overview-cost">
        <p class="overview-energy">
          <b>{{ energyTotal }}</b> énergie
        </p>
        <p v-if="deckValue" class="price-deck" :title="PRICE_NOTE">
          Valeur du deck : <b class="price-amount">{{ deckValue }}</b>
        </p>
        <div class="curve" role="img" aria-label="Répartition des coûts en énergie du deck principal">
          <div class="bar" v-for="bucket in curve" :key="bucket.cost">
            <i :style="{ height: bucket.height + '%' }" :title="`${bucket.count} carte(s) à ${bucket.cost}`"></i>
            <small>{{ bucket.cost }}{{ bucket.cost === 7 ? "+" : "" }}</small>
          </div>
        </div>
        <div class="deck-domains" v-if="domainSpread.length">
          <span class="chip chip-rune" v-for="[domain, count] in domainSpread" :key="domain">
            <img
              class="rb-glyph rune"
              :src="glyphUrl(`rune_${DOMAIN_RUNE[domain] || 'rainbow'}`)"
              :alt="RUNE_LABELS[DOMAIN_RUNE[domain]] || domain"
              width="18"
              height="18"
            />
            {{ DOMAINS[domain]?.label || domain }} · {{ count }}
          </span>
        </div>
      </div>
      <textarea
        v-if="canEdit"
        v-model="deck.description"
        placeholder="Plan de jeu, forces, faiblesses…"
        aria-label="Description du deck"
      ></textarea>
      <p v-else-if="deck.description" class="deck-read-desc">{{ deck.description }}</p>
    </div>

    <!-- Fantôme de drag -->
    <Teleport to="body">
      <div
        v-if="drag.active && drag.card"
        class="drag-ghost"
        :class="{ 'over-deck': drag.overDeck, removing: drag.from === 'deck' && !drag.overDeck }"
        :style="{ transform: `translate(${drag.x - 55}px, ${drag.y - 78}px) rotate(4deg)` }"
        aria-hidden="true"
      >
        <img :src="cardThumb(drag.card.image_url, 220)" alt="" draggable="false" />
        <span v-if="drag.from === 'deck'" class="ghost-hint">{{ drag.overDeck ? "" : "Relâchez pour retirer" }}</span>
        <span v-else class="ghost-hint">{{ drag.overDeck ? "Ajouter au deck" : "" }}</span>
      </div>
    </Teleport>

    <!-- Aperçu lisible -->
    <Teleport to="body">
      <div
        v-if="preview"
        class="builder-preview"
        :class="{ large: preview.large }"
        :style="{ left: `${preview.x}px`, top: `${preview.y}px` }"
        aria-hidden="true"
      >
        <div class="card-art" :class="{ landscape: preview.card.orientation === 'landscape' }">
          <img :src="cardThumb(preview.card.image_url, preview.large ? 720 : 460)" alt="" />
        </div>
        <div class="builder-preview-copy" v-if="!preview.large">
          <h3>{{ preview.card.name }}</h3>
          <p class="muted mono" style="font-size: 0.7rem">
            {{ TYPES[preview.card.type] || preview.card.type }} ·
            {{ RARITIES[preview.card.rarity] || preview.card.rarity }}
            <template v-if="formatEur(preview.card.price_eur)"> · {{ formatEur(preview.card.price_eur) }}</template>
            <template v-if="session.token"> · possédée ×{{ preview.card.owned_qty ?? 0 }}</template>
            <template v-if="inDeckQty(preview.card)"> · dans le deck ×{{ inDeckQty(preview.card) }}</template>
          </p>
          <CardText v-if="preview.card.text" :text="preview.card.text" />
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

    <ModalDialog v-if="showExport" title="Exporter le deck" wide @close="showExport = false">
      <DeckExportBar :deck="deck" />
    </ModalDialog>
  </section>

  <section v-else>
    <div class="wrap" style="padding-top: 44px">
      <p v-if="error" class="error">{{ error }}</p>
      <p v-else class="muted">Chargement du deck…</p>
    </div>
  </section>
</template>
