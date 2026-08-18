<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { useRoute } from "vue-router"
import { api, cardThumb, DOMAINS, TYPES, RARITIES, session } from "../api.js"
import { DOMAIN_RUNE, RUNE_LABELS, cardsQuery, glyphUrl, variantFamily } from "../cardText.js"
import CardText from "../components/CardText.vue"
import FilterSelect from "../components/FilterSelect.vue"
import ModalDialog from "../components/ModalDialog.vue"

const route = useRoute()
const deck = ref(null)
const error = ref("")
const saveState = ref("") // "" | "saving" | "saved" | "error"
const limitMessage = ref("")

const finePointer = typeof window !== "undefined" && window.matchMedia("(hover: hover) and (pointer: fine)").matches
const reducedMotion = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches

/* ---------- Zones du deck ---------- */

const ZONES = [
  { key: "Legend", label: "Légende", target: 1 },
  { key: "Battlefield", label: "Champs de bataille", target: 3 },
  { key: "Rune", label: "Runes", target: 12 },
  { key: "main", label: "Deck principal", target: 40 }
]

/* La légende est affichée en vitrine : les listes ne montrent que les autres zones. */
const LIST_ZONES = ZONES.filter((zone) => zone.key !== "Legend")

/* Plafond d'exemplaires par carte, appliqué en mode tournoi (12 = limite du schéma en mode libre). */
const TOURNAMENT_CAPS = { Legend: 1, Battlefield: 1, Rune: 12, main: 3 }

const zoneOf = (card) => (card.type in TOURNAMENT_CAPS ? card.type : "main")

const grouped = computed(() => {
  const groups = { Legend: [], Battlefield: [], Rune: [], main: [] }
  for (const entry of deck.value?.cards || []) groups[zoneOf(entry.card)].push(entry)
  for (const zone of Object.values(groups)) {
    zone.sort((a, b) => (a.card.energy ?? -1) - (b.card.energy ?? -1) || a.card.name.localeCompare(b.card.name))
  }
  return groups
})

const zoneCounts = computed(() => {
  const counts = {}
  for (const zone of ZONES) counts[zone.key] = grouped.value[zone.key].reduce((total, entry) => total + entry.qty, 0)
  return counts
})

/* Quantités par famille de variantes : l'art alternatif compte comme la carte de base. */
const familyQty = computed(() => {
  const map = new Map()
  for (const entry of deck.value?.cards || []) {
    const family = variantFamily(entry.card.riftbound_id) || entry.card.id
    map.set(family, (map.get(family) || 0) + entry.qty)
  }
  return map
})

const inDeckQty = (card) => familyQty.value.get(variantFamily(card.riftbound_id) || card.id) || 0

/* ---------- Légende d'abord : elle fixe l'identité de domaines du deck ---------- */

const legendEntry = computed(() => grouped.value.Legend[0] || null)
const legendDomains = computed(
  () => new Set((legendEntry.value?.card.domains || []).filter((domain) => domain !== "Colorless"))
)
const legendRunes = computed(() =>
  [...legendDomains.value].map((domain) => ({
    domain,
    label: RUNE_LABELS[DOMAIN_RUNE[domain]] || domain,
    src: glyphUrl(`rune_${DOMAIN_RUNE[domain]}`)
  }))
)

/* Hors identité : ne concerne que le deck principal et les runes (champs de bataille libres). */
function offDomain(card) {
  if (!legendEntry.value || card.type === "Legend" || card.type === "Battlefield") return false
  return (card.domains || []).some((domain) => domain !== "Colorless" && !legendDomains.value.has(domain))
}

const curve = computed(() => {
  const buckets = Array(8).fill(0)
  for (const entry of grouped.value.main) buckets[Math.min(entry.card.energy ?? 0, 7)] += entry.qty
  const max = Math.max(...buckets, 1)
  return buckets.map((count, cost) => ({ cost, count, height: (count / max) * 100 }))
})

const domainSpread = computed(() => {
  const counts = {}
  for (const entry of deck.value?.cards || []) {
    for (const domain of entry.card.domains || []) {
      if (domain === "Colorless") continue
      counts[domain] = (counts[domain] || 0) + entry.qty
    }
  }
  return Object.entries(counts).sort((a, b) => b[1] - a[1])
})

const missingInDeck = computed(() =>
  (deck.value?.cards || []).reduce((total, entry) => total + Math.max(0, entry.qty - (entry.card.owned_qty ?? 0)), 0)
)

/* ---------- Mutations + retour visuel ---------- */

const flashes = reactive(new Set())
const shakes = reactive(new Set())
let limitTimer = null

function pulse(set, key, duration = 600) {
  set.add(key)
  setTimeout(() => set.delete(key), duration)
}

function notify(message) {
  limitMessage.value = message
  clearTimeout(limitTimer)
  limitTimer = setTimeout(() => (limitMessage.value = ""), 2600)
}

function notifyLimit(message, cardId) {
  pulse(shakes, cardId, 500)
  notify(message)
}

function addCard(card) {
  if (!deck.value) return false
  const zone = zoneOf(card)
  if (deck.value.format === "tournament") {
    const cap = TOURNAMENT_CAPS[zone]
    if (zone === "Legend") {
      const current = legendEntry.value
      if (current && current.card.id === card.id) {
        notifyLimit("Cette légende est déjà dans le deck.", card.id)
        return false
      }
      if (current) {
        deck.value.cards.splice(deck.value.cards.indexOf(current), 1)
        notify(`Légende remplacée par ${card.name}.`)
      }
    } else if (!legendEntry.value) {
      notifyLimit("Choisissez d'abord votre légende : elle fixe les domaines du deck.", card.id)
      return false
    }
    if (offDomain(card)) {
      notifyLimit(`${card.name} est hors des domaines de votre légende.`, card.id)
      return false
    }
    if (zone === "Battlefield" && zoneCounts.value.Battlefield >= 3 && inDeckQty(card) === 0) {
      notifyLimit("3 champs de bataille maximum.", card.id)
      return false
    }
    if (zone !== "Legend" && inDeckQty(card) >= cap) {
      notifyLimit(
        zone === "main" ? `Maximum 3 exemplaires de ${card.name}.` : `Maximum ${cap} exemplaire(s) de ${card.name}.`,
        card.id
      )
      return false
    }
  } else if (inDeckQty(card) >= 12) {
    notifyLimit("12 exemplaires maximum.", card.id)
    return false
  }
  const existing = deck.value.cards.find((entry) => entry.card.id === card.id)
  if (existing) existing.qty += 1
  else deck.value.cards.push({ card, qty: 1 })
  pulse(flashes, card.id)
  return true
}

function setQty(entry, delta) {
  if (delta > 0) {
    addCard(entry.card)
    return
  }
  entry.qty += delta
  if (entry.qty <= 0) deck.value.cards.splice(deck.value.cards.indexOf(entry), 1)
}

function removeOne(cardId) {
  const entry = deck.value?.cards.find((item) => item.card.id === cardId)
  if (entry) setQty(entry, -1)
}

/* ---------- Chargement + sauvegarde automatique ---------- */

const snapshot = () =>
  JSON.stringify({
    name: deck.value.name,
    description: deck.value.description,
    format: deck.value.format,
    is_public: deck.value.is_public,
    cards: deck.value.cards.map((entry) => [entry.card.id, entry.qty])
  })

let savedSnapshot = ""
let saveTimer = null

async function load() {
  try {
    deck.value = await api(`/api/decks/${route.params.id}`)
    savedSnapshot = snapshot()
    // Deck sans légende : la galerie démarre sur le choix de la légende.
    if (!deck.value.cards.some((entry) => entry.card.type === "Legend")) gallery.type = ["Legend"]
  } catch (e) {
    error.value = e.message
  }
}

async function save() {
  if (!deck.value || snapshot() === savedSnapshot) return
  saveState.value = "saving"
  const sent = snapshot()
  try {
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
    savedSnapshot = sent
    /* On ne remplace pas l'état local (l'utilisateur tape peut-être) : on rapatrie le calculé. */
    deck.value.checks = fresh.checks
    deck.value.moderation_status = fresh.moderation_status
    deck.value.updated_at = fresh.updated_at
    saveState.value = "saved"
  } catch (e) {
    saveState.value = "error"
    error.value = e.message
  }
}

function scheduleSave() {
  clearTimeout(saveTimer)
  saveTimer = setTimeout(save, 900)
}

watch(
  () => (deck.value ? snapshot() : ""),
  (next, previous) => {
    if (!deck.value || !previous || next === savedSnapshot) return
    error.value = ""
    scheduleSave()
  }
)

/* ---------- Galerie filtrable ---------- */

const ENERGIES = ["0", "1", "2", "3", "4", "5", "6", "7+"]
const gallery = reactive({ q: "", set_id: [], type: [], domain: [], rarity: [], energy: [], owned: "", page: 1 })
const result = ref({ total: 0, items: [] })
const sets = ref([])
const loading = ref(false)
const grid = ref(null)
const tileMin = ref(150)
const size = ref(24)
let galleryTimer = null
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
    (gallery.q ? 1 : 0) +
    gallery.set_id.length +
    gallery.type.length +
    gallery.domain.length +
    gallery.rarity.length +
    gallery.energy.length +
    (gallery.owned ? 1 : 0)
)
const pageCount = computed(() => Math.max(1, Math.ceil(result.value.total / size.value)))

function measure() {
  const width = grid.value?.clientWidth || 720
  const gap = 14
  const columns = Math.max(2, Math.floor((width + gap) / (132 + gap)))
  tileMin.value = Math.max(112, Math.floor((width - gap * (columns - 1)) / columns) - 1)
  const rows = (window.innerHeight || 800) >= 1000 ? 5 : 4
  size.value = Math.min(60, columns * rows)
}

function scheduleMeasure() {
  clearTimeout(resizeTimer)
  resizeTimer = setTimeout(measure, 160)
}

async function loadGallery() {
  loading.value = true
  try {
    result.value = await api(`/api/cards?${cardsQuery(gallery, size.value)}`)
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

function scheduleGallery() {
  clearTimeout(galleryTimer)
  galleryTimer = setTimeout(loadGallery, 180)
}

function setFilter(key, values) {
  gallery[key] = values
  gallery.page = 1
}

function resetFilters() {
  Object.assign(gallery, { q: "", set_id: [], type: [], domain: [], rarity: [], energy: [], owned: "", page: 1 })
}

watch(
  () => [
    gallery.q,
    gallery.set_id.join(),
    gallery.type.join(),
    gallery.domain.join(),
    gallery.rarity.join(),
    gallery.energy.join(),
    gallery.owned,
    gallery.page
  ],
  scheduleGallery
)
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

const preview = ref(null) // { card, x, y }

function showPreview(card, event) {
  if (!finePointer || drag.active) return
  const rect = event.currentTarget.getBoundingClientRect()
  const width = 320
  const rightSpace = window.innerWidth - rect.right
  const x = rightSpace > width + 28 ? rect.right + 14 : Math.max(10, rect.left - width - 14)
  const y = Math.min(Math.max(12, rect.top - 40), Math.max(12, window.innerHeight - 480))
  preview.value = { card, x, y }
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

function onTilePointerDown(card, from, event) {
  if (!finePointer || event.pointerType === "touch" || event.button !== 0) return
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

/* ---------- Cartes manquantes ---------- */

const showMissing = ref(false)
const missing = ref(null)
const missingError = ref("")
const copyLabel = ref("Copier la liste")

async function openMissing() {
  showMissing.value = true
  missing.value = null
  missingError.value = ""
  copyLabel.value = "Copier la liste"
  await save()
  try {
    missing.value = await api(`/api/decks/${deck.value.id}/missing`)
  } catch (e) {
    missingError.value = e.message
  }
}

async function copyMissing() {
  if (!missing.value?.items.length) return
  const lines = missing.value.items.map(
    (item) => `${item.missing}× ${item.card.name} (${item.card.riftbound_id.toUpperCase()})`
  )
  try {
    await navigator.clipboard.writeText(lines.join("\n"))
    copyLabel.value = "Copié ✓"
  } catch {
    copyLabel.value = "Copie impossible"
  }
}

/* ---------- Cycle de vie ---------- */

watch(
  () => route.params.id,
  async () => {
    deck.value = null
    await load()
  },
  { immediate: true }
)

onMounted(async () => {
  measure()
  loadGallery()
  window.addEventListener("resize", scheduleMeasure)
  window.addEventListener("scroll", hidePreview, { passive: true })
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
  clearTimeout(saveTimer)
  clearTimeout(galleryTimer)
  clearTimeout(resizeTimer)
  clearTimeout(limitTimer)
  window.removeEventListener("resize", scheduleMeasure)
  window.removeEventListener("scroll", hidePreview)
  window.removeEventListener("pointermove", onDragMove)
  observer?.disconnect()
  save()
})
</script>

<template>
  <section class="dbuilder-page" v-if="deck">
    <div class="dbuilder-bar">
      <RouterLink to="/decks" class="dbuilder-back">← Mes decks</RouterLink>
      <input type="text" v-model="deck.name" class="dbuilder-name" maxlength="80" aria-label="Nom du deck" />
      <select v-model="deck.format" aria-label="Format">
        <option value="tournament">Mode tournoi</option>
        <option value="free">Mode libre</option>
      </select>
      <label class="switch"> <input type="checkbox" v-model="deck.is_public" /><i></i> Public </label>
      <span class="dbuilder-save" :class="saveState">
        <template v-if="saveState === 'saving'">Enregistrement…</template>
        <template v-else-if="saveState === 'saved'">Enregistré ✓</template>
        <template v-else-if="saveState === 'error'">Erreur de sauvegarde</template>
      </span>
      <span v-if="error" class="error">{{ error }}</span>
    </div>
    <p v-if="deck.moderation_status === 'pending'" class="error dbuilder-moderation">
      En attente de modération : ce deck n'est pas visible publiquement.
    </p>

    <div class="dbuilder">
      <!-- Galerie : toutes les cartes du jeu, façon collection de jeu de cartes -->
      <div class="dbuilder-gallery">
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
          <span class="dbuilder-hint">— cliquez ou glissez une carte vers le deck</span>
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
            <span class="gcard-add" aria-hidden="true">+</span>
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
            type="button"
            class="deck-hero-remove"
            aria-label="Retirer la légende du deck"
            @click="removeOne(legendEntry.card.id)"
          >
            ✕
          </button>
        </div>
        <div v-else class="deck-hero empty">
          <p><b>1.</b> Choisissez votre légende : elle fixe les deux domaines du deck.</p>
          <button type="button" class="btn btn-ghost btn-sm" @click="setFilter('type', ['Legend'])">
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
                <span class="row-actions">
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
            <p v-if="!grouped[zone.key].length" class="zone-empty">Glissez des cartes ici.</p>
          </template>

          <div class="deck-extra">
            <h4>Courbe d'énergie</h4>
            <div class="curve" role="img" aria-label="Répartition des coûts en énergie du deck principal">
              <div class="bar" v-for="bucket in curve" :key="bucket.cost">
                <i :style="{ height: bucket.height + '%' }" :title="`${bucket.count} carte(s) à ${bucket.cost}`"></i>
                <small>{{ bucket.cost }}{{ bucket.cost === 7 ? "+" : "" }}</small>
              </div>
            </div>
            <div class="deck-domains" v-if="domainSpread.length">
              <span
                class="chip"
                v-for="[domain, count] in domainSpread"
                :key="domain"
                :style="{ '--chip': DOMAINS[domain]?.color }"
              >
                {{ DOMAINS[domain]?.label || domain }} · {{ count }}
              </span>
            </div>

            <h4>
              Validation
              <span class="muted" style="font-size: 0.72rem; letter-spacing: 0">
                {{ deck.format === "tournament" ? "règles de tournoi" : "indicatif (mode libre)" }}
              </span>
            </h4>
            <ul class="validator">
              <li v-for="checkItem in deck.checks" :key="checkItem.rule" :class="checkItem.ok ? 'v-ok' : 'v-ko'">
                {{ checkItem.message }}
              </li>
            </ul>

            <button class="btn btn-gold missing-btn" @click="openMissing">Trouver les cartes manquantes</button>

            <h4>Description</h4>
            <textarea
              v-model="deck.description"
              placeholder="Plan de jeu, forces, faiblesses…"
              aria-label="Description du deck"
            ></textarea>
          </div>
        </div>
      </aside>
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
        :style="{ left: `${preview.x}px`, top: `${preview.y}px` }"
        aria-hidden="true"
      >
        <div class="card-art" :class="{ landscape: preview.card.orientation === 'landscape' }">
          <img :src="cardThumb(preview.card.image_url, 460)" alt="" />
        </div>
        <div class="builder-preview-copy">
          <h3>{{ preview.card.name }}</h3>
          <p class="muted mono" style="font-size: 0.7rem">
            {{ TYPES[preview.card.type] || preview.card.type }} ·
            {{ RARITIES[preview.card.rarity] || preview.card.rarity }}
            <template v-if="session.token"> · possédée ×{{ preview.card.owned_qty ?? 0 }}</template>
            <template v-if="inDeckQty(preview.card)"> · dans le deck ×{{ inDeckQty(preview.card) }}</template>
          </p>
          <CardText v-if="preview.card.text" :text="preview.card.text" />
        </div>
      </div>
    </Teleport>

    <!-- Cartes manquantes -->
    <ModalDialog v-if="showMissing" title="Cartes manquantes" wide @close="showMissing = false">
      <p v-if="missingError" class="error">{{ missingError }}</p>
      <p v-else-if="!missing" class="muted">Analyse de votre collection…</p>
      <template v-else-if="missing.items.length">
        <p class="muted" style="margin-bottom: 14px">
          Il vous manque <b>{{ missing.missing_total }}</b> carte(s) sur les {{ missing.deck_total }} du deck. Les
          variantes (art alternatif, signature) comptent comme la carte de base.
        </p>
        <table class="missing-table">
          <thead>
            <tr>
              <th></th>
              <th>Carte</th>
              <th>Requis</th>
              <th>Possédé</th>
              <th>À trouver</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in missing.items" :key="item.card.id">
              <td><img class="row-thumb" :src="cardThumb(item.card.image_url, 84)" alt="" loading="lazy" /></td>
              <td>
                <RouterLink :to="`/cartes/${item.card.id}`">{{ item.card.name }}</RouterLink>
                <span class="muted mono" style="font-size: 0.68rem; display: block">{{
                  item.card.riftbound_id.toUpperCase()
                }}</span>
              </td>
              <td class="num">{{ item.needed }}</td>
              <td class="num">{{ item.owned }}</td>
              <td class="num">
                <b>{{ item.missing }}</b>
              </td>
            </tr>
          </tbody>
        </table>
        <div class="modal-actions">
          <button class="btn btn-ghost" @click="copyMissing">{{ copyLabel }}</button>
        </div>
      </template>
      <p v-else class="success">Vous possédez déjà toutes les cartes de ce deck. Bon match !</p>
    </ModalDialog>
  </section>

  <section v-else>
    <div class="wrap" style="padding-top: 44px">
      <p v-if="error" class="error">{{ error }}</p>
      <p v-else class="muted">Chargement du deck…</p>
    </div>
  </section>
</template>
