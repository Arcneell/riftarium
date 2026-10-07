<script setup>
import { DOMAIN_RUNE, glyphUrl } from "../cardText.js"
import { DOMAINS } from "../api.js"
import { useDeckStats } from "../composables/useDeckStats.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import RiftChip from "../ui/RiftChip.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftStat from "../ui/RiftStat.vue"

const props = defineProps({
  cards: { type: Array, default: () => [] },
  checks: { type: Array, default: () => [] },
  prices: { type: Object, default: null }
})

const { curve, curveLabel, energyTotal, domainSpread } = useDeckStats(() => props.cards || [])

/* Valeur indicative du deck (deck_out.prices, null si rien de pricé). */
const deckValue = () => formatEur(props.prices?.total_eur)

/* Hauteur d'une barre : jamais NaN, même quand le deck est vide. */
const barHeight = (bucket) => (Number.isFinite(bucket.height) ? bucket.height : 0)
</script>

<template>
  <RiftPanel title="Analyse">
    <div class="analyse-stats">
      <RiftStat label="Énergie" :glyph="glyphUrl('energy_1')" glyph-kind="energy" :value="energyTotal" />
      <RiftStat v-if="deckValue()" label="Valeur" :value="deckValue()" :title="PRICE_NOTE" />
    </div>

    <div class="analyse-curve" role="group" aria-label="Répartition des coûts en énergie du deck principal">
      <div v-for="bucket in curve" :key="bucket.cost" class="analyse-bar">
        <i class="analyse-bar-fill" :style="{ height: barHeight(bucket) + '%' }"></i>
        <span class="sr-only">{{ bucket.count }} carte(s) à {{ bucket.cost }} d'énergie</span>
        <small class="analyse-bar-cost">{{ bucket.cost }}{{ bucket.cost === 7 ? "+" : "" }}</small>
      </div>
    </div>
    <!-- Doublon visuel des barres : aria-hidden, les .sr-only des barres le disent déjà. -->
    <p v-if="curveLabel" class="analyse-curve-label" aria-hidden="true">{{ curveLabel }}</p>

    <div v-if="domainSpread.length" class="analyse-domains">
      <RiftChip
        v-for="[domain, count] in domainSpread"
        :key="domain"
        class="analyse-domain"
        tabindex="-1"
        :label="`${DOMAINS[domain]?.label || domain} · ${count}`"
        :glyph="glyphUrl(`rune_${DOMAIN_RUNE[domain] || 'rainbow'}`)"
        glyph-kind="rune"
        :color="DOMAINS[domain]?.color"
      />
    </div>

    <ul v-if="checks?.length" class="analyse-checks">
      <li v-for="item in checks" :key="item.rule" :class="item.ok ? 'ok' : 'ko'">
        <span class="analyse-check-mark" aria-hidden="true">{{ item.ok ? "✓" : "✕" }}</span>
        <span>{{ item.message }}</span>
      </li>
    </ul>

    <slot name="actions" />
  </RiftPanel>
</template>

<style scoped>
.analyse-stats {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-bottom: var(--space-4);
}
.analyse-curve {
  display: flex;
  align-items: flex-end;
  gap: var(--space-2);
  height: 96px;
}
.analyse-bar {
  position: relative;
  display: flex;
  flex: 1;
  flex-direction: column;
  justify-content: flex-end;
  align-items: center;
  height: 100%;
  min-width: 0;
}
.analyse-bar-fill {
  display: block;
  width: 100%;
  min-height: 0;
  background: linear-gradient(180deg, var(--blood), var(--bronze));
  transition: height var(--t-fast);
}
.analyse-bar-cost {
  margin-top: var(--space-1);
  font-family: var(--font-label);
  font-size: 12px;
  color: var(--ink-muted);
}
.analyse-curve-label {
  margin: var(--space-2) 0 0;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.04em;
  color: var(--ink-muted);
}
.analyse-domains {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-top: var(--space-4);
}
/* Simple affichage : la puce n'est pas une bascule ici. */
.analyse-domain {
  pointer-events: none;
}
.analyse-checks {
  display: grid;
  gap: var(--space-2);
  margin: var(--space-4) 0 0;
  padding: 0;
  list-style: none;
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 1.35;
  color: var(--ink);
}
.analyse-checks li {
  display: flex;
  gap: var(--space-2);
}
.analyse-check-mark {
  flex: none;
  font-weight: 700;
}
.analyse-checks .ok .analyse-check-mark {
  color: var(--bronze-light);
}
.analyse-checks .ko .analyse-check-mark {
  color: var(--blood-text);
}
@media (prefers-reduced-motion: reduce) {
  .analyse-bar-fill {
    transition: none;
  }
}
</style>
