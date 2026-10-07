<script setup>
import { computed, useId } from "vue"
import { cardThumb } from "../api.js"
import { glyphUrl } from "../cardText.js"

/* Plateau animé du guide : une scène de `STEPS` posée sur le tapis officiel.
   Composant d'affichage pur : le zoom d'une carte est émis (`zoom`), la page
   l'ouvre dans CardZoom. */
const props = defineProps({
  scene: { type: Object, required: true },
  spots: { type: Object, required: true },
  cards: { type: Object, required: true }
})
const emit = defineEmits(["zoom"])

/* Identifiant unique du marqueur SVG : deux plateaux ne doivent pas se le disputer. */
const headId = `${useId()}-plateau-head`
const energyGlyph = glyphUrl("energy_1")

const contested = (bf) => Boolean(props.scene.contested?.includes(bf))
const controller = (bf) => props.scene.control?.[bf]
const score = computed(() => props.scene.score ?? { you: 0, foe: 0 })

/* Flèche dans un repère 160×95 (même proportion que le plateau) : pas de déformation. */
const arrowPath = computed(() => {
  const arrow = props.scene.arrow
  if (!arrow) return null
  const from = { x: arrow.from.x * 1.6, y: arrow.from.y * 0.95 }
  const to = { x: arrow.to.x * 1.6, y: arrow.to.y * 0.95 }
  const midY = (from.y + to.y) / 2
  return `M ${from.x} ${from.y} C ${from.x} ${midY}, ${to.x} ${midY}, ${to.x} ${to.y}`
})

const zoomUrl = (card) => cardThumb(card.img, 1024)

function zoom(placed) {
  if (!placed.facedown) emit("zoom", placed.card)
}
</script>

<template>
  <!-- Sur téléphone (≤ 560 px), le plateau garde sa largeur et défile horizontalement -->
  <div class="plateau-scroller">
    <div class="plateau">
      <template v-if="!scene.bare">
        <!-- Bases (la vôtre en bas, la sienne en miroir) -->
        <div class="plateau-strip plateau-strip--foe"><span>Base adverse</span></div>
        <div class="plateau-strip plateau-strip--you"><span>Votre base</span></div>
        <div class="plateau-slot" :style="{ left: spots.discard.x + '%', top: spots.discard.y + '%' }">
          <span>Défausse</span>
        </div>
        <div class="plateau-slot" :style="{ left: spots.foeDiscard.x + '%', top: spots.foeDiscard.y + '%' }">
          <span>Sa défausse</span>
        </div>
        <div class="plateau-runezone"><span>Runes</span></div>
        <div class="plateau-handzone"><span>Votre main</span></div>

        <!-- Champs de bataille : 2 en duel, un présenté par chaque joueur -->
        <div
          v-for="bf in ['bfFoe', 'bfYou']"
          :key="bf"
          class="plateau-bf"
          :class="{
            'plateau-bf--contested': contested(bf),
            'plateau-bf--controlled': controller(bf) === 'you',
            'plateau-bf--controlled-foe': controller(bf) === 'foe'
          }"
          :style="{ left: spots[bf].x + '%', top: spots[bf].y + '%' }"
        >
          <img :src="cards[bf].img" :alt="cards[bf].name" loading="lazy" />
          <span class="plateau-bf-name">{{ bf === "bfFoe" ? "Champ adverse" : "Votre champ" }}</span>
          <span v-if="contested(bf)" class="plateau-bf-flag">Contesté</span>
          <span v-else-if="controller(bf) === 'you'" class="plateau-bf-flag plateau-bf-flag--you">À vous</span>
          <span v-else-if="controller(bf) === 'foe'" class="plateau-bf-flag plateau-bf-flag--foe">À lui</span>
        </div>

        <!-- Main adverse : dos de cartes en haut -->
        <div v-if="scene.foeHand" class="plateau-foehand" aria-label="Main adverse">
          <span v-for="i in scene.foeHand" :key="i" class="plateau-back plateau-back--small"></span>
        </div>

        <!-- Score : pistes verticales de 8 gemmes -->
        <div class="plateau-score plateau-score--you" aria-label="Vos points">
          <i>Vous</i>
          <span
            v-for="i in 8"
            :key="i"
            class="plateau-gem"
            :class="{
              'plateau-gem--filled': i <= score.you,
              'plateau-gem--pulse': scene.scorePulse && i === score.you
            }"
          ></span>
        </div>
        <div class="plateau-score plateau-score--foe" aria-label="Points adverses">
          <i>Adversaire</i>
          <span
            v-for="i in 8"
            :key="i"
            class="plateau-gem plateau-gem--foe"
            :class="{ 'plateau-gem--filled': i <= score.foe }"
          ></span>
        </div>
      </template>

      <!-- Flèche (pioche ou déplacement) -->
      <svg v-if="arrowPath" class="plateau-arrows" viewBox="0 0 160 95" aria-hidden="true">
        <defs>
          <marker :id="headId" viewBox="0 0 8 8" refX="6.4" refY="4" markerWidth="3.4" markerHeight="3.4" orient="auto">
            <path d="M 0 0 L 8 4 L 0 8 z" fill="var(--bronze-light)" />
          </marker>
        </defs>
        <path class="plateau-move plateau-move--halo" :d="arrowPath" />
        <path class="plateau-move" :d="arrowPath" :marker-end="`url(#${headId})`" />
      </svg>

      <!-- Combat en cours -->
      <span
        v-if="scene.clash"
        class="plateau-clash"
        :style="{ left: spots.bfFoe.x + '%', top: spots.bfFoe.y - 24 + '%' }"
        aria-hidden="true"
        >⚔</span
      >

      <!-- Cartes -->
      <TransitionGroup name="plateau">
        <!-- Une carte face visible s'agrandit au clic : c'est un bouton, pas un div
             cliquable (clavier, lecteurs d'écran). Les cartes face cachée ne sont
             pas interactives et restent des div. -->
        <component
          :is="placed.facedown ? 'div' : 'button'"
          v-for="placed in scene.cards"
          :key="placed.key"
          class="plateau-card"
          :type="placed.facedown ? undefined : 'button'"
          :aria-label="placed.facedown ? undefined : `Agrandir ${placed.card.name}`"
          :class="{
            'plateau-card--tapped': placed.tapped,
            'plateau-card--dead': placed.dead,
            'plateau-card--wide': placed.wide,
            'plateau-card--glow': placed.glow,
            'plateau-card--ghost': placed.ghost,
            'plateau-card--inhand': placed.hand,
            'plateau-card--clickable': !placed.facedown
          }"
          :style="{
            left: placed.spot.x + '%',
            top: placed.spot.y + '%',
            '--r': (placed.spot.r ?? 0) + 'deg'
          }"
          @click="zoom(placed)"
        >
          <span v-if="placed.facedown" class="plateau-back" :title="placed.label"></span>
          <img v-else :src="placed.card.img" :alt="placed.card.name" loading="lazy" />
          <span v-if="placed.might && placed.card.might" class="plateau-might">{{ placed.card.might }}</span>
          <span v-if="placed.dmg" class="plateau-dmg">−{{ placed.dmg }}</span>
          <span v-if="placed.label" class="plateau-slot-label">{{ placed.label }}</span>
        </component>
      </TransitionGroup>

      <!-- Gros plan annoté : lire une carte -->
      <button
        v-if="scene.focus"
        type="button"
        class="plateau-focus"
        :aria-label="`Agrandir ${scene.focus.card.name}`"
        @click="emit('zoom', scene.focus.card)"
      >
        <img :src="zoomUrl(scene.focus.card)" :alt="scene.focus.card.name" />
        <span
          v-for="note in scene.focus.notes"
          :key="note.n"
          class="plateau-focus-note"
          :style="{ left: note.x + '%', top: note.y + '%' }"
        >
          {{ note.n }}
        </span>
      </button>

      <!-- Réserve runique : énergie en glyphe Riot, essence sans domaine connu (✦) -->
      <div v-if="scene.chips" class="plateau-pool" aria-label="Réserve runique">
        <span v-for="i in scene.chips.energy" :key="'e' + i" class="plateau-chip plateau-chip--energy">
          <img class="rb-glyph energy" :src="energyGlyph" alt="1 énergie" width="16" height="16" />
        </span>
        <span
          v-for="i in scene.chips.essence"
          :key="'c' + i"
          class="plateau-chip plateau-chip--essence"
          role="img"
          aria-label="1 essence"
          >✦</span
        >
        <i>Réserve runique</i>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Repris de main.css (« Guide du débutant : table de jeu ») et rhabillé en Forge.
   Les positions restent en % : le plateau s'adapte à toute largeur. */
.plateau {
  position: relative;
  aspect-ratio: 16 / 12;
  border: 1px solid var(--line);
  border-radius: var(--radius-m);
  /* Tapis : fond creusé, filets de bronze très discrets en losanges. */
  background:
    repeating-linear-gradient(45deg, rgba(138, 110, 75, 0.06) 0 1px, transparent 1px 28px),
    repeating-linear-gradient(-45deg, rgba(138, 110, 75, 0.06) 0 1px, transparent 1px 28px),
    radial-gradient(110% 80% at 50% 115%, rgba(138, 110, 75, 0.12), transparent 60%), var(--bg-sunken);
  box-shadow:
    inset 0 0 0 1px rgba(214, 185, 140, 0.05),
    var(--shadow-deep);
  overflow: hidden;
}

/* Zones en pointillés */
.plateau-strip,
.plateau-slot,
.plateau-runezone,
.plateau-handzone {
  position: absolute;
  border: 1.5px dashed var(--line);
  pointer-events: none;
}
.plateau-strip span,
.plateau-slot span,
.plateau-runezone span,
.plateau-handzone span {
  font-family: var(--font-label);
  font-size: 0.6rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.plateau-strip {
  height: 14%;
  border-radius: var(--radius-m);
}
.plateau-strip span,
.plateau-runezone span,
.plateau-handzone span {
  position: absolute;
  left: 10px;
}
.plateau-strip--foe {
  top: 15%;
  left: 21%;
  right: 22%;
}
.plateau-strip--foe span {
  bottom: 3px;
}
.plateau-strip--you {
  top: 54%;
  left: 22%;
  right: 23%;
}
.plateau-strip--you span,
.plateau-runezone span,
.plateau-handzone span {
  top: 3px;
}
.plateau-slot {
  transform: translate(-50%, -50%);
  width: 7.5%;
  aspect-ratio: 744 / 1039;
  border-radius: 8%;
  display: flex;
  align-items: center;
  justify-content: center;
}
.plateau-slot span {
  font-size: 0.5rem;
  letter-spacing: 0.1em;
  text-align: center;
  padding: 0 3px;
}
.plateau-runezone {
  left: 14.5%;
  width: 33%;
  top: 71.5%;
  bottom: 13.5%;
  border-bottom: none;
  border-radius: var(--radius-m) var(--radius-m) 0 0;
}
.plateau-handzone {
  left: 51%;
  right: 15.5%;
  top: 85%;
  bottom: 0.5%;
  border-color: var(--bronze);
  border-bottom: none;
  border-radius: var(--radius-m) var(--radius-m) 0 0;
}
.plateau-handzone span {
  color: var(--bronze-light);
}

/* Main adverse */
.plateau-foehand {
  position: absolute;
  left: 50%;
  top: 1.5%;
  transform: translateX(-50%);
  display: flex;
}
.plateau-foehand .plateau-back--small {
  width: 26px;
  height: 37px;
  margin: 0 -5px;
  rotate: 180deg;
}

/* Champs de bataille */
.plateau-bf {
  position: absolute;
  transform: translate(-50%, -50%);
  width: 17.5%;
  border-radius: var(--radius-card);
  outline: 3px solid transparent;
  outline-offset: 3px;
  transition:
    box-shadow 0.5s ease,
    outline-color 0.5s ease;
}
.plateau-bf img {
  width: 100%;
  display: block;
  border-radius: var(--radius-card);
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.55);
}
.plateau-bf-name {
  position: absolute;
  left: 50%;
  top: 100%;
  margin-top: 5px;
  transform: translateX(-50%);
  font-family: var(--font-label);
  font-size: 0.58rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-muted);
  white-space: nowrap;
}
/* Contesté : halo de sang qui bat ; contrôlé : filet de bronze. */
.plateau-bf--contested {
  outline-color: var(--blood);
  box-shadow: 0 0 22px 4px rgba(179, 38, 43, 0.55);
  animation: plateau-alert 1.4s ease-in-out infinite;
}
.plateau-bf--controlled {
  outline-color: var(--bronze-light);
}
.plateau-bf--controlled-foe {
  outline-color: var(--bronze);
}
@keyframes plateau-alert {
  50% {
    box-shadow: 0 0 10px 1px rgba(179, 38, 43, 0.3);
  }
}
.plateau-bf-flag {
  position: absolute;
  top: -12px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 3;
  padding: 3px 10px;
  background: var(--blood);
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 0.6rem;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  white-space: nowrap;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
}
.plateau-bf-flag--you {
  background: var(--bronze-light);
  color: var(--bg);
}
.plateau-bf-flag--foe {
  background: var(--bronze);
  color: var(--bg);
}

/* Cartes */
.plateau-card {
  position: absolute;
  z-index: 2;
  padding: 0;
  width: 7.2%;
  aspect-ratio: 744 / 1039;
  transform: translate(-50%, -50%) rotate(var(--r, 0deg));
  transition:
    left 0.8s cubic-bezier(0.22, 0.8, 0.32, 1),
    top 0.8s cubic-bezier(0.22, 0.8, 0.32, 1),
    transform 0.6s cubic-bezier(0.22, 0.8, 0.32, 1),
    opacity 0.5s ease,
    filter 0.5s ease;
}
.plateau-card img {
  width: 100%;
  display: block;
  border-radius: 8%;
  box-shadow: 0 6px 14px rgba(0, 0, 0, 0.6);
}
.plateau-card--wide {
  width: 15%;
  aspect-ratio: 1038 / 744;
}
.plateau-card--inhand {
  width: 8.6%;
  z-index: 5;
}
.plateau-card--inhand:hover {
  transform: translate(-50%, -56%) rotate(var(--r, 0deg)) scale(1.5);
  z-index: 9;
}
.plateau-card--tapped {
  transform: translate(-50%, -50%) rotate(calc(var(--r, 0deg) + 90deg));
}
.plateau-card--tapped img {
  filter: saturate(0.75) brightness(0.92);
}
.plateau-card--dead {
  opacity: 0;
  filter: grayscale(1) brightness(1.1);
  transition-delay: 1s;
}
.plateau-card--ghost {
  opacity: 0.55;
}
.plateau-card--ghost img {
  box-shadow: 0 0 0 2px var(--ink-muted);
}
.plateau-card--glow img {
  box-shadow:
    0 0 0 3px var(--bronze-light),
    0 10px 24px rgba(214, 185, 140, 0.3);
}
.plateau-card--clickable {
  cursor: zoom-in;
}
.plateau-card:focus-visible,
.plateau-focus:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.plateau-enter-from {
  opacity: 0;
  transform: translate(-50%, -20%) rotate(var(--r, 0deg)) scale(0.6);
}
.plateau-leave-to {
  opacity: 0;
  transform: translate(-50%, -60%) rotate(var(--r, 0deg)) scale(0.7);
}
.plateau-leave-active {
  transition:
    opacity 0.35s ease,
    transform 0.35s ease;
}
.plateau-might {
  position: absolute;
  right: -9%;
  bottom: -7%;
  z-index: 3;
  min-width: 38%;
  aspect-ratio: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg);
  color: var(--ink);
  border: 2px solid var(--bronze-light);
  border-radius: 50%;
  font-family: var(--font-display);
  font-size: clamp(0.72rem, 1.5vw, 1.05rem);
  font-weight: 700;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
}
.plateau-dmg {
  position: absolute;
  left: -9%;
  top: -9%;
  z-index: 3;
  padding: 2px 8px;
  background: var(--blood);
  color: var(--ink);
  border: 1px solid var(--blood-text);
  font-family: var(--font-label);
  font-size: clamp(0.66rem, 1.2vw, 0.9rem);
  font-weight: 600;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
  animation: plateau-pop 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.plateau-slot-label {
  position: absolute;
  left: 50%;
  bottom: -5px;
  transform: translate(-50%, 100%);
  width: 140%;
  font-family: var(--font-label);
  font-size: 0.54rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--ink-muted);
  text-align: center;
  line-height: 1.35;
}
/* Dos de carte : plaque sombre cerclée de bronze. */
.plateau-back {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: 8%;
  background:
    radial-gradient(60% 60% at 50% 42%, rgba(179, 38, 43, 0.35), transparent 70%),
    linear-gradient(160deg, var(--bg-raised), var(--bg));
  border: 2px solid var(--bronze);
  box-shadow: 0 6px 14px rgba(0, 0, 0, 0.6);
}
.plateau-back::after {
  content: "";
  display: block;
  width: 34%;
  aspect-ratio: 1;
  margin: 46% auto 0;
  border-radius: 50%;
  border: 2px solid rgba(214, 185, 140, 0.7);
}
.plateau-back--small::after {
  margin-top: 30%;
  border-width: 1.5px;
}

/* Réserve runique */
.plateau-pool {
  position: absolute;
  left: 16%;
  top: 68%;
  z-index: 4;
  display: flex;
  align-items: center;
  gap: 6px;
}
.plateau-chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 27px;
  height: 27px;
  border-radius: 50%;
  font-family: var(--font-label);
  font-size: 0.8rem;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
  animation: plateau-pop 0.45s cubic-bezier(0.34, 1.56, 0.64, 1) backwards;
}
.plateau-chip--energy {
  background: var(--bronze-light);
  border: 1.5px solid var(--bronze);
}
.plateau-chip--energy .rb-glyph {
  margin: 0;
}
.plateau-chip--essence {
  background: var(--bg-raised);
  border: 1.5px solid var(--bronze-light);
  color: var(--bronze-light);
}
.plateau-pool i {
  margin-left: 4px;
  font-style: normal;
  font-family: var(--font-label);
  font-size: 0.6rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}

/* Score : sang pour vous, bronze pour l'adversaire */
.plateau-score {
  position: absolute;
  top: 50%;
  z-index: 3;
  transform: translateY(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}
.plateau-score--you {
  left: 1.6%;
}
.plateau-score--foe {
  right: 1.6%;
}
.plateau-score i {
  margin-bottom: 4px;
  font-style: normal;
  font-family: var(--font-label);
  font-size: 0.6rem;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  color: var(--ink-muted);
  writing-mode: vertical-rl;
  rotate: 180deg;
}
.plateau-gem {
  width: 12px;
  height: 12px;
  border: 1.5px solid var(--line);
  /* Gemme taillée : un losange plutôt qu'un rond. */
  rotate: 45deg;
  transition:
    background 0.5s ease,
    border-color 0.5s ease;
}
.plateau-gem--filled {
  background: var(--blood);
  border-color: var(--blood-text);
}
.plateau-gem--foe.plateau-gem--filled {
  background: var(--bronze);
  border-color: var(--bronze-light);
}
.plateau-gem--pulse {
  animation: plateau-pulse 1.4s ease-in-out infinite;
}

/* Flèche */
.plateau-arrows {
  position: absolute;
  inset: 0;
  z-index: 4;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
.plateau-move {
  fill: none;
  stroke: var(--bronze-light);
  stroke-width: 1.1;
  stroke-linecap: round;
  stroke-dasharray: 3.2 2.4;
  animation: plateau-march 0.9s linear infinite;
}
.plateau-move--halo {
  stroke: rgba(214, 185, 140, 0.22);
  stroke-width: 3;
  stroke-dasharray: none;
  animation: none;
}
.plateau-clash {
  position: absolute;
  z-index: 4;
  transform: translate(-50%, -50%);
  color: var(--blood-bright);
  font-size: 2rem;
  filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.6));
  animation: plateau-pulse 1.6s ease-in-out infinite;
}

/* Gros plan annoté */
.plateau-focus {
  position: absolute;
  left: 50%;
  top: 43%;
  z-index: 6;
  padding: 0;
  height: 76%;
  aspect-ratio: 744 / 1039;
  transform: translate(-50%, -50%);
  cursor: zoom-in;
  animation: plateau-in 0.35s cubic-bezier(0.22, 0.8, 0.32, 1);
}
.plateau-focus img {
  width: 100%;
  height: 100%;
  border-radius: 4.5%;
  box-shadow: 0 18px 44px rgba(0, 0, 0, 0.7);
}
.plateau-focus-note {
  position: absolute;
  transform: translate(-50%, -50%);
  width: 26px;
  height: 26px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--blood);
  color: var(--ink);
  border: 2px solid var(--bronze-light);
  border-radius: 50%;
  font-family: var(--font-label);
  font-size: 0.85rem;
  font-weight: 700;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
  animation: plateau-pulse 2s ease-in-out infinite;
}

@keyframes plateau-march {
  to {
    stroke-dashoffset: -11.2;
  }
}
@keyframes plateau-pop {
  from {
    scale: 0;
  }
  to {
    scale: 1;
  }
}
@keyframes plateau-pulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.45;
  }
}
@keyframes plateau-in {
  from {
    opacity: 0;
    scale: 0.92;
  }
  to {
    opacity: 1;
    scale: 1;
  }
}

@media (max-width: 980px) {
  .plateau-bf-name,
  .plateau-slot-label {
    display: none;
  }
}
/* Téléphone : le plateau garde ~560 px et défile horizontalement (contenu intact),
   au format 16/10 pour ne pas laisser ~250 px vides sous les zones. Bords estompés :
   sans eux, rien ne dit que le plateau défile latéralement. */
@media (max-width: 560px) {
  .plateau-scroller {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    -webkit-mask-image: linear-gradient(90deg, transparent 0, #000 18px, #000 calc(100% - 18px), transparent 100%);
    mask-image: linear-gradient(90deg, transparent 0, #000 18px, #000 calc(100% - 18px), transparent 100%);
  }
  .plateau {
    min-width: 560px;
    aspect-ratio: 16 / 10;
  }
}
/* Les cartes gardent leur place, sans glissement ni clignotement. */
@media (prefers-reduced-motion: reduce) {
  .plateau-bf,
  .plateau-card,
  .plateau-gem,
  .plateau-leave-active {
    transition: none;
  }
  .plateau-card--dead {
    transition-delay: 0s;
  }
  .plateau-bf--contested,
  .plateau-dmg,
  .plateau-chip,
  .plateau-gem--pulse,
  .plateau-move,
  .plateau-clash,
  .plateau-focus,
  .plateau-focus-note {
    animation: none;
  }
}
</style>
