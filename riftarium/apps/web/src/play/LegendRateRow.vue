<script setup>
import { cardThumb } from "../api.js"
import { formatWinRate, winRatePercent } from "../play.js"

/* Une ligne « légende » des statistiques de duel : vignette, nom, bilan V / D et
   jauge de taux de victoire. Partagée par les statistiques et le profil public. */
const LEGEND_FALLBACK = "Légende supprimée"

defineProps({
  row: { type: Object, required: true },
  altPrefix: { type: String, default: "Légende" }
})

/* Le taux se déduit de J / G quand le contrat ne le chiffre pas. */
const rateOf = (row) => (row.played ? row.won / row.played : null)
</script>

<template>
  <li class="duel-legende">
    <img
      v-if="row.image_url"
      class="duel-legende-vignette"
      :src="cardThumb(row.image_url, 72)"
      :alt="`${altPrefix} : ${row.name || LEGEND_FALLBACK}`"
      width="36"
      height="36"
      loading="lazy"
      decoding="async"
    />
    <span v-else class="duel-legende-vignette" aria-hidden="true"></span>
    <span class="duel-legende-nom" :class="{ 'duel-legende-nom--absent': !row.name }">
      {{ row.name || LEGEND_FALLBACK }}
    </span>
    <span class="duel-legende-bilan">{{ row.won }} V / {{ row.lost }} D</span>
    <span class="duel-legende-taux">
      <span class="duel-legende-jauge" aria-hidden="true">
        <span class="duel-legende-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
      </span>
      <span class="duel-legende-valeur">{{ formatWinRate(rateOf(row)) }}</span>
    </span>
  </li>
</template>

<style scoped>
.duel-legende {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr) minmax(120px, 40%);
  grid-template-areas:
    "thumb nom taux"
    "thumb bilan taux";
  align-items: center;
  column-gap: var(--space-3);
}
.duel-legende-vignette {
  grid-area: thumb;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  object-fit: cover;
  background: var(--bg-sunken);
}
.duel-legende-nom {
  grid-area: nom;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--ink);
}
.duel-legende-nom--absent {
  color: var(--ink-muted);
}
.duel-legende-bilan {
  grid-area: bilan;
  font-size: 13px;
  color: var(--ink-muted);
}
.duel-legende-taux {
  grid-area: taux;
  display: flex;
  align-items: center;
  gap: var(--space-2);
}
.duel-legende-jauge {
  flex: 1 1 auto;
  min-width: 56px;
  height: 8px;
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
}
.duel-legende-fill {
  display: block;
  height: 100%;
  background: var(--bronze-light);
}
.duel-legende-valeur {
  flex: none;
  min-width: 3.5em;
  text-align: right;
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}
@media (max-width: 559px) {
  .duel-legende {
    grid-template-columns: 36px minmax(0, 1fr);
    grid-template-areas:
      "thumb nom"
      "thumb bilan"
      "taux taux";
    row-gap: var(--space-1);
  }
}
</style>
