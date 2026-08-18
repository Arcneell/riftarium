<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue"
import { toggleValue } from "../cardText.js"

const props = defineProps({
  label: { type: String, required: true },
  options: { type: Array, required: true },
  modelValue: { type: Array, default: () => [] }
})
const emit = defineEmits(["update:modelValue"])

const root = ref(null)
const open = ref(false)
const selectedGlyphs = computed(() =>
  props.options.filter((option) => option.glyph && props.modelValue.includes(option.value))
)

function toggle(value) {
  emit("update:modelValue", toggleValue(props.modelValue, value))
}

function clear() {
  emit("update:modelValue", [])
  open.value = false
}

function onPointerDown(event) {
  if (open.value && root.value && !root.value.contains(event.target)) open.value = false
}

function onKeydown(event) {
  if (event.key === "Escape") open.value = false
}

onMounted(() => {
  document.addEventListener("pointerdown", onPointerDown)
  document.addEventListener("keydown", onKeydown)
})

onBeforeUnmount(() => {
  document.removeEventListener("pointerdown", onPointerDown)
  document.removeEventListener("keydown", onKeydown)
})
</script>

<template>
  <div ref="root" class="fsel">
    <button
      type="button"
      class="fsel-btn"
      :class="{ open, active: modelValue.length > 0 }"
      :aria-expanded="open"
      :aria-label="`Filtrer par ${label.toLowerCase()}`"
      @click="open = !open"
    >
      {{ label }}
      <span v-if="selectedGlyphs.length" class="fsel-glyphs">
        <img
          v-for="option in selectedGlyphs"
          :key="option.value"
          class="rb-glyph"
          :class="option.glyphKind"
          :src="option.glyph"
          :alt="option.label"
          width="18"
          height="18"
        />
      </span>
      <span v-else-if="modelValue.length" class="fsel-count">{{ modelValue.length }}</span>
      <svg class="fsel-caret" width="11" height="11" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M5 9l7 7 7-7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" />
      </svg>
    </button>

    <div v-if="open" class="fsel-pop" role="group" :aria-label="label">
      <button
        v-for="option in options"
        :key="option.value"
        type="button"
        class="fsel-opt"
        :class="{ on: modelValue.includes(option.value) }"
        :aria-pressed="modelValue.includes(option.value)"
        :style="!option.glyph && option.color ? { '--chip': option.color } : null"
        @click="toggle(option.value)"
      >
        <span v-if="!option.glyph" class="fsel-tick"></span>
        <img
          v-if="option.glyph"
          class="rb-glyph"
          :class="option.glyphKind"
          :src="option.glyph"
          :alt="option.label"
          width="22"
          height="22"
        />
        {{ option.label }}
      </button>
      <button v-if="modelValue.length" type="button" class="fsel-clear" @click="clear">Tout décocher</button>
    </div>
  </div>
</template>
