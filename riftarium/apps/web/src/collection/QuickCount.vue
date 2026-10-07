<script setup>
import { ref, watch } from "vue"
import RiftStepper from "../ui/RiftStepper.vue"
import { useOwnedCopies } from "./useOwnedCopies.js"

/* Compteur rapide posé en bas de l'illustration d'une vignette. Les lots ne sont chargés
   qu'au premier « − » (il faut savoir quel lot réduire). `defaults` (réactif) est partagé
   par toutes les vignettes de la page. Émet `change({ id, owned_qty })`. */
const props = defineProps({
  card: { type: Object, required: true },
  defaults: { type: Object, default: undefined }
})
const emit = defineEmits(["change"])

const shown = ref(props.card.owned_qty ?? 0)
watch(
  () => props.card.owned_qty,
  (next) => (shown.value = next ?? 0)
)

const owned = useOwnedCopies(() => props.card.id, {
  autoload: false,
  defaults: props.defaults,
  onChange: (patch) => {
    shown.value = patch.owned_qty
    emit("change", patch)
  }
})

/* Le compteur vit dans le lien de la vignette : aucun clic ne doit le suivre. */
function swallow(event) {
  event.preventDefault()
  event.stopPropagation()
}

const increment = () => owned.increment()
async function decrement() {
  if (!owned.entries.value.length) await owned.load()
  await owned.decrement()
}
</script>

<template>
  <div class="quick-count" @click="swallow" @keydown.enter.stop @keydown.space.stop>
    <RiftStepper
      size="sm"
      :value="shown"
      :busy="owned.busy.value || owned.loading.value"
      :label="card.name"
      @increment="increment"
      @decrement="decrement"
    />
    <span v-if="owned.error.value" class="quick-count-error" role="alert" :title="owned.error.value">
      <span aria-hidden="true">!</span>
      <span class="sr-only">Échec de la mise à jour : {{ owned.error.value }}</span>
    </span>
  </div>
</template>

<style scoped>
.quick-count {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-1);
  padding: var(--space-1);
  background: linear-gradient(to top, rgba(13, 13, 15, 0.92), rgba(13, 13, 15, 0));
}
.quick-count-error {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border: 1px solid var(--blood-text);
  color: var(--blood-text);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
  cursor: help;
}
</style>
