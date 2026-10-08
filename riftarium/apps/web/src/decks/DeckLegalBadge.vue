<script setup>
import { computed } from "vue"
import { legalState } from "../deckDisplay.js"

const props = defineProps({
  deck: { type: Object, required: true },
  /* Écrit aussi la raison d'illégalité en clair : au doigt, l'infobulle ne s'ouvre jamais. */
  explain: { type: Boolean, default: false }
})

const legal = computed(() => legalState(props.deck))
</script>

<template>
  <!-- role="img" : sans rôle, un aria-label posé sur un span générique est ignoré
       par les lecteurs d'écran ; la raison remplace alors « Légal ». -->
  <span
    class="legalite"
    :class="legal.ok ? 'legalite--ok' : 'legalite--ko'"
    role="img"
    :title="legal.title"
    :aria-label="legal.title"
  >
    <span class="legalite-glyph" aria-hidden="true">{{ legal.ok ? "✓" : "✕" }}</span>
    {{ legal.label }}
  </span>
  <p v-if="explain && !legal.ok" class="legalite-why">{{ legal.title }}</p>
</template>

<style scoped>
.legalite {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  padding: 2px var(--space-2);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  white-space: nowrap;
  background: rgba(13, 13, 15, 0.72);
}
.legalite--ok {
  border: 1px solid var(--bronze-light);
  color: var(--bronze-light);
}
.legalite--ko {
  border: 1px solid var(--blood);
  color: var(--blood-text);
}
.legalite-glyph {
  font-size: 11px;
}
.legalite-why {
  margin: 0;
  font-family: var(--font-body);
  font-size: 13px;
  line-height: 1.35;
  color: var(--blood-text);
}
</style>
