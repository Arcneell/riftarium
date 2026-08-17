<script setup>
import { nextTick, onMounted, onUnmounted, ref } from "vue";
import { api, cardThumb } from "../api.js";

/* Deux rangées qui défilent en sens opposés. Pause hors écran, copies stables. */
const rows = ref([[], []]);
const root = ref(null);
const paused = ref(false);
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
let observer;

onMounted(async () => {
  try {
    const [a, b] = await Promise.all([
      api("/api/cards?set_id=OGN&size=10&page=2"),
      api("/api/cards?set_id=SFD&size=10&page=3")
    ]);
    rows.value = [a.items, b.items];
  } catch { /* la rivière reste vide, la page vit sans */ }

  if (reducedMotion) return;
  await nextTick();
  if (!root.value) return;
  observer = new IntersectionObserver(([entry]) => {
    paused.value = !entry.isIntersecting;
  }, { threshold: 0.08 });
  observer.observe(root.value);
});

onUnmounted(() => observer?.disconnect());
</script>

<template>
  <div class="river" ref="root" v-if="rows[0].length" :class="{ paused: paused || reducedMotion }">
    <div class="river-row" v-for="(row, i) in rows" :key="i" :class="{ reverse: i === 1 }">
      <div class="river-track">
        <template v-for="copy in 2" :key="copy">
          <RouterLink v-for="card in row" :key="`${copy}-${card.id}`"
                      class="river-card" :class="{ landscape: card.orientation === 'landscape' }"
                      :to="`/cartes/${card.id}`"
                      :tabindex="copy === 1 ? undefined : -1"
                      :aria-hidden="copy === 2 ? true : undefined"
                      :aria-label="copy === 1 ? `Voir la carte ${card.name}` : undefined">
            <img :src="cardThumb(card.image_url, 180)"
                 :alt="copy === 1 ? `Carte Riftbound : ${card.name}` : ''"
                 width="150" height="209" loading="lazy" decoding="async" />
          </RouterLink>
        </template>
      </div>
    </div>
  </div>
</template>
