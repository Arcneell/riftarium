<script setup>
import { ref } from "vue"
import { cardThumb } from "../api.js"
import ModalDialog from "./ModalDialog.vue"

/* Modale « cartes manquantes » : la comparaison deck/collection calculée par l'API.
   L'aperçu au survol reste géré par l'éditeur (événements preview / hide-preview). */
const props = defineProps({
  missing: { type: Object, default: null }, // null tant que l'analyse est en cours
  error: { type: String, default: "" }
})
defineEmits(["close", "preview", "hide-preview"])

const copyLabel = ref("Copier la liste")

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
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in missing.items" :key="item.card.id">
            <td>
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
</template>
