<script setup>
import { computed } from "vue"
import { RouterLink } from "vue-router"

/* Bouton de la Forge : principal (rouge biseauté), secondaire (filet de bronze),
   fantôme. Un seul composant pour les boutons et les liens d'action. */
const props = defineProps({
  variant: { type: String, default: "primary", validator: (v) => ["primary", "secondary", "ghost"].includes(v) },
  size: { type: String, default: "md", validator: (v) => ["sm", "md"].includes(v) },
  to: { type: [String, Object], default: null },
  href: { type: String, default: null },
  type: { type: String, default: "button" },
  disabled: { type: Boolean, default: false },
  block: { type: Boolean, default: false }
})
defineEmits(["click"])

const tag = computed(() => (props.to ? RouterLink : props.href ? "a" : "button"))
const bindings = computed(() => {
  if (props.to) return { to: props.to }
  if (props.href) return { href: props.href }
  return { type: props.type, disabled: props.disabled }
})
</script>

<template>
  <component
    :is="tag"
    v-bind="bindings"
    class="rift-btn"
    :class="[`rift-btn--${variant}`, `rift-btn--${size}`, { 'rift-btn--block': block }]"
    @click="$emit('click', $event)"
  >
    <slot />
  </component>
</template>

<style scoped>
.rift-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  min-height: 44px;
  padding: 0 var(--space-5);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  text-decoration: none;
  white-space: nowrap;
  color: var(--ink);
  transition:
    background-color var(--t-fast),
    color var(--t-fast),
    border-color var(--t-fast);
}
.rift-btn--sm {
  min-height: 36px;
  padding: 0 var(--space-4);
  font-size: 12px;
}
/* Écran tactile : la taille compacte reste une cible de 44 px. */
@media (hover: none) {
  .rift-btn--sm {
    min-height: 44px;
  }
}
.rift-btn--primary {
  padding-inline: calc(var(--space-5) + var(--cut));
  background: var(--blood);
  color: #fff;
  clip-path: polygon(var(--cut) 0, 100% 0, calc(100% - var(--cut)) 100%, 0 100%);
}
.rift-btn--primary:hover,
.rift-btn--primary:focus-visible {
  background: var(--blood-bright);
  color: #fff;
}
/* Le biseau rogne le contour de focus : on le remplace par un liseré intérieur. */
.rift-btn--primary:focus-visible {
  outline: none;
  box-shadow: inset 0 0 0 2px var(--bronze-light);
}
.rift-btn--secondary {
  border: 1px solid var(--bronze);
  color: var(--bronze-light);
}
.rift-btn--secondary:hover {
  border-color: var(--bronze-light);
  color: var(--ink);
}
.rift-btn--ghost {
  color: var(--ink-muted);
}
.rift-btn--ghost:hover {
  color: var(--ink);
}
.rift-btn--block {
  width: 100%;
}
.rift-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
