<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue"

/* Mini-scène animée : une suite d'images (frames) qui bouclent.
   Chaque frame place des éléments (unités, cartes, piles, étiquettes) en % ;
   les éléments partagent leurs clés entre frames, donc ils glissent d'une
   position à l'autre — même langage visuel que le guide de prise en main. */
const props = defineProps({
  demo: { type: Object, required: true }
})

const frameIndex = ref(0)
const frame = computed(() => props.demo.frames[frameIndex.value])
let timer = null

const DELAY = 2600

/* Reduced motion : pas de défilement automatique, la navigation reste possible par les points. */
const reducedMotion = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches

/* Lecture/pause : une scène qui change toutes les 2,6 s sans commande est
   impossible à lire au doigt, on n'a pas le temps de finir la légende. */
const playing = ref(!reducedMotion)
const playLabel = computed(() => (playing.value ? "Mettre l'animation en pause" : "Lire l'animation"))

function next() {
  frameIndex.value = (frameIndex.value + 1) % props.demo.frames.length
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
  <div class="demo">
    <div class="demo-stage" role="img" :aria-label="demo.title">
      <TransitionGroup name="demo">
        <div
          v-for="item in frame.items"
          :key="item.k"
          class="demo-item"
          :class="[item.type, item.side, { tapped: item.tapped, dead: item.dead, glow: item.glow }]"
          :style="{ left: item.x + '%', top: item.y + '%' }"
        >
          <template v-if="item.type === 'unit'">
            <span class="demo-unit-n">{{ item.n }}</span>
          </template>
          <template v-else-if="item.type === 'chip'">{{ item.n }}</template>
          <template v-else>{{ item.label }}</template>
        </div>
      </TransitionGroup>
    </div>
    <div class="demo-bar">
      <p class="demo-caption">{{ frame.caption }}</p>
      <div class="demo-dots">
        <button
          type="button"
          class="demo-play"
          :aria-pressed="playing"
          :aria-label="playLabel"
          :title="playLabel"
          @click="togglePlay"
        >
          {{ playing ? "❚❚" : "▶" }}
        </button>
        <button
          v-for="(f, i) in demo.frames"
          :key="i"
          class="demo-dot"
          :class="{ active: i === frameIndex }"
          :aria-label="`Image ${i + 1}`"
          @click="goTo(i)"
        ></button>
      </div>
    </div>
  </div>
</template>
