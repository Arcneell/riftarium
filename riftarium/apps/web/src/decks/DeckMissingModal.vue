<script setup>
import { computed, onUnmounted, ref } from "vue"
import { api, cardThumb, session } from "../api.js"
import { copyText } from "../deckExport.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftModal from "../ui/RiftModal.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

/* Modale « cartes manquantes » : la comparaison deck/collection calculée par l'API.
   L'aperçu au survol reste géré par l'éditeur (événements preview / hide-preview). */
const props = defineProps({
  missing: { type: Object, default: null }, // null tant que l'analyse est en cours
  error: { type: String, default: "" },
  missingEur: { type: Number, default: null }, // prices.missing_eur du deck (null si rien de pricé)
  deckId: { type: [Number, String], default: null } // requis pour « ajouter à la wishlist »
})
defineEmits(["close", "preview", "hide-preview"])

const missingCost = computed(() => formatEur(props.missingEur))

const COPY_LABEL = "Copier la liste"
const WISH_LABEL = "Ajouter les manquantes à ma wishlist"

const copyLabel = ref(COPY_LABEL)

/* Toutes les manquantes en un clic : l'API remplit la wishlist depuis le deck. */
const wishLabel = ref(WISH_LABEL)
const wishBusy = ref(false)

/* Les deux boutons annoncent leur résultat puis reprennent leur intitulé : sans
   ce retour, « Copié » restait figé et le bouton ne disait plus ce qu'il fait. */
const FLASH_DELAY = 3000
let copyTimer = 0
let wishTimer = 0

function flashCopy(message) {
  copyLabel.value = message
  clearTimeout(copyTimer)
  copyTimer = window.setTimeout(() => (copyLabel.value = COPY_LABEL), FLASH_DELAY)
}

function flashWish(message) {
  wishLabel.value = message
  clearTimeout(wishTimer)
  wishTimer = window.setTimeout(() => (wishLabel.value = WISH_LABEL), FLASH_DELAY)
}

onUnmounted(() => {
  clearTimeout(copyTimer)
  clearTimeout(wishTimer)
})

async function addMissingToWishlist() {
  if (wishBusy.value || !props.deckId) return
  wishBusy.value = true
  try {
    const payload = await api(`/api/wishlist/from-deck/${props.deckId}`, { method: "POST" })
    flashWish(`${payload.added} ajoutée(s)`)
  } catch (e) {
    flashWish(e.message)
  } finally {
    wishBusy.value = false
  }
}

async function copyMissing() {
  if (!props.missing?.items.length) return
  const lines = props.missing.items.map(
    (item) => `${item.missing}× ${item.card.name} (${(item.card.riftbound_id || "").toUpperCase()})`
  )
  try {
    /* Même chemin de copie que la barre d'export (message d'erreur unifié). */
    await copyText(lines.join("\n"))
    flashCopy("Copié")
  } catch (e) {
    flashCopy(e.message || "Copie impossible")
  }
}
</script>

<template>
  <RiftModal title="Cartes manquantes" wide @close="$emit('close')">
    <p v-if="error" class="atelier-missing-error" role="alert">{{ error }}</p>
    <template v-else-if="!missing">
      <p class="sr-only" role="status">Analyse de votre collection…</p>
      <RiftSkeleton :lines="4" />
    </template>
    <template v-else-if="missing.items.length">
      <p class="atelier-missing-intro">
        Il vous manque <b>{{ missing.missing_total }}</b> carte(s) sur les {{ missing.deck_total }} du deck. Les
        variantes (art alternatif, signature) comptent comme la carte de base.
      </p>
      <ul class="atelier-missing-list">
        <!-- focusin/focusout : sans eux, l'aperçu de la carte n'existait qu'au survol
             souris, inaccessible au clavier (le nom de la carte est un lien). -->
        <li
          v-for="item in missing.items"
          :key="item.card.id"
          class="atelier-missing-item"
          @focusin="$emit('preview', item.card, $event, 400)"
          @focusout="$emit('hide-preview')"
        >
          <img
            class="atelier-missing-thumb"
            :src="cardThumb(item.card.image_url, 84)"
            :alt="item.card.name"
            loading="lazy"
            @mouseenter="$emit('preview', item.card, $event, 400)"
            @mouseleave="$emit('hide-preview')"
          />
          <div
            class="atelier-missing-copy"
            @mouseenter="$emit('preview', item.card, $event, 400)"
            @mouseleave="$emit('hide-preview')"
          >
            <RouterLink class="atelier-missing-name" :to="`/cartes/${item.card.id}`">{{ item.card.name }}</RouterLink>
            <span class="atelier-missing-id">{{ (item.card.riftbound_id || "").toUpperCase() }}</span>
          </div>
          <span class="atelier-missing-qty">×{{ item.missing }} manquante(s)</span>
          <span class="atelier-missing-price" :title="PRICE_NOTE">{{ formatEur(item.card.price_eur) || "—" }}</span>
        </li>
      </ul>
      <p v-if="missingCost" class="atelier-missing-cost" :title="PRICE_NOTE">
        Coût pour compléter : <b>{{ missingCost }}</b>
      </p>
      <div class="atelier-missing-actions" aria-live="polite">
        <RiftButton variant="secondary" @click="copyMissing">{{ copyLabel }}</RiftButton>
        <RiftButton v-if="deckId && session.token" :disabled="wishBusy" @click="addMissingToWishlist">
          {{ wishLabel }}
        </RiftButton>
      </div>
    </template>
    <p v-else class="atelier-missing-done">Vous possédez déjà toutes les cartes de ce deck.</p>
  </RiftModal>
</template>

<style scoped>
.atelier-missing-error {
  margin: 0;
  color: var(--blood-text);
}
.atelier-missing-intro {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
  line-height: 1.5;
}
.atelier-missing-intro b {
  color: var(--ink);
}
.atelier-missing-list {
  display: grid;
  gap: var(--space-2);
  margin: 0;
  padding: 0;
  list-style: none;
}
.atelier-missing-item {
  display: grid;
  grid-template-columns: 38px minmax(0, 1fr) auto auto;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-3);
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
}
.atelier-missing-thumb {
  display: block;
  width: 38px;
  aspect-ratio: 744 / 1039;
  object-fit: cover;
  border-radius: 3px;
  cursor: zoom-in;
}
.atelier-missing-copy {
  min-width: 0;
  cursor: zoom-in;
}
.atelier-missing-name {
  display: block;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  color: var(--ink);
  text-decoration: none;
}
.atelier-missing-name:hover {
  color: var(--bronze-light);
}
.atelier-missing-name:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.atelier-missing-id {
  display: block;
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.08em;
  color: var(--ink-muted);
}
.atelier-missing-qty {
  white-space: nowrap;
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  color: var(--blood-text);
}
.atelier-missing-price {
  min-width: 64px;
  white-space: nowrap;
  text-align: right;
  font-family: var(--font-label);
  font-size: 14px;
  color: var(--bronze-light);
}
.atelier-missing-cost {
  margin: var(--space-4) 0 0;
  font-family: var(--font-label);
  font-size: 15px;
  color: var(--ink-muted);
}
.atelier-missing-cost b {
  color: var(--bronze-light);
}
.atelier-missing-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: var(--space-2);
  margin-top: var(--space-4);
}
.atelier-missing-done {
  margin: 0;
  color: var(--ink);
}
/* Téléphone : la quantité et le prix passent sous le nom. */
@media (max-width: 559px) {
  .atelier-missing-item {
    grid-template-columns: 38px minmax(0, 1fr) auto;
  }
  .atelier-missing-thumb {
    grid-row: span 2;
  }
  .atelier-missing-qty {
    grid-column: 2;
    grid-row: 2;
  }
  .atelier-missing-price {
    grid-column: 3;
    grid-row: 1;
  }
}
</style>
