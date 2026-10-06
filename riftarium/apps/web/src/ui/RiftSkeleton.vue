<script setup>
/* Squelette de chargement : réserve la place du contenu à venir, sans texte lu. */
defineProps({
  lines: { type: Number, default: 3 },
  block: { type: Boolean, default: false }
})
</script>

<template>
  <div class="rift-skeleton" aria-hidden="true">
    <div v-if="block" class="rift-skeleton-block"></div>
    <template v-else>
      <div v-for="n in lines" :key="n" class="rift-skeleton-line" :class="{ last: n === lines }"></div>
    </template>
  </div>
</template>

<style scoped>
.rift-skeleton {
  display: grid;
  gap: var(--space-2);
}
.rift-skeleton-line,
.rift-skeleton-block {
  background: linear-gradient(
    90deg,
    var(--bg-sunken) 0%,
    color-mix(in srgb, var(--bg-raised), var(--bronze) 12%) 50%,
    var(--bg-sunken) 100%
  );
  background-size: 200% 100%;
  animation: rift-shimmer 1.4s linear infinite;
}
.rift-skeleton-line {
  height: 12px;
}
.rift-skeleton-line.last {
  width: 60%;
}
.rift-skeleton-block {
  height: 120px;
}
@keyframes rift-shimmer {
  to {
    background-position: -200% 0;
  }
}
</style>
