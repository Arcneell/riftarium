<script setup>
import { computed } from "vue"
import { cardThumb, DOMAINS } from "../api.js"
import { isFoil, variantLabel } from "../cardText.js"
import CardHoverPreview from "./CardHoverPreview.vue"
import { formatEur, PRICE_NOTE } from "../prices.js"

/* Vignette Forgée : l'illustration d'abord, le reflet foil au survol des cartes
   rares, un filet de la couleur du domaine, le nom et le prix dessous. */
const props = defineProps({
  card: { type: Object, required: true },
  preview: { type: Boolean, default: true }
})
const foil = computed(() => isFoil(props.card))
const badge = computed(() => {
  const label = variantLabel(props.card)
  return label === "Normale" ? "" : label
})
const price = computed(() => formatEur(props.card.price_eur))
const style = computed(() => ({ "--tile-accent": DOMAINS[props.card.domains?.[0]]?.color || "var(--bronze)" }))
</script>

<template>
  <CardHoverPreview :card="card" :disabled="!preview">
    <RouterLink
      :to="`/cartes/${card.id}`"
      class="rift-tile"
      :class="{ landscape: card.orientation === 'landscape' }"
      :style="style"
    >
      <span class="tile-art">
        <img :src="cardThumb(card.image_url, 320)" alt="" loading="lazy" decoding="async" />
        <span v-if="foil" class="tile-foil" aria-hidden="true"></span>
        <span v-if="badge" class="tile-badge">{{ badge }}</span>
        <span v-if="card.owned_qty && !$slots.overlay" class="tile-owned">×{{ card.owned_qty }}</span>
        <slot name="overlay"></slot>
      </span>
      <span class="tile-name">{{ card.name }}</span>
      <span class="tile-meta">
        <span>{{ (card.riftbound_id || "").toUpperCase() }}</span>
        <span v-if="price" class="tile-price" :title="PRICE_NOTE">{{ price }}</span>
      </span>
    </RouterLink>
  </CardHoverPreview>
</template>

<style scoped>
.rift-tile {
  display: grid;
  gap: var(--space-1);
  padding: var(--space-2);
  background: var(--bg-raised);
  border-top: 2px solid var(--tile-accent);
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  transition: box-shadow var(--t-fast);
}
.rift-tile:hover,
.rift-tile:focus-visible {
  color: var(--ink);
  box-shadow: inset 0 0 0 1px var(--bronze);
}
.tile-art {
  position: relative;
  display: block;
  overflow: hidden;
  border-radius: var(--radius-card);
}
.tile-art img {
  width: 100%;
  aspect-ratio: 0.716;
  object-fit: cover;
}
.rift-tile.landscape .tile-art img {
  aspect-ratio: 1.396;
}
.tile-foil {
  position: absolute;
  inset: 0;
  background: linear-gradient(115deg, transparent 30%, rgba(255, 236, 200, 0.35) 48%, transparent 66%);
  background-size: 250% 100%;
  background-position: 120% 0;
  mix-blend-mode: screen;
  opacity: 0;
  transition:
    opacity var(--t-base),
    background-position 900ms ease;
}
.rift-tile:hover .tile-foil,
.rift-tile:focus-visible .tile-foil {
  opacity: 1;
  background-position: -60% 0;
}
.tile-badge,
.tile-owned {
  position: absolute;
  top: var(--space-1);
  padding: 1px 6px;
  background: rgba(13, 13, 15, 0.85);
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.tile-badge {
  left: var(--space-1);
  color: var(--bronze-light);
}
.tile-owned {
  right: var(--space-1);
  color: #fff;
  background: var(--blood);
}
.tile-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}
.tile-meta {
  display: flex;
  justify-content: space-between;
  gap: var(--space-2);
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.tile-price {
  color: var(--bronze-light);
}
@media (prefers-reduced-motion: reduce) {
  .tile-foil {
    display: none;
  }
}
</style>
