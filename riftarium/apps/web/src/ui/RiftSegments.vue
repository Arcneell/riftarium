<script setup>
import { computed, ref } from "vue"

/* Onglets dans une page (tablist) : un seul onglet dans l'ordre de tabulation,
   les flèches déplacent la sélection. Les panneaux restent à la page, qui pose
   `id="${idBase}-panel-${value}"`, `role="tabpanel"` et `aria-labelledby`. */
const props = defineProps({
  modelValue: { type: String, default: "" },
  items: { type: Array, required: true }, // [{ value, label, badge? }]
  label: { type: String, required: true },
  idBase: { type: String, required: true }
})
const emit = defineEmits(["update:modelValue"])

const bar = ref(null)
/* Sans sélection valide, le premier onglet reste atteignable au clavier. */
const tabbable = computed(() =>
  props.items.some((i) => i.value === props.modelValue) ? props.modelValue : props.items[0]?.value
)
const hasBadge = (item) => item.badge !== undefined && item.badge !== null && item.badge !== ""

function select(index) {
  const count = props.items.length
  const position = ((index % count) + count) % count
  emit("update:modelValue", props.items[position].value)
  bar.value?.querySelectorAll("[role=tab]")[position]?.focus()
}

function onKey(event, index) {
  if (event.altKey || event.ctrlKey || event.metaKey) return
  const moves = { ArrowRight: index + 1, ArrowLeft: index - 1, Home: 0, End: props.items.length - 1 }
  const next = moves[event.key]
  if (next === undefined) return
  event.preventDefault()
  select(next)
}
</script>

<template>
  <div ref="bar" class="rift-segments" role="tablist" :aria-label="label">
    <button
      v-for="(item, index) in items"
      :id="`${idBase}-tab-${item.value}`"
      :key="item.value"
      type="button"
      role="tab"
      class="rift-segments-tab"
      :class="{ selected: item.value === modelValue }"
      :aria-selected="String(item.value === modelValue)"
      :aria-controls="`${idBase}-panel-${item.value}`"
      :tabindex="item.value === tabbable ? 0 : -1"
      @click="$emit('update:modelValue', item.value)"
      @keydown="onKey($event, index)"
    >
      {{ item.label }}
      <span v-if="hasBadge(item)" class="rift-segments-badge">{{ item.badge }}</span>
    </button>
  </div>
</template>

<style scoped>
.rift-segments {
  position: sticky;
  top: 0;
  z-index: 5;
  display: flex;
  width: 100%;
  background: var(--bg-raised);
  border-bottom: 1px solid var(--line);
}
/* Boutons neutralisés localement : main.css stylise `button` globalement. */
.rift-segments-tab {
  flex: 1 1 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  min-height: 44px;
  padding: 0 var(--space-3);
  border: 0;
  border-bottom: 2px solid transparent;
  border-radius: 0;
  background: transparent;
  box-shadow: none;
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  cursor: pointer;
  transition:
    border-color var(--t-fast),
    color var(--t-fast);
}
.rift-segments-tab:hover {
  color: var(--ink);
}
.rift-segments-tab:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.rift-segments-tab.selected {
  color: var(--ink);
  border-bottom-color: var(--blood);
}
.rift-segments-badge {
  min-width: 20px;
  padding: 0 6px;
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  color: var(--ink-muted);
  font-size: 11px;
  line-height: 18px;
  text-align: center;
}
@media (prefers-reduced-motion: reduce) {
  .rift-segments-tab {
    transition: none;
  }
}
</style>
