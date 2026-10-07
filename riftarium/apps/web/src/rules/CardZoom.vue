<script setup>
import { cardThumb } from "../api.js"
import RiftModal from "../ui/RiftModal.vue"

/* Zoom d'une carte dans un vrai dialogue. useDialog gère Échap, le piège à focus et
   le retour du focus au déclencheur (élément actif à l'ouverture). Le titre de
   RiftModal n'est pas masquable : le nom de la carte reste affiché. */
defineProps({ card: { type: Object, required: true } })
const emit = defineEmits(["close"])
</script>

<template>
  <RiftModal :title="card.name" @close="emit('close')">
    <img class="carte-zoom-img" :src="cardThumb(card.img, 1024)" :alt="card.name" @click="emit('close')" />
  </RiftModal>
</template>

<style>
/* Non scopé : le contenu est téléporté dans le body par RiftModal. */
.carte-zoom-img {
  display: block;
  max-width: 100%;
  max-height: 90vh;
  max-height: 90dvh;
  margin: 0 auto;
  object-fit: contain;
  cursor: zoom-out;
}
</style>
