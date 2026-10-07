<script setup>
import { computed, ref } from "vue"
import { cardThumb } from "../api.js"
import { CARDS } from "./guide.js"
import CardZoom from "./CardZoom.vue"
import RiftButton from "../ui/RiftButton.vue"

/* Deux runes, le matériel exact du premier tour du guide : 2 énergie (Rearguard)
   plus 1 essence Fureur (Seal of Rage). Prêt → épuisé → recyclé. */
const RUNES = [
  { id: "fury", domain: "Fureur", color: "var(--fury)", img: cardThumb(CARDS.furyRune.img, 200) },
  { id: "chaos", domain: "Chaos", color: "var(--chaos)", img: cardThumb(CARDS.chaosRune.img, 200) }
]

const NEED = { energy: 2, fury: 1 }
const CARD_BUTTONS = [
  { card: CARDS.rearguard, img: cardThumb(CARDS.rearguard.img, 200), cost: "2 énergie" },
  { card: CARDS.gear, img: cardThumb(CARDS.gear.img, 200), cost: "1 essence Fureur" }
]

const states = ref({ fury: "ready", chaos: "ready" })

function cycle(id) {
  const current = states.value[id]
  if (current === "recycled") return
  states.value = {
    ...states.value,
    [id]: current === "ready" ? "exhausted" : "recycled"
  }
}

function reset() {
  states.value = { fury: "ready", chaos: "ready" }
}

const energy = computed(
  () => Object.values(states.value).filter((state) => state === "exhausted" || state === "recycled").length
)
const furyEssence = computed(() => (states.value.fury === "recycled" ? 1 : 0))
const paid = computed(() => energy.value >= NEED.energy && furyEssence.value >= NEED.fury)

/* Le zoom passe par CardZoom (RiftModal) : défilement, focus et Échap y sont gérés. */
const zoomCard = ref(null)

const label = (state) => ({ ready: "Préparée", exhausted: "Épuisée", recycled: "Recyclée" })[state]
</script>

<template>
  <div class="lecon-runes">
    <div class="lecon-runes-cards">
      <div v-for="item in CARD_BUTTONS" :key="item.card.name" class="lecon-runes-card">
        <button
          type="button"
          class="lecon-runes-zoom"
          :aria-label="`Agrandir ${item.card.name}`"
          @click="zoomCard = item.card"
        >
          <img :src="item.img" :alt="item.card.name" loading="lazy" decoding="async" />
        </button>
        <span class="lecon-runes-cost">{{ item.cost }}</span>
        <button type="button" class="lecon-runes-enlarge" @click="zoomCard = item.card">Agrandir</button>
      </div>
    </div>

    <div class="lecon-runes-gauges" aria-live="polite">
      <p>
        Énergie <b>{{ energy }} / {{ NEED.energy }}</b>
      </p>
      <p>
        Essence Fureur <b>{{ furyEssence }} / {{ NEED.fury }}</b>
      </p>
    </div>

    <div class="lecon-runes-row">
      <button
        v-for="rune in RUNES"
        :key="rune.id"
        type="button"
        class="lecon-rune"
        :class="states[rune.id]"
        :style="{ '--rune': rune.color }"
        :disabled="states[rune.id] === 'recycled'"
        :aria-label="`${rune.domain} : ${label(states[rune.id])}`"
        @click="cycle(rune.id)"
      >
        <img :src="rune.img" :alt="rune.domain" loading="lazy" decoding="async" />
        <span class="lecon-rune-state">{{ label(states[rune.id]) }}</span>
      </button>
    </div>

    <p v-if="paid" class="lecon-runes-ok">Les deux cartes sont payées. Vous pourriez les jouer ce tour-ci.</p>
    <p v-else class="lecon-runes-hint">Épuisez les deux runes, puis recyclez celle de Fureur — dans cet ordre.</p>
    <RiftButton variant="ghost" size="sm" @click="reset">Réinitialiser</RiftButton>

    <CardZoom v-if="zoomCard" :card="zoomCard" @close="zoomCard = null" />
  </div>
</template>

<style scoped>
.lecon-runes {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--space-3);
  margin: var(--space-4) 0;
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.lecon-runes-cards,
.lecon-runes-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-4);
}
.lecon-runes-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
}
.lecon-runes-zoom,
.lecon-rune {
  padding: 0;
  background: none;
  border: 0;
  cursor: pointer;
}
.lecon-runes-zoom img {
  display: block;
  width: 110px;
  border-radius: var(--radius-card);
}
.lecon-runes-cost {
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.lecon-runes-enlarge {
  min-height: 44px;
  padding: 0 var(--space-3);
  background: none;
  border: 0;
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  cursor: pointer;
  transition: color var(--t-fast);
}
.lecon-runes-enlarge:hover {
  color: var(--bronze-light);
}
.lecon-runes-gauges {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-5);
  color: var(--ink-muted);
}
.lecon-runes-gauges p {
  margin: 0;
}
.lecon-runes-gauges b {
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 18px;
}
.lecon-rune {
  --rune: var(--bronze);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  min-width: 96px;
  min-height: 44px;
  padding: var(--space-2);
  border-bottom: 3px solid var(--rune);
  transition:
    opacity var(--t-base),
    transform var(--t-base);
}
.lecon-rune img {
  width: 64px;
  height: 64px;
  object-fit: contain;
  transition: transform var(--t-base);
}
.lecon-rune.exhausted img {
  transform: rotate(90deg);
}
.lecon-rune.exhausted {
  opacity: 0.75;
}
.lecon-rune.recycled {
  opacity: 0.4;
  cursor: default;
}
.lecon-rune-state {
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.lecon-runes-zoom:focus-visible,
.lecon-runes-enlarge:focus-visible,
.lecon-rune:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.lecon-runes-ok {
  margin: 0;
  color: var(--bronze-light);
  font-weight: 600;
}
.lecon-runes-hint {
  margin: 0;
  color: var(--ink-muted);
  font-size: 15px;
}
@media (prefers-reduced-motion: reduce) {
  .lecon-rune,
  .lecon-rune img,
  .lecon-runes-enlarge {
    transition: none;
  }
}
</style>
