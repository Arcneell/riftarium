<script setup>
import { onBeforeUnmount, onMounted } from "vue"

const props = defineProps({
  title: { type: String, required: true },
  wide: { type: Boolean, default: false }
})
const emit = defineEmits(["close"])

function onKeydown(event) {
  if (event.key === "Escape") emit("close")
}

onMounted(() => {
  document.addEventListener("keydown", onKeydown)
  document.body.style.overflow = "hidden"
})

onBeforeUnmount(() => {
  document.removeEventListener("keydown", onKeydown)
  document.body.style.overflow = ""
})
</script>

<template>
  <Teleport to="body">
    <div class="modal-overlay" @pointerdown.self="emit('close')">
      <div class="modal" :class="{ wide: props.wide }" role="dialog" aria-modal="true" :aria-label="title">
        <div class="modal-head">
          <h3>{{ title }}</h3>
          <button type="button" class="modal-close" aria-label="Fermer" @click="emit('close')">✕</button>
        </div>
        <div class="modal-body">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>
