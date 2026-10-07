<script setup>
import { computed } from "vue"
import { cardThumb } from "../api.js"
import { DECK_ZONES, championOf, groupDeck } from "../deckDisplay.js"
import CardHoverPreview from "../components/CardHoverPreview.vue"

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
  <div class="lecture-visual">
    <div v-for="pack in packs" :key="pack.key" :class="{ 'lecture-zone-identity': pack.key === 'identity' }">
      <section v-for="zone in pack.zones" :key="zone.key" class="lecture-zone">
        <h2 class="decklist-zone-title">
          {{ zone.label }}
          <small>{{ zone.count }}</small>
        </h2>
        <div class="lecture-zone-grid" :class="`lecture-zone-grid--${zone.key.toLowerCase()}`">
          <div
            v-for="entry in zone.entries"
            :key="entry.card.id"
            class="lecture-card-cell"
            :class="{ 'lecture-card-cell--champion': entry.card.id === championId }"
          >
            <CardHoverPreview :card="entry.card">
              <!-- Vignette cliquable : l'aperçu au survol n'existe pas au doigt, la
                   fiche de la carte est le seul moyen de la lire en grand sur téléphone. -->
              <RouterLink
                class="lecture-card-link"
                :to="`/cartes/${entry.card.id}`"
                :aria-label="`Voir la carte ${entry.card.name}`"
              >
                <div
                  class="lecture-card"
                  :class="{
                    'lecture-card--landscape': entry.card.orientation === 'landscape' || zone.key === 'Battlefield'
                  }"
                >
                  <img
                    :src="cardThumb(entry.card.image_url, 280)"
                    :alt="entry.card.name"
                    loading="lazy"
                    decoding="async"
                  />
                  <span class="lecture-card-qty">×{{ entry.qty }}</span>
                </div>
              </RouterLink>
              <p class="lecture-card-name">{{ entry.card.name }}</p>
              <p v-if="entry.card.id === championId" class="lecture-card-champion">Champion</p>
            </CardHoverPreview>
          </div>
        </div>
      </section>
    </div>
    <p v-if="!zones.length" class="lecture-visual-empty">Aucune carte dans ce deck.</p>
  </div>
</template>

<style scoped>
.lecture-visual {
  display: grid;
  gap: var(--space-6);
  min-width: 0;
}
.lecture-zone-identity {
  display: grid;
  gap: var(--space-6);
}
/* main.css style les section : on neutralise. */
.lecture-zone {
  padding: 0;
}
/* main.css colore et dimensionne les h2 : tout est posé ici. */
.decklist-zone-title {
  display: flex;
  align-items: baseline;
  gap: var(--space-2);
  margin: 0 0 var(--space-3);
  font-family: var(--font-display);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink);
}
.decklist-zone-title small {
  font-size: 15px;
  font-weight: 600;
  color: var(--ink-muted);
}
.lecture-zone-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(110px, 1fr));
  gap: var(--space-3);
}
.lecture-zone-grid--battlefield {
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
}
.lecture-card-cell {
  min-width: 0;
}
/* Champion : filet rouge au-dessus de la vignette, étiquette dessous. */
.lecture-card-cell--champion {
  border-top: 2px solid var(--blood);
  padding-top: var(--space-1);
}
.lecture-card-link {
  display: block;
}
.lecture-card-link:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.lecture-card {
  position: relative;
  aspect-ratio: 5 / 7;
  overflow: hidden;
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
}
.lecture-card--landscape {
  aspect-ratio: 7 / 5;
}
.lecture-card img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.lecture-card-qty {
  position: absolute;
  right: var(--space-1);
  bottom: var(--space-1);
  padding: 0 var(--space-2);
  font-family: var(--font-display);
  font-size: 14px;
  font-weight: 700;
  color: var(--ink);
  background: color-mix(in srgb, var(--bg) 85%, transparent);
}
.lecture-card-name {
  margin: var(--space-1) 0 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: var(--font-body);
  font-size: 13px;
  color: var(--ink-muted);
}
.lecture-card-champion {
  margin: 0;
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.lecture-visual-empty {
  margin: 0;
  color: var(--ink-muted);
}
</style>
