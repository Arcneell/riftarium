<script setup>
import { computed, ref } from "vue"

/* Choix unique en puces (groupe radio) : une seule puce dans l'ordre de tabulation,
   les flèches déplacent la sélection. */
const props = defineProps({
  modelValue: { type: String, default: "" },
  options: { type: Array, required: true }, // [{ value, label, title }]
  label: { type: String, required: true }
})
const emit = defineEmits(["update:modelValue"])

const group = ref(null)
/* Sans sélection valide, la première puce reste atteignable au clavier. */
const tabbable = computed(() =>
  props.options.some((o) => o.value === props.modelValue) ? props.modelValue : props.options[0]?.value
)

function select(index) {
  const count = props.options.length
  const position = ((index % count) + count) % count
  emit("update:modelValue", props.options[position].value)
  group.value?.querySelectorAll("[role=radio]")[position]?.focus()
}

function onKey(event, index) {
  const moves = { ArrowRight: index + 1, ArrowDown: index + 1, ArrowLeft: index - 1, ArrowUp: index - 1 }
  let next = moves[event.key]
  if (event.key === "Home") next = 0
  if (event.key === "End") next = props.options.length - 1
  if (next === undefined) return
  event.preventDefault()
  select(next)
}
</script>

<template>
  <div ref="group" class="rift-choice" role="radiogroup" :aria-label="label">
    <button
      v-for="(option, index) in options"
      :key="option.value"
      type="button"
      role="radio"
      class="rift-choice-opt"
      :class="{ selected: option.value === modelValue }"
      :aria-checked="String(option.value === modelValue)"
      :tabindex="option.value === tabbable ? 0 : -1"
      :title="option.title"
      @click="$emit('update:modelValue', option.value)"
      @keydown="onKey($event, index)"
    >
      {{ option.label }}
    </button>
  </div>
</template>

<style scoped>
.rift-choice {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
/* Boutons neutralisés localement : main.css stylise `button` globalement. */
.rift-choice-opt {
  min-height: 44px;
  min-width: 44px;
  padding: 0 var(--space-3);
  border: 1px solid var(--line);
  border-radius: 0;
  background: var(--bg-sunken);
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
.rift-choice-opt:hover {
  color: var(--ink);
  border-color: var(--bronze);
}
.rift-choice-opt:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.rift-choice-opt.selected {
  color: var(--bronze-light);
  border-color: var(--bronze-light);
  background: color-mix(in srgb, var(--bg-sunken), var(--bronze-light) 10%);
}
</style>
