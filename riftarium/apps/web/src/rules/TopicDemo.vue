<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue"

/* Mini-scène animée : une suite d'images (frames) qui bouclent.
   Chaque frame place des éléments (unités, cartes, piles, étiquettes) en % ;
   les éléments partagent leurs clés entre frames, donc ils glissent d'une
   position à l'autre — même langage visuel que le plateau animé. */
const props = defineProps({
  demo: { type: Object, required: true }
})

const frameIndex = ref(0)
/* Une démo sans image (données incomplètes) ne doit pas faire exploser le rendu
   sur `frame.items` : on retombe sur une scène vide. */
const EMPTY_FRAME = { items: [], caption: "" }
const frames = computed(() => props.demo.frames ?? [])
const frame = computed(() => frames.value[frameIndex.value] ?? EMPTY_FRAME)
let timer = null

const DELAY = 2600

/* Reduced motion : pas de défilement automatique, la navigation reste possible par les points. */
const reducedMotion = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches

/* Lecture/pause : une scène qui change toutes les 2,6 s sans commande est
   impossible à lire au doigt, on n'a pas le temps de finir la légende. */
const playing = ref(!reducedMotion)
const playLabel = computed(() => (playing.value ? "Mettre l'animation en pause" : "Lire l'animation"))

function next() {
  if (!frames.value.length) return
  frameIndex.value = (frameIndex.value + 1) % frames.value.length
}
function goTo(i) {
  frameIndex.value = i
  restart()
}
function restart() {
  clearInterval(timer)
  timer = null
  if (!playing.value) return
  timer = setInterval(next, DELAY)
}
function togglePlay() {
  playing.value = !playing.value
  restart()
}
onMounted(restart)
onBeforeUnmount(() => clearInterval(timer))
</script>

<template>
  <!-- role="img" sur la scène seule : posé sur le conteneur, il masquait aux
       lecteurs d'écran les boutons de la barre (points, lecture/pause). -->
  <div class="scene">
    <div class="scene-stage" role="img" :aria-label="demo.title">
      <TransitionGroup name="scene">
        <div
          v-for="item in frame.items"
          :key="item.k"
          class="scene-item"
          :class="[
            `scene-${item.type}`,
            {
              'scene-foe': item.side === 'foe',
              'scene-tapped': item.tapped,
              'scene-dead': item.dead,
              'scene-glow': item.glow,
              'scene-ok': item.ok,
              'scene-hot': item.hot
            }
          ]"
          :style="{ left: item.x + '%', top: item.y + '%' }"
        >
          <template v-if="item.type === 'unit'">
            <span class="scene-unit-n">{{ item.n }}</span>
          </template>
          <template v-else-if="item.type === 'chip'">{{ item.n }}</template>
          <template v-else>{{ item.label }}</template>
        </div>
      </TransitionGroup>
    </div>
    <div class="scene-bar">
      <!-- La légende change avec l'image : annoncée, sinon le changement de scène
           est muet pour qui n'en voit pas le rendu. -->
      <p class="scene-caption" aria-live="polite">{{ frame.caption }}</p>
      <div class="scene-controls">
        <button
          type="button"
          class="scene-play"
          :aria-pressed="playing"
          :aria-label="playLabel"
          :title="playLabel"
          @click="togglePlay"
        >
          {{ playing ? "❚❚" : "▶" }}
        </button>
        <button
          v-for="(_, i) in frames"
          :key="i"
          type="button"
          class="scene-dot"
          :class="{ 'scene-dot--active': i === frameIndex }"
          :aria-current="i === frameIndex ? 'true' : undefined"
          :aria-label="`Image ${i + 1}`"
          @click="goTo(i)"
        ></button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.scene {
  margin-bottom: var(--space-4);
  overflow: hidden;
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
  border-top: 2px solid var(--blood);
}
.scene-stage {
  position: relative;
  aspect-ratio: 16 / 7;
}
.scene-item {
  position: absolute;
  transform: translate(-50%, -50%);
  transition:
    left 0.9s cubic-bezier(0.22, 0.8, 0.32, 1),
    top 0.9s cubic-bezier(0.22, 0.8, 0.32, 1),
    transform 0.6s ease,
    opacity 0.5s ease;
}
/* Jetons d'unité : bronze pour les alliés, sang pour l'adversaire. */
.scene-unit {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: var(--bronze);
  border: 2px solid var(--bronze-light);
}
.scene-unit.scene-foe {
  background: var(--blood);
  border-color: var(--blood-text);
}
.scene-unit-n {
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 20px;
  font-weight: 700;
}
.scene-unit.scene-tapped {
  transform: translate(-50%, -50%) rotate(90deg);
  opacity: 0.8;
}
.scene-unit.scene-dead {
  opacity: 0;
  transform: translate(-50%, -80%) scale(0.5);
}
.scene-card {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 46px;
  height: 64px;
  padding: 3px;
  background: var(--bg-raised);
  border: 2px solid var(--bronze);
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 11px;
  line-height: 1.2;
  text-align: center;
}
.scene-card.scene-foe {
  border-color: var(--blood);
}
.scene-card.scene-tapped {
  transform: translate(-50%, -50%) rotate(90deg);
}
.scene-card.scene-dead {
  opacity: 0;
}
.scene-card.scene-glow {
  box-shadow: 0 0 0 3px var(--bronze-light);
}
.scene-zone {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  width: 26%;
  height: 52%;
  padding-bottom: 4px;
  border: 1.5px dashed var(--line);
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 11px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  pointer-events: none;
}
.scene-zone.scene-hot {
  border-color: var(--blood);
}
.scene-chip {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 26px;
  height: 26px;
  padding: 0 7px;
  border-radius: 13px;
  background: var(--blood);
  color: #fff;
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 700;
  animation: scene-pop 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.scene-chip.scene-ok {
  background: var(--bronze);
}
.scene-label {
  padding: 3px 10px;
  border: 1px solid var(--bronze);
  background: var(--bg-raised);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  white-space: nowrap;
}
.scene-label.scene-glow {
  background: var(--bronze);
  color: var(--bg);
}
.scene-enter-from,
.scene-leave-to {
  opacity: 0;
}
.scene-leave-active {
  transition: opacity 0.4s ease;
}
@keyframes scene-pop {
  from {
    transform: scale(0.4);
    opacity: 0;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
}
.scene-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-3);
  border-top: 1px solid var(--line);
  background: var(--bg-raised);
}
.scene-caption {
  margin: 0;
  color: var(--ink);
  font-size: 14px;
  line-height: 1.4;
}
.scene-controls {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  gap: var(--space-1);
}
/* Lecture / pause : une animation qui tourne en boucle doit pouvoir s'arrêter. */
.scene-play {
  min-width: 44px;
  height: 44px;
  background: transparent;
  border: 1px solid var(--bronze);
  color: var(--bronze-light);
  font-size: 12px;
  line-height: 1;
  cursor: pointer;
  transition: border-color var(--t-fast);
}
.scene-play:hover {
  border-color: var(--bronze-light);
}
/* Cible de 44 px, losange dessiné par ::before (comme le plateau animé). */
.scene-dot {
  position: relative;
  width: 24px;
  height: 44px;
  padding: 0;
  background: none;
  border: 0;
  cursor: pointer;
}
.scene-dot::before {
  content: "";
  position: absolute;
  top: 50%;
  left: 50%;
  width: 9px;
  height: 9px;
  margin: -4.5px 0 0 -4.5px;
  border: 1.5px solid var(--line);
  rotate: 45deg;
  transition:
    background var(--t-base),
    border-color var(--t-base);
}
.scene-dot--active::before {
  background: var(--blood);
  border-color: var(--blood-text);
}
.scene-dot:hover::before {
  border-color: var(--bronze-light);
}
.scene-play:focus-visible,
.scene-dot:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
@media (max-width: 560px) {
  .scene-bar {
    flex-direction: column;
    align-items: stretch;
  }
  .scene-controls {
    justify-content: center;
  }
}
@media (prefers-reduced-motion: reduce) {
  .scene-item {
    transition: none;
  }
  .scene-chip {
    animation: none;
  }
}
</style>
