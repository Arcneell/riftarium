<script setup>
import { ref, useId } from "vue"

/* Champ de la Forge. Les attributs non déclarés (ARIA, écouteurs clavier,
   autocomplete…) vont sur l'<input>, pas sur l'enveloppe : la palette de
   recherche s'en sert pour en faire un combobox. */
defineOptions({ inheritAttrs: false })

const props = defineProps({
  label: { type: String, required: true },
  hideLabel: { type: Boolean, default: false },
  search: { type: Boolean, default: false },
  type: { type: String, default: "text" },
  placeholder: { type: String, default: "" },
  error: { type: String, default: "" }
})
const model = defineModel({ type: String, default: "" })

const id = useId()
const errorId = `${id}-error`
const input = ref(null)

defineExpose({ focus: () => input.value?.focus() })
</script>

<template>
  <div class="rift-field" :class="{ 'rift-field--search': search, 'rift-field--invalid': error }">
    <label :for="id" class="rift-field-label" :class="{ 'sr-only': hideLabel }">{{ label }}</label>
    <div class="rift-field-box">
      <Icon v-if="search" name="search" :size="16" class="rift-field-icon" />
      <input
        :id="id"
        ref="input"
        v-model="model"
        class="rift-field-input"
        :type="search ? 'search' : props.type"
        :placeholder="placeholder"
        :aria-invalid="error ? 'true' : undefined"
        :aria-describedby="error ? errorId : undefined"
        v-bind="$attrs"
      />
    </div>
    <p v-if="error" :id="errorId" class="rift-field-error">{{ error }}</p>
  </div>
</template>

<style scoped>
.rift-field {
  display: grid;
  gap: var(--space-1);
}
.rift-field-label {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.rift-field-box {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 44px;
  padding: 0 var(--space-3);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  transition: border-color var(--t-fast);
}
.rift-field-box:focus-within {
  border-color: var(--bronze-light);
}
.rift-field--invalid .rift-field-box {
  border-color: var(--blood-bright);
}
.rift-field-icon {
  flex: none;
  color: var(--ink-muted);
}
.rift-field-input {
  flex: 1;
  min-width: 0;
  background: none;
  border: none;
  color: var(--ink);
  font: inherit;
}
.rift-field-input:focus {
  outline: none;
}
.rift-field-input::placeholder {
  color: var(--ink-muted);
}
.rift-field-error {
  font-size: 13px;
  color: var(--blood-text);
}
</style>
