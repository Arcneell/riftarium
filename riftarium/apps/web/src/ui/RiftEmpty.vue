<script setup>
/* État vide : dire pourquoi il n'y a rien, et proposer la sortie. */
defineProps({
  title: { type: String, required: true },
  text: { type: String, default: "" }
})
</script>

<template>
  <div class="rift-empty" role="status">
    <p class="rift-empty-title">{{ title }}</p>
    <p v-if="text" class="rift-empty-text">{{ text }}</p>
    <div v-if="$slots.default" class="rift-empty-actions"><slot /></div>
  </div>
</template>

<style scoped>
.rift-empty {
  display: grid;
  justify-items: center;
  gap: var(--space-2);
  padding: var(--space-7) var(--space-4);
  text-align: center;
  border: 1px dashed var(--line);
}
.rift-empty-title {
  font-family: var(--font-display);
  font-size: 20px;
  font-weight: 700;
  color: var(--ink);
}
.rift-empty-text {
  max-width: 420px;
  color: var(--ink-muted);
}
.rift-empty-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--space-2);
  margin-top: var(--space-3);
}
</style>
