<script setup>
import { ref, useId } from "vue"
import { useDialog } from "./useDialog.js"

/* Feuille du bas (téléphone) : menu du compte, filtres. Même comportement
   clavier et même verrou de défilement que la modale. */
defineProps({ title: { type: String, required: true } })
const emit = defineEmits(["close"])

const sheet = ref(null)
const titleId = `${useId()}-title`
useDialog(sheet, () => emit("close"))
</script>

<template>
  <Teleport to="body">
    <div class="rift-sheet-overlay" @click.self="emit('close')">
      <div ref="sheet" class="rift-sheet" role="dialog" aria-modal="true" :aria-labelledby="titleId" tabindex="-1">
        <div class="rift-sheet-head">
          <h2 :id="titleId">{{ title }}</h2>
          <button type="button" class="rift-sheet-close" aria-label="Fermer" @click="emit('close')">
            <Icon name="x" :size="20" />
          </button>
        </div>
        <div class="rift-sheet-body">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.rift-sheet-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--z-overlay);
  display: flex;
  align-items: flex-end;
  background: rgba(5, 4, 4, 0.72);
}
.rift-sheet {
  width: 100%;
  max-height: 85dvh;
  overflow-y: auto;
  overscroll-behavior: contain;
  padding-bottom: env(safe-area-inset-bottom);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  animation: rift-sheet-in var(--t-base) ease-out;
}
.rift-sheet:focus {
  outline: none;
}
.rift-sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3) var(--space-4);
  border-bottom: 1px solid var(--line);
}
.rift-sheet-head h2 {
  margin: 0;
  font-size: 16px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.rift-sheet-close {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  color: var(--ink-muted);
}
.rift-sheet-body {
  padding: var(--space-4);
}
@keyframes rift-sheet-in {
  from {
    transform: translateY(24px);
    opacity: 0;
  }
}
</style>
