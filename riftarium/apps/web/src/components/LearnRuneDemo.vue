<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from "vue"
import { cardThumb } from "../api.js"
import { CARDS } from "../rules/guide.js"

/* Deux runes, le matériel exact du premier tour du guide : 2 énergie (Rearguard)
   plus 1 essence Fureur (Seal of Rage). Prêt → épuisé → recyclé. */
const RUNES = [
  { id: "fury", domain: "Fureur", color: "var(--fury)", img: cardThumb(CARDS.furyRune.img, 200) },
  { id: "chaos", domain: "Chaos", color: "var(--chaos)", img: cardThumb(CARDS.chaosRune.img, 200) }
]

const NEED = { energy: 2, fury: 1 }
const rearguardImg = cardThumb(CARDS.rearguard.img, 200)
const gearImg = cardThumb(CARDS.gear.img, 200)

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

const zoomCard = ref(null)
const zoomEl = ref(null)
const zoomUrl = (card) => cardThumb(card.img, 1024)

function onZoomKey(event) {
  if (event.key === "Escape") zoomCard.value = null
}

watch(zoomCard, async (card) => {
  if (typeof document === "undefined") return
  if (card) {
    document.body.classList.add("nav-locked")
    document.addEventListener("keydown", onZoomKey)
    await nextTick()
    zoomEl.value?.focus()
  } else {
    document.body.classList.remove("nav-locked")
    document.removeEventListener("keydown", onZoomKey)
  }
})

onBeforeUnmount(() => {
  if (typeof document === "undefined") return
  document.removeEventListener("keydown", onZoomKey)
  document.body.classList.remove("nav-locked")
})

const label = (state) => ({ ready: "Préparée", exhausted: "Épuisée", recycled: "Recyclée" })[state]
</script>

<template>
  <div class="learn-runes">
    <div class="learn-runes-cards">
      <button
        type="button"
        class="learn-runes-card"
        :aria-label="`${CARDS.rearguard.name}. Double-cliquer pour agrandir.`"
        @dblclick="zoomCard = CARDS.rearguard"
      >
        <img :src="rearguardImg" :alt="CARDS.rearguard.name" loading="lazy" decoding="async" />
        <span class="mono">2 énergie</span>
      </button>
      <button
        type="button"
        class="learn-runes-card"
        :aria-label="`${CARDS.gear.name}. Double-cliquer pour agrandir.`"
        @dblclick="zoomCard = CARDS.gear"
      >
        <img :src="gearImg" :alt="CARDS.gear.name" loading="lazy" decoding="async" />
        <span class="mono">1 essence Fureur</span>
      </button>
    </div>
    <p class="muted learn-type-hint">Double-cliquez une carte pour l'agrandir.</p>

    <div class="learn-runes-gauges" aria-live="polite">
      <p>
        Énergie <b>{{ energy }} / {{ NEED.energy }}</b>
      </p>
      <p>
        Essence Fureur <b>{{ furyEssence }} / {{ NEED.fury }}</b>
      </p>
    </div>

    <div class="learn-runes-row">
      <button
        v-for="rune in RUNES"
        :key="rune.id"
        type="button"
        class="learn-rune"
        :class="states[rune.id]"
        :style="{ '--rune': rune.color }"
        :disabled="states[rune.id] === 'recycled'"
        :aria-label="`${rune.domain} : ${label(states[rune.id])}`"
        @click="cycle(rune.id)"
      >
        <img :src="rune.img" :alt="rune.domain" loading="lazy" decoding="async" />
        <span class="mono">{{ label(states[rune.id]) }}</span>
      </button>
    </div>

    <p v-if="paid" class="learn-runes-ok">Les deux cartes sont payées. Vous pourriez les jouer ce tour-ci.</p>
    <p v-else class="muted" style="font-size: 0.86rem">
      Épuisez les deux runes, puis recyclez celle de Fureur — dans cet ordre.
    </p>
    <button class="btn btn-ghost btn-sm" type="button" @click="reset">Réinitialiser</button>

    <Teleport to="body">
      <div
        v-if="zoomCard"
        ref="zoomEl"
        class="tb-zoom topic-zoom"
        role="dialog"
        aria-modal="true"
        aria-label="Carte en grand"
        tabindex="-1"
        @click="zoomCard = null"
      >
        <img :src="zoomUrl(zoomCard)" :alt="zoomCard.name" />
        <p class="mono">{{ zoomCard.name }} — clic ou Échap pour fermer</p>
      </div>
    </Teleport>
  </div>
</template>
