<script setup>
import { computed } from "vue"
import { DOMAINS } from "../api.js"
import { DOMAIN_RUNE, RUNE_LABELS, glyphUrl } from "../cardText.js"
import { DECK_ZONES, groupDeck, runesOf } from "../deckDisplay.js"
import DeckExportBar from "./DeckExportBar.vue"
import DeckVisual from "./DeckVisual.vue"

const props = defineProps({
  deck: { type: Object, required: true }
})
defineEmits(["like"])

const grouped = computed(() => groupDeck(props.deck))
const runes = computed(() => runesOf(props.deck))
const zoneCounts = computed(() => {
  const counts = {}
  for (const zone of DECK_ZONES) {
    counts[zone.key] = grouped.value[zone.key].reduce((total, entry) => total + entry.qty, 0)
  }
  return counts
})

const curve = computed(() => {
  const buckets = Array(8).fill(0)
  for (const entry of grouped.value.main) buckets[Math.min(entry.card.energy ?? 0, 7)] += entry.qty
  const max = Math.max(...buckets, 1)
  return buckets.map((count, cost) => ({ cost, count, height: (count / max) * 100 }))
})

const energyTotal = computed(() =>
  grouped.value.main.reduce((sum, entry) => sum + (entry.card.energy ?? 0) * entry.qty, 0)
)

const domainSpread = computed(() => {
  const counts = {}
  for (const entry of props.deck.cards || []) {
    for (const domain of entry.card.domains || []) {
      if (domain === "Colorless") continue
      counts[domain] = (counts[domain] || 0) + entry.qty
    }
  }
  return Object.entries(counts).sort((a, b) => b[1] - a[1])
})
</script>

<template>
  <section class="deck-view">
    <div class="wrap">
      <div class="deck-view-bar">
        <RouterLink to="/communaute" class="dbuilder-back">← Communauté</RouterLink>
        <h2 class="deck-view-title">{{ deck.name }}</h2>
        <p class="muted mono deck-view-meta">
          {{ deck.format === "tournament" ? "tournoi" : "libre" }} · par {{ deck.owner }}
        </p>
        <div class="deck-view-runes" v-if="runes.length">
          <img
            v-for="rune in runes"
            :key="rune.domain"
            :src="rune.src"
            :alt="rune.label"
            :title="rune.label"
            width="26"
            height="26"
          />
        </div>
        <div class="deck-box-stats">
          <button
            v-if="deck.is_public"
            type="button"
            class="deck-box-stat"
            :class="{ liked: deck.liked_by_me }"
            :aria-pressed="deck.liked_by_me"
            :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
            @click="$emit('like')"
          >
            <Icon name="heart" :size="14" />
            {{ deck.likes }}
          </button>
          <span class="deck-box-stat" :title="`${deck.views ?? 0} vue(s)`">
            <Icon name="eye" :size="14" />
            {{ deck.views ?? 0 }}
          </span>
        </div>
      </div>

      <div class="deck-meters">
        <div
          class="meter"
          v-for="zone in DECK_ZONES"
          :key="zone.key"
          :class="{ full: zoneCounts[zone.key] >= zone.target }"
        >
          <b
            >{{ zoneCounts[zone.key] }}<small>/{{ zone.target }}{{ zone.key === "main" ? "+" : "" }}</small></b
          >
          <span>{{ zone.label }}</span>
        </div>
      </div>

      <div class="deck-view-layout">
        <div class="deck-view-board">
          <DeckVisual :deck="deck" />
        </div>
        <aside class="deck-view-side">
          <p class="overview-energy">
            <b>{{ energyTotal }}</b> énergie
          </p>
          <div class="curve" role="img" aria-label="Répartition des coûts en énergie du deck principal">
            <div class="bar" v-for="bucket in curve" :key="bucket.cost">
              <i :style="{ height: bucket.height + '%' }" :title="`${bucket.count} carte(s) à ${bucket.cost}`"></i>
              <small>{{ bucket.cost }}{{ bucket.cost === 7 ? "+" : "" }}</small>
            </div>
          </div>
          <div class="deck-domains" v-if="domainSpread.length">
            <span class="chip chip-rune" v-for="[domain, count] in domainSpread" :key="domain">
              <img
                class="rb-glyph rune"
                :src="glyphUrl(`rune_${DOMAIN_RUNE[domain] || 'rainbow'}`)"
                :alt="RUNE_LABELS[DOMAIN_RUNE[domain]] || domain"
                width="18"
                height="18"
              />
              {{ DOMAINS[domain]?.label || domain }} · {{ count }}
            </span>
          </div>
          <ul class="validator" v-if="deck.checks?.length">
            <li v-for="checkItem in deck.checks" :key="checkItem.rule" :class="checkItem.ok ? 'v-ok' : 'v-ko'">
              {{ checkItem.message }}
            </li>
          </ul>
          <p v-if="deck.description" class="deck-read-desc">{{ deck.description }}</p>
          <DeckExportBar :deck="deck" />
        </aside>
      </div>
    </div>
  </section>
</template>
