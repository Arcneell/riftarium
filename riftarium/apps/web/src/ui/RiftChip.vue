<script setup>
import { computed } from "vue"

/* Puce de la Forge : filtre à bascule (aria-pressed) ou filtre actif retirable. */
const props = defineProps({
  label: { type: String, required: true },
  selected: { type: Boolean, default: false },
  removable: { type: Boolean, default: false },
  glyph: { type: String, default: "" },
  glyphKind: { type: String, default: "" },
  color: { type: String, default: "" }
})
const emit = defineEmits(["toggle", "remove"])

const style = computed(() => (props.color ? { "--chip-color": props.color } : undefined))
function onClick() {
  emit(props.removable ? "remove" : "toggle")
}
</script>

<template>
  <button
    type="button"
    class="rift-chip"
    :class="{ selected, removable }"
    :style="style"
    :aria-pressed="removable ? undefined : String(selected)"
    :aria-label="removable ? `Retirer le filtre ${label}` : undefined"
    @click="onClick"
  >
    <img v-if="glyph" class="rb-glyph" :class="glyphKind" :src="glyph" alt="" width="16" height="16" />
    <span>{{ label }}</span>
    <span v-if="removable" class="rift-chip-x" aria-hidden="true">✕</span>
  </button>
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
.rift-chip-x {
  margin-left: var(--space-1);
  font-size: 11px;
}
</style>
