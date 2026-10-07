<script setup>
/* Compteur d'exemplaires de la Forge : « − valeur + ». Le parent tient la valeur et
   répond aux événements ; `busy` désactive les deux boutons pendant une requête. */
defineProps({
  value: { type: Number, required: true },
  min: { type: Number, default: 0 },
  max: { type: Number, default: 999 },
  busy: { type: Boolean, default: false },
  label: { type: String, default: "" },
  size: { type: String, default: "md", validator: (v) => ["md", "sm"].includes(v) }
})
defineEmits(["increment", "decrement"])
</script>

<template>
  <div class="rift-stepper" :class="`rift-stepper--${size}`">
    <button
      type="button"
      class="rift-stepper-btn rift-stepper-minus"
      :aria-label="`Retirer un exemplaire de ${label}`"
      :disabled="busy || value <= min"
      @click="$emit('decrement')"
    >
      −
    </button>
    <span class="rift-stepper-value" aria-live="polite">{{ value }}</span>
    <button
      type="button"
      class="rift-stepper-btn rift-stepper-plus"
      :aria-label="`Ajouter un exemplaire de ${label}`"
      :disabled="busy || value >= max"
      @click="$emit('increment')"
    >
      +
    </button>
  </div>
</template>

<style scoped>
.rift-stepper {
  --stepper-size: 44px;
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
}
.rift-stepper--md {
  --stepper-size: 44px;
}
.rift-stepper--sm {
  --stepper-size: 32px;
}
/* Les boutons sont neutralisés localement : main.css stylise `button` globalement. */
.rift-stepper-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--stepper-size);
  height: var(--stepper-size);
  min-height: 0;
  padding: 0;
  border: 1px solid var(--bronze);
  border-radius: 0;
  background: transparent;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 20px;
  line-height: 1;
  cursor: pointer;
  transition:
    background-color var(--t-fast),
    border-color var(--t-fast),
    color var(--t-fast);
}
.rift-stepper-btn:hover:not(:disabled) {
  border-color: var(--bronze-light);
  color: var(--ink);
}
.rift-stepper-btn:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.rift-stepper-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
.rift-stepper-minus {
  background: transparent;
}
/* Le + : rouge biseauté, comme le bouton principal. Le biseau rogne le contour : liseré intérieur. */
.rift-stepper-plus {
  border: 0;
  background: var(--blood);
  color: #fff;
  clip-path: polygon(25% 0, 100% 0, 75% 100%, 0 100%);
  width: calc(var(--stepper-size) * 1.25);
}
.rift-stepper-plus:hover:not(:disabled) {
  background: var(--blood-bright);
  color: #fff;
}
.rift-stepper-plus:focus-visible {
  outline: none;
  box-shadow: inset 0 0 0 2px var(--bronze-light);
}
.rift-stepper-value {
  min-width: 2ch;
  text-align: center;
  font-family: var(--font-label);
  font-size: 18px;
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}
.rift-stepper--sm .rift-stepper-value {
  font-size: 14px;
}
</style>
