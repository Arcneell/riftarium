<script setup>
import { computed } from "vue"
import { cardThumb } from "../api.js"
import { DECK_ZONES, championOf, groupDeck } from "../deckDisplay.js"
import CardHoverPreview from "./CardHoverPreview.vue"

const props = defineProps({
  deck: { type: Object, required: true }
})

const grouped = computed(() => groupDeck(props.deck))
const championId = computed(() => championOf(props.deck)?.card.id || null)
const zones = computed(() =>
  DECK_ZONES.map((zone) => ({
    ...zone,
    entries: grouped.value[zone.key],
    count: grouped.value[zone.key].reduce((total, entry) => total + entry.qty, 0)
  })).filter((zone) => zone.entries.length)
)
const packs = computed(() =>
  [
    { key: "identity", zones: zones.value.filter((zone) => zone.key !== "main") },
    { key: "main", zones: zones.value.filter((zone) => zone.key === "main") }
  ].filter((pack) => pack.zones.length)
)
</script>

<template>
  <div class="dvis">
    <div v-for="pack in packs" :key="pack.key" :class="{ 'dvis-identity': pack.key === 'identity' }">
      <div v-for="zone in pack.zones" :key="zone.key" class="dvis-zone">
        <h4>
          {{ zone.label }}
          <small>{{ zone.count }}</small>
        </h4>
        <div class="dvis-grid" :class="zone.key.toLowerCase()">
          <div
            v-for="entry in zone.entries"
            :key="entry.card.id"
            class="dvis-cell"
            :class="{ champion: entry.card.id === championId }"
          >
            <CardHoverPreview :card="entry.card">
              <!-- Vignette cliquable : l'aperçu au survol n'existe pas au doigt, la
                   fiche de la carte est le seul moyen de la lire en grand sur téléphone. -->
              <RouterLink
                class="dvis-link"
                :to="`/cartes/${entry.card.id}`"
                :aria-label="`Voir la carte ${entry.card.name}`"
              >
                <div
                  class="dvis-card"
                  :class="{ landscape: entry.card.orientation === 'landscape' || zone.key === 'Battlefield' }"
                >
                  <img
                    :src="cardThumb(entry.card.image_url, 280)"
                    :alt="entry.card.name"
                    loading="lazy"
                    decoding="async"
                  />
                  <span class="dvis-qty">×{{ entry.qty }}</span>
                </div>
              </RouterLink>
              <p class="dvis-name">{{ entry.card.name }}</p>
            </CardHoverPreview>
          </div>
        </div>
      </div>
    </div>
    <p v-if="!zones.length" class="muted">Aucune carte dans ce deck.</p>
  </div>
</template>
