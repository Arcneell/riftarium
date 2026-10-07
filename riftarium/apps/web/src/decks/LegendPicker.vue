<script setup>
import { computed, nextTick, onBeforeUnmount, ref, useId, watch } from "vue"
import { cardThumb } from "../api.js"
import { toggleValue } from "../cardText.js"
import RiftChip from "../ui/RiftChip.vue"
import RiftField from "../ui/RiftField.vue"

/* Sélecteur de légendes (motif ARIA combobox + listbox, sélection multiple). La liste
   s'ouvre dans le flux du panneau, sous le champ ; les légendes choisies restent visibles
   en puces retirables quand elle est fermée. */
const props = defineProps({
  legends: { type: Array, default: () => [] }, // [{ id, name, image_url, deck_count }]
  modelValue: { type: Array, default: () => [] }
})
const emit = defineEmits(["update:modelValue"])

/* Filtre sans casse ni accents. */
function fold(text) {
  return String(text).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}

const uid = useId()
const listId = `${uid}-list`
const root = ref(null)
const list = ref(null)
const query = ref("")
const open = ref(false)
const activeIndex = ref(-1)

const shown = computed(() => {
  const needle = fold(query.value.trim())
  if (!needle) return props.legends
  return props.legends.filter((item) => fold(item.name).includes(needle))
})
const selectedLegends = computed(() => props.legends.filter((item) => props.modelValue.includes(item.id)))
const optionId = (index) => `${uid}-opt-${index}`
const activeId = computed(() => (open.value && activeIndex.value >= 0 ? optionId(activeIndex.value) : undefined))

function toggle(id) {
  emit("update:modelValue", toggleValue(props.modelValue, id))
}

function openList() {
  open.value = true
}
function closeList() {
  open.value = false
  activeIndex.value = -1
}

function move(target) {
  if (!shown.value.length) return
  open.value = true
  activeIndex.value = Math.max(0, Math.min(shown.value.length - 1, target))
  nextTick(() => document.getElementById(optionId(activeIndex.value))?.scrollIntoView?.({ block: "nearest" }))
}

function onKeydown(event) {
  switch (event.key) {
    case "ArrowDown":
      event.preventDefault()
      move(activeIndex.value + 1)
      break
    case "ArrowUp":
      event.preventDefault()
      move(activeIndex.value - 1)
      break
    case "Home":
      if (!open.value) return
      event.preventDefault()
      move(0)
      break
    case "End":
      if (!open.value) return
      event.preventDefault()
      move(shown.value.length - 1)
      break
    case "Enter":
      if (open.value && activeIndex.value >= 0 && shown.value[activeIndex.value]) {
        event.preventDefault()
        toggle(shown.value[activeIndex.value].id)
      }
      break
    case "Escape":
      if (open.value) closeList()
      else query.value = ""
      break
    case "Tab":
      closeList()
      break
  }
}

/* Une nouvelle saisie rouvre la liste et repart d'aucune option active. */
watch(query, () => {
  open.value = true
  activeIndex.value = -1
})

/* Clic en dehors : écouteur posé seulement tant que la liste est ouverte. */
function onOutside(event) {
  if (root.value && !root.value.contains(event.target)) closeList()
}
watch(open, (isOpen) => {
  if (isOpen) document.addEventListener("pointerdown", onOutside)
  else document.removeEventListener("pointerdown", onOutside)
})
onBeforeUnmount(() => document.removeEventListener("pointerdown", onOutside))
</script>

<template>
  <div ref="root" class="legende-picker">
    <RiftField
      v-model="query"
      search
      label="Légende"
      placeholder="Rechercher une légende…"
      role="combobox"
      autocomplete="off"
      autocapitalize="off"
      autocorrect="off"
      spellcheck="false"
      aria-autocomplete="list"
      :aria-expanded="String(open)"
      :aria-controls="listId"
      :aria-activedescendant="activeId"
      @focus="openList"
      @click="openList"
      @keydown="onKeydown"
    />

    <ul
      v-show="open"
      :id="listId"
      ref="list"
      class="legende-list"
      role="listbox"
      aria-multiselectable="true"
      aria-label="Légendes"
    >
      <li
        v-for="(item, index) in shown"
        :id="optionId(index)"
        :key="item.id"
        class="legende-option"
        :class="{ active: index === activeIndex }"
        role="option"
        :aria-selected="String(modelValue.includes(item.id))"
        @mousedown.prevent
        @click="toggle(item.id)"
      >
        <img
          v-if="item.image_url"
          class="legende-thumb"
          :src="cardThumb(item.image_url, 96)"
          alt=""
          width="32"
          height="32"
          loading="lazy"
        />
        <span v-else class="legende-thumb" aria-hidden="true"></span>
        <span class="legende-name">{{ item.name }}</span>
        <span class="legende-count">{{ item.deck_count }}</span>
        <span class="legende-check" aria-hidden="true">{{ modelValue.includes(item.id) ? "✓" : "" }}</span>
      </li>
      <li v-if="!shown.length" class="legende-empty" role="presentation">Aucune légende ne correspond</li>
    </ul>

    <div v-if="selectedLegends.length" class="legende-chosen">
      <RiftChip v-for="item in selectedLegends" :key="item.id" :label="item.name" removable @remove="toggle(item.id)" />
    </div>
  </div>
</template>

<style scoped>
.legende-picker {
  display: grid;
  gap: var(--space-2);
  min-width: 0;
}
.legende-list {
  list-style: none;
  margin: 0;
  padding: 0;
  max-height: 280px;
  overflow-y: auto;
  background: var(--bg-raised);
  border: 1px solid var(--line);
}
.legende-option {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 44px;
  margin: 0;
  padding: 0 var(--space-3);
  border-left: 2px solid transparent;
  color: var(--ink);
  cursor: pointer;
  transition: background var(--t-fast);
}
.legende-option:hover,
.legende-option.active {
  background: var(--bg-sunken);
}
.legende-option.active {
  border-left-color: var(--blood);
}
.legende-thumb {
  flex: none;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  object-fit: cover;
  object-position: center 20%;
  background: var(--bg-sunken);
}
.legende-name {
  flex: 1;
  min-width: 0;
  overflow-wrap: anywhere;
}
.legende-count {
  flex: none;
  font-size: 13px;
  color: var(--ink-muted);
}
.legende-check {
  flex: none;
  width: 1em;
  color: var(--bronze-light);
}
.legende-empty {
  margin: 0;
  padding: var(--space-3);
  color: var(--ink-muted);
  font-size: 14px;
}
.legende-chosen {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}
@media (prefers-reduced-motion: reduce) {
  .legende-option {
    transition: none;
  }
}
</style>
