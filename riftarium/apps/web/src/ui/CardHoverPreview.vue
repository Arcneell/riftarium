<script>
/* Portée module : une grille monte des centaines de tuiles, et ces deux
   préférences ne changent pas d'une tuile à l'autre — inutile d'interroger
   matchMedia à chaque instance. */
const hasMatchMedia = typeof window !== "undefined" && Boolean(window.matchMedia)
const REDUCED_MOTION = hasMatchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches
const FINE_POINTER = hasMatchMedia && window.matchMedia("(hover: hover) and (pointer: fine)").matches
</script>

<script setup>
import { computed, onUnmounted, ref } from "vue"
import { cardThumb } from "../api.js"
import { isFoil, variantLabel } from "../cardText.js"
import RiftText from "./RiftText.vue"

/* Aperçu agrandi d'une carte au survol (ou au focus) de son contenu : une infobulle
   fixe sur le côté de l'écran, au pointeur fin seulement. Au doigt, la fiche de la
   carte reste le moyen de la lire en grand. */
const props = defineProps({
  card: { type: Object, required: true },
  disabled: { type: Boolean, default: false }
})

const HOVER_DELAY = 450

const visible = ref(false)
/* Les constantes du bloc <script> ne sont pas exposées au template : on les
   reprend ici pour la classe « apercu-instant ». */
const instant = REDUCED_MOTION
let timer = 0

function show() {
  if (props.disabled || !FINE_POINTER) return
  clearTimeout(timer)
  timer = window.setTimeout(
    () => {
      visible.value = true
    },
    REDUCED_MOTION ? 0 : HOVER_DELAY
  )
}

function hide() {
  clearTimeout(timer)
  visible.value = false
}

onUnmounted(() => clearTimeout(timer))

const foil = computed(() => isFoil(props.card))
const landscape = computed(() => props.card.orientation === "landscape")
</script>

<template>
  <div
    class="apercu-hote"
    :class="{ 'apercu-paysage': landscape }"
    @mouseenter="show"
    @mouseleave="hide"
    @focusin="show"
    @focusout="hide"
  >
    <slot />
    <Teleport to="body">
      <div
        v-if="visible"
        class="apercu-bulle"
        :class="{ 'apercu-instant': instant, 'apercu-paysage': landscape }"
        role="tooltip"
      >
        <div class="apercu-illus">
          <img :src="cardThumb(card.image_url, 460)" :alt="`Aperçu : ${card.name}`" />
          <span v-if="foil" class="apercu-foil" aria-hidden="true"></span>
        </div>
        <div class="apercu-copie">
          <p class="apercu-variante">{{ variantLabel(card) }}</p>
          <p class="apercu-nom">{{ card.name }}</p>
          <RiftText v-if="card.text" tag="p" class="apercu-texte" :text="card.text" />
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
/* Hôte : une cellule de grille comme une autre ; un terrain (paysage) en occupe deux. */
.apercu-hote {
  min-width: 0;
}
.apercu-hote.apercu-paysage {
  grid-column: span 2;
}

.apercu-bulle {
  position: fixed;
  z-index: var(--z-overlay);
  right: 4vw;
  top: 50%;
  transform: translateY(-50%);
  width: min(360px, 86vw);
  padding: var(--space-4);
  background: var(--bg-raised);
  border-top: 2px solid var(--bronze);
  box-shadow:
    inset 0 0 0 1px var(--line),
    var(--shadow-deep);
  pointer-events: none;
  animation: apercu-entree var(--t-base) ease-out;
}
.apercu-bulle.apercu-paysage {
  width: min(520px, 92vw);
}
.apercu-bulle.apercu-instant {
  animation: none;
}

.apercu-illus {
  position: relative;
  overflow: hidden;
  border-radius: var(--radius-card);
}
.apercu-illus img {
  width: 100%;
  height: auto;
  aspect-ratio: 744 / 1039;
  object-fit: contain;
}
.apercu-paysage .apercu-illus img {
  aspect-ratio: 1038 / 744;
}
/* Reflet foil des cartes rares et showcase : un seul passage à l'ouverture. */
.apercu-foil {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: linear-gradient(115deg, transparent 30%, rgba(255, 236, 200, 0.35) 48%, transparent 66%);
  background-size: 250% 100%;
  background-position: -60% 0;
  mix-blend-mode: screen;
  animation: apercu-reflet 900ms ease 1;
}

.apercu-copie {
  display: grid;
  gap: var(--space-1);
  margin-top: var(--space-3);
}
.apercu-variante {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.apercu-nom {
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.2;
  color: var(--ink);
}
.apercu-texte {
  font-size: 14px;
  line-height: 1.6;
  color: var(--ink);
}

@keyframes apercu-entree {
  from {
    opacity: 0;
    transform: translateY(-50%) scale(0.96);
  }
  to {
    opacity: 1;
    transform: translateY(-50%) scale(1);
  }
}
@keyframes apercu-reflet {
  from {
    background-position: 120% 0;
  }
  to {
    background-position: -60% 0;
  }
}

/* Aperçu réservé aux grands écrans : en dessous, il masquerait la grille. */
@media (max-width: 980px) {
  .apercu-bulle {
    display: none;
  }
}
/* Mouvement réduit : ni entrée animée ni reflet. */
@media (prefers-reduced-motion: reduce) {
  .apercu-bulle {
    animation: none;
  }
  .apercu-foil {
    display: none;
  }
}
</style>
