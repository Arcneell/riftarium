<script setup>
import { cardThumb, DOMAINS, TYPES, RARITIES } from "../api.js";

defineProps({ card: { type: Object, required: true } });
</script>

<template>
  <RouterLink v-tilt class="card-tile" :class="{ landscape: card.orientation === 'landscape' }" :to="`/cartes/${card.id}`">
    <img :src="cardThumb(card.image_url, 320)" :alt="`Carte Riftbound : ${card.name}`"
         loading="lazy" decoding="async" width="200" height="279" />
    <div class="t-name">{{ card.name }}</div>
    <div class="t-meta">
      <span>{{ card.riftbound_id.toUpperCase() }}</span>
      <span :style="{ color: DOMAINS[card.domains?.[0]]?.color }">
        {{ card.domains?.map(d => DOMAINS[d]?.label || d).join(" / ") }}
      </span>
    </div>
    <div class="t-meta">
      <span>{{ TYPES[card.type] || card.type }} · {{ RARITIES[card.rarity] || card.rarity }}</span>
    </div>
  </RouterLink>
</template>
