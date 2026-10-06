<script setup>
import RiftStat from "../ui/RiftStat.vue"

/* Rangée de statistiques de la collection : une valeur nulle s'affiche « — ». */
defineProps({
  items: { type: Array, default: () => [] } // [{ label, value, title? }]
})
</script>

<template>
  <div class="collection-stats-row">
    <RiftStat
      v-for="item in items"
      :key="item.label"
      :label="item.label"
      :value="item.value === null || item.value === undefined ? '—' : item.value"
      :title="item.title"
    />
  </div>
</template>

<style scoped>
.collection-stats-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}
</style>
