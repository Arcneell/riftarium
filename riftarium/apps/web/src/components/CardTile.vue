<script setup>
import { computed } from "vue"
import { cardThumb, DOMAINS, TYPES, RARITIES } from "../api.js"
import { isFoil, variantLabel } from "../cardText.js"
import CardHoverPreview from "./CardHoverPreview.vue"

const props = defineProps({ card: { type: Object, required: true } })
const foil = computed(() => isFoil(props.card))
const badge = computed(() => {
  const label = variantLabel(props.card)
  return label === "Normale" ? "" : label
})
</script>

<template>
  <CardHoverPreview :card="card">
    <RouterLink
      v-tilt
      class="card-tile"
      :class="{ landscape: card.orientation === 'landscape' }"
      :to="`/cartes/${card.id}`"
    >
      <div class="card-art" :class="{ foil }">
        <img
          :src="cardThumb(card.image_url, 320)"
          :alt="`Carte Riftbound : ${card.name}`"
          loading="lazy"
          decoding="async"
        />
        <span v-if="foil" class="card-foil"></span>
        <span v-if="card.owned_qty" class="card-qty">×{{ card.owned_qty }}</span>
        <span v-if="badge" class="card-badge">{{ badge }}</span>
      </div>
      <div class="t-name">{{ card.name }}</div>
      <div class="t-meta">
        <span>{{ card.riftbound_id.toUpperCase() }}</span>
        <span :style="{ color: DOMAINS[card.domains?.[0]]?.color }">
          {{ card.domains?.map((d) => DOMAINS[d]?.label || d).join(" / ") }}
        </span>
      </div>
      <div class="t-meta">
        <span>{{ TYPES[card.type] || card.type }} · {{ RARITIES[card.rarity] || card.rarity }}</span>
      </div>
    </RouterLink>
  </CardHoverPreview>
</template>
