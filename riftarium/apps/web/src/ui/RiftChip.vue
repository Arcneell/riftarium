<script setup>
import { computed } from "vue"

/* Puce de la Forge : filtre à bascule (aria-pressed) ou filtre actif retirable. */
const props = defineProps({
  label: { type: String, required: true },
  selected: { type: Boolean, default: false },
  removable: { type: Boolean, default: false },
  glyph: { type: String, default: "" },
  glyphKind: { type: String, default: "" },
  color: { type: String, default: "" },
  /* Simple affichage : un span sans rôle de bascule, sans clic ni tabulation. */
  static: { type: Boolean, default: false }
})
const emit = defineEmits(["toggle", "remove"])

const style = computed(() => (props.color ? { "--chip-color": props.color } : undefined))
function onClick() {
  emit(props.removable ? "remove" : "toggle")
}
</script>

<template>
  <component
    :is="$props.static ? 'span' : 'button'"
    :type="$props.static ? undefined : 'button'"
    class="rift-chip"
    :class="{ selected, removable }"
    :style="style"
    :aria-pressed="$props.static || removable ? undefined : String(selected)"
    :aria-label="removable && !$props.static ? `Retirer le filtre ${label}` : undefined"
    @click="!$props.static && onClick()"
  >
    <img v-if="glyph" class="rb-glyph" :class="glyphKind" :src="glyph" alt="" width="16" height="16" />
    <span>{{ label }}</span>
    <span v-if="removable" class="rift-chip-x" aria-hidden="true">✕</span>
  </component>
</template>

<style scoped>
.rift-chip {
  --chip-color: var(--bronze-light);
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  min-height: 32px;
  padding: 0 var(--space-3);
  border: 1px solid var(--line);
  background: var(--bg-sunken);
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  transition:
    border-color var(--t-fast),
    color var(--t-fast);
}
.rift-chip:hover {
  color: var(--ink);
  border-color: var(--bronze);
}
.rift-chip.selected,
.rift-chip.removable {
  color: var(--chip-color);
  border-color: var(--chip-color);
  background: color-mix(in srgb, var(--bg-sunken), var(--chip-color) 10%);
}
/* Écran tactile : la puce bouton reste une cible de 44 px (les puces statiques, des span, restent compactes). */
@media (hover: none) {
  button.rift-chip {
    min-height: 44px;
  }
}
.rift-chip-x {
  margin-left: var(--space-1);
  font-size: 11px;
}
</style>
