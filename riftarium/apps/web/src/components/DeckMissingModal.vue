<script setup>
import { computed, ref } from "vue"
import { api, cardThumb, session } from "../api.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import ModalDialog from "./ModalDialog.vue"

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

const copyLabel = ref("Copier la liste")

/* Toutes les manquantes en un clic : l'API remplit la wishlist depuis le deck. */
const wishLabel = ref("Ajouter les manquantes à ma wishlist")
const wishBusy = ref(false)

async function addMissingToWishlist() {
  if (wishBusy.value || !props.deckId) return
  wishBusy.value = true
  try {
    const payload = await api(`/api/wishlist/from-deck/${props.deckId}`, { method: "POST" })
    wishLabel.value = `${payload.added} ajoutée(s) ✓`
  } catch (e) {
    wishLabel.value = e.message
  } finally {
    wishBusy.value = false
  }
}

async function copyMissing() {
  if (!props.missing?.items.length) return
  const lines = props.missing.items.map(
    (item) => `${item.missing}× ${item.card.name} (${item.card.riftbound_id.toUpperCase()})`
  )
  try {
    await navigator.clipboard.writeText(lines.join("\n"))
    copyLabel.value = "Copié ✓"
  } catch {
    copyLabel.value = "Copie impossible"
  }
}
</script>

<template>
  <ModalDialog title="Cartes manquantes" wide @close="$emit('close')">
    <p v-if="error" class="error">{{ error }}</p>
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
            <th>Prix</th>
          </tr>
        </thead>
        <tbody>
          <!-- focusin/focusout : sans eux, l'aperçu de la carte n'existait qu'au survol
               souris, inaccessible au clavier (le nom de la carte est un lien). -->
          <tr
            v-for="item in missing.items"
            :key="item.card.id"
            @focusin="$emit('preview', item.card, $event, 400)"
            @focusout="$emit('hide-preview')"
          >
            <!-- data-label : sous 560 px le tableau devient une pile de cartes
                 (CSS), les intitulés de colonnes sont repris cellule par cellule. -->
            <td class="missing-thumb">
              <img
                class="row-thumb missing-zoom"
                :src="cardThumb(item.card.image_url, 84)"
                :alt="item.card.name"
                loading="lazy"
                @mouseenter="$emit('preview', item.card, $event, 400)"
                @mouseleave="$emit('hide-preview')"
              />
            </td>
            <td
              class="missing-zoom"
              @mouseenter="$emit('preview', item.card, $event, 400)"
              @mouseleave="$emit('hide-preview')"
            >
              <RouterLink :to="`/cartes/${item.card.id}`">{{ item.card.name }}</RouterLink>
              <span class="muted mono" style="font-size: 0.68rem; display: block">{{
                item.card.riftbound_id.toUpperCase()
              }}</span>
            </td>
            <td class="num" data-label="Requis">{{ item.needed }}</td>
            <td class="num" data-label="Possédé">{{ item.owned }}</td>
            <td class="num" data-label="À trouver">
              <b>{{ item.missing }}</b>
            </td>
            <td class="num price-cell" data-label="Prix" :title="PRICE_NOTE">
              {{ formatEur(item.card.price_eur) || "—" }}
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="missingCost" class="price-missing" :title="PRICE_NOTE">
        Coût pour compléter : <b class="price-amount">{{ missingCost }}</b>
      </p>
      <div class="modal-actions">
        <button
          v-if="deckId && session.token"
          class="btn btn-gold wish-from-deck"
          :disabled="wishBusy"
          @click="addMissingToWishlist"
        >
          {{ wishLabel }}
        </button>
        <button class="btn btn-ghost" @click="copyMissing">{{ copyLabel }}</button>
      </div>
    </template>
    <p v-else class="success">Vous possédez déjà toutes les cartes de ce deck. Bon match !</p>
  </ModalDialog>
</template>
