<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { toggleValue } from "../cardText.js"

const props = defineProps({
  label: { type: String, required: true },
  options: { type: Array, required: true },
  modelValue: { type: Array, default: () => [] },
  searchable: { type: Boolean, default: false },
  /* Mode choix unique (ex. tri) : sélectionner remplace, re-cliquer désélectionne, le popup se ferme. */
  single: { type: Boolean, default: false },
  /* Choix unique obligatoire (ex. format d'un deck) : jamais de valeur vide, pas de « Tout décocher ». */
  required: { type: Boolean, default: false }
})
const emit = defineEmits(["update:modelValue"])

/* Options chargées en différé (sets, légendes) : le bouton est rendu tout de suite,
   inactif tant que la liste est vide. Le monter seulement une fois la réponse
   arrivée faisait sauter la barre de filtres, et tout le contenu avec. */
const empty = computed(() => !props.options.length)

const root = ref(null)
const searchInput = ref(null)
const open = ref(false)
const needle = ref("")
const selectedGlyphs = computed(() =>
  props.options.filter((option) => option.glyph && props.modelValue.includes(option.value))
)
const visibleOptions = computed(() => {
  const q = needle.value.trim().toLowerCase()
  if (!q) return props.options
  return props.options.filter((option) => option.label.toLowerCase().includes(q))
})

function toggle(value) {
  if (props.single) {
    const cleared = props.modelValue.includes(value) && !props.required
    emit("update:modelValue", cleared ? [] : [value])
    open.value = false
    return
  }
  emit("update:modelValue", toggleValue(props.modelValue, value))
}

/* En mode single, le bouton affiche le libellé du choix plutôt qu'un compteur. */
const singleLabel = computed(() =>
  props.single && props.modelValue.length
    ? props.options.find((option) => option.value === props.modelValue[0])?.label
    : null
)

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

watch(open, async (isOpen) => {
  needle.value = ""
  if (isOpen && props.searchable) {
    await nextTick()
    searchInput.value?.focus()
  }
})

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
      :disabled="empty"
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
      <span v-else-if="singleLabel" class="fsel-single">{{ singleLabel }}</span>
      <span v-else-if="modelValue.length" class="fsel-count">{{ modelValue.length }}</span>
      <svg class="fsel-caret" width="11" height="11" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M5 9l7 7 7-7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" />
      </svg>
    </button>

    <div v-if="open" class="fsel-pop" role="group" :aria-label="label">
      <input
        v-if="searchable"
        ref="searchInput"
        type="search"
        class="fsel-search"
        v-model="needle"
        :placeholder="`Filtrer les ${label.toLowerCase()}…`"
        :aria-label="`Filtrer les ${label.toLowerCase()}`"
        @click.stop
      />
      <button
        v-for="option in visibleOptions"
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
      <p v-if="searchable && !visibleOptions.length" class="fsel-empty">Aucun résultat</p>
      <button v-if="modelValue.length && !required" type="button" class="fsel-clear" @click="clear">
        Tout décocher
      </button>
    </div>
  </div>
</template>
