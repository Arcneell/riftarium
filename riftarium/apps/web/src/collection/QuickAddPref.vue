<script setup>
import { computed, ref } from "vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import { conditionOptions, defaultsLabel, langOptions } from "./collectionDefaults.js"

/* Rappel de la préférence d'ajout (« Ajouts en NM · Français · changer ») et feuille pour
   la modifier. `defaults` est l'objet réactif partagé (useQuickAdd) ; les changements
   remontent par `update(patch)` et c'est le parent qui les applique. */
const props = defineProps({
  defaults: { type: Object, required: true }
})
const emit = defineEmits(["update"])

const summary = computed(() => defaultsLabel(props.defaults))
const open = ref(false)
</script>

<template>
  <p class="quick-pref-line">
    Ajouts en
    <button type="button" class="quick-pref" @click="open = true">{{ summary }} · changer</button>
  </p>

  <RiftSheet v-if="open" title="Ajouts par défaut" @close="open = false">
    <div class="quick-sheet">
      <RiftChoice
        label="État par défaut"
        :model-value="defaults.condition"
        :options="conditionOptions"
        @update:model-value="emit('update', { condition: $event })"
      />
      <RiftChoice
        label="Langue par défaut"
        :model-value="defaults.lang"
        :options="langOptions"
        @update:model-value="emit('update', { lang: $event })"
      />
      <RiftButton block @click="open = false">Fermer</RiftButton>
    </div>
  </RiftSheet>
</template>

<style scoped>
.quick-pref-line {
  margin: 0;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.08em;
  color: var(--ink-muted);
}
/* Bouton redéfini ici : fond, filet et curseur ne viennent pas du style de base. */
.quick-pref {
  min-height: 0;
  padding: 0;
  border: 0;
  border-bottom: 1px dotted var(--bronze);
  border-radius: 0;
  background: none;
  color: var(--bronze-light);
  font: inherit;
  letter-spacing: inherit;
  text-transform: none;
  cursor: pointer;
}
.quick-pref:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.quick-sheet {
  display: grid;
  gap: var(--space-4);
}
</style>
