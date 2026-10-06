<script setup>
import { ref, useId } from "vue"
import { useDialog } from "./useDialog.js"

const props = defineProps({
  title: { type: String, required: true },
  wide: { type: Boolean, default: false }
})
const emit = defineEmits(["close"])

const modal = ref(null)
const titleId = `${useId()}-title`
useDialog(modal, () => emit("close"))
</script>

<template>
  <Teleport to="body">
    <!-- @click.self et non @pointerdown.self : au doigt, un début de glissement
         sur le fond fermait la modale avant même le relâchement. -->
    <div class="rift-modal-overlay" @click.self="emit('close')">
      <div
        ref="modal"
        class="rift-modal"
        :class="{ wide: props.wide }"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="titleId"
        tabindex="-1"
      >
        <div class="rift-modal-head">
          <h3 :id="titleId">{{ title }}</h3>
          <button type="button" class="rift-modal-close" aria-label="Fermer" @click="emit('close')">✕</button>
        </div>
        <div class="rift-modal-body">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.rift-modal-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--z-overlay);
  display: grid;
  place-items: center;
  padding: var(--space-4);
  background: rgba(5, 4, 4, 0.78);
}
.rift-modal {
  width: min(560px, 100%);
  max-height: calc(100dvh - 2 * var(--space-4));
  display: flex;
  flex-direction: column;
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow:
    inset 0 0 0 1px var(--line),
    var(--shadow-deep);
  clip-path: polygon(
    var(--cut) 0,
    100% 0,
    100% calc(100% - var(--cut)),
    calc(100% - var(--cut)) 100%,
    0 100%,
    0 var(--cut)
  );
}
.rift-modal.wide {
  width: min(960px, 100%);
}
.rift-modal:focus {
  outline: none;
}
.rift-modal-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--line);
}
.rift-modal-head h3 {
  font-size: 18px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.rift-modal-close {
  width: 44px;
  height: 44px;
  color: var(--ink-muted);
}
.rift-modal-close:hover {
  color: var(--ink);
}
.rift-modal-body {
  padding: var(--space-5);
  overflow-y: auto;
}
</style>
