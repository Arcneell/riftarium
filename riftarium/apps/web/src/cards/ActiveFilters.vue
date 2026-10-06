<script setup>
import { computed } from "vue"
import { DOMAINS, RARITIES, TYPES } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"

/* Filtres actifs au-dessus de la grille : on voit d'un coup d'œil pourquoi la liste
   est réduite, et on retire un filtre d'un clic. */
const props = defineProps({
  state: { type: Object, required: true },
  sets: { type: Array, default: () => [] }
})
const emit = defineEmits(["update", "reset"])

const ORDER = ["domain", "type", "rarity", "energy", "set_id"]

function labelOf(key, value) {
  if (key === "domain") return DOMAINS[value]?.label || value
  if (key === "type") return TYPES[value] || value
  if (key === "rarity") return RARITIES[value] || value
  if (key === "energy") return `Coût ${value === "7+" ? "7 et plus" : value}`
  return props.sets.find((set) => set.value === value)?.label || value
}

const chips = computed(() => {
  const list = []
  if (props.state.q?.trim()) list.push({ key: "q", value: props.state.q, label: `« ${props.state.q.trim()} »` })
  for (const key of ORDER) {
    for (const value of props.state[key] ?? []) list.push({ key, value, label: labelOf(key, value) })
  }
  return list
})

function remove(chip) {
  if (chip.key === "q") emit("update", "q", "")
  else
    emit(
      "update",
      chip.key,
      props.state[chip.key].filter((value) => value !== chip.value)
    )
}
</script>

<template>
  <div v-if="chips.length" class="active-filters" role="group" aria-label="Filtres actifs">
    <RiftChip
      v-for="chip in chips"
      :key="`${chip.key}:${chip.value}`"
      removable
      :label="chip.label"
      :color="chip.key === 'domain' ? DOMAINS[chip.value]?.color : ''"
      @remove="remove(chip)"
    />
    <RiftButton v-if="chips.length > 1" variant="ghost" size="sm" @click="emit('reset')">Tout effacer</RiftButton>
  </div>
</template>

<style scoped>
.active-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}
</style>
