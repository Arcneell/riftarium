<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { CARDS, SPOTS, STEPS } from "../rules/guide.js"

const route = useRoute()
const router = useRouter()

const initial = Number.parseInt(route.query.etape, 10)
const stepIndex = ref(initial >= 1 && initial <= STEPS.length ? initial - 1 : 0)
watch(stepIndex, (value) => router.replace({ query: value ? { etape: value + 1 } : {} }))

const step = computed(() => STEPS[stepIndex.value])
const scene = computed(() => step.value.scene)

const strong = (text) => text.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")

const contested = (bf) => scene.value.contested?.includes(bf)
const controller = (bf) => scene.value.control?.[bf]

/* Flèche dans un repère 160×95 (même proportion que le plateau) : pas de déformation. */
const arrowPath = computed(() => {
  const arrow = scene.value.arrow
  if (!arrow) return null
  const from = { x: arrow.from.x * 1.6, y: arrow.from.y * 0.95 }
  const to = { x: arrow.to.x * 1.6, y: arrow.to.y * 0.95 }
  const midY = (from.y + to.y) / 2
  return `M ${from.x} ${from.y} C ${from.x} ${midY}, ${to.x} ${midY}, ${to.x} ${to.y}`
})

function goTo(index) {
  stepIndex.value = Math.min(STEPS.length - 1, Math.max(0, index))
}
function onKeydown(event) {
  if (event.key === "ArrowRight") goTo(stepIndex.value + 1)
  if (event.key === "ArrowLeft") goTo(stepIndex.value - 1)
  if (event.key === "Escape" && fullscreen.value) toggleFullscreen()
}

/* Plein écran : API Fullscreen quand elle existe, sinon simple superposition. */
const fullscreen = ref(false)
const layoutEl = ref(null)

function toggleFullscreen() {
  fullscreen.value = !fullscreen.value
  if (fullscreen.value) {
    layoutEl.value?.requestFullscreen?.().catch(() => {})
    layoutEl.value?.focus()
  } else if (document.fullscreenElement) {
    document.exitFullscreen?.()
  }
}
const syncFullscreen = () => {
  if (!document.fullscreenElement) fullscreen.value = false
}
onMounted(() => document.addEventListener("fullscreenchange", syncFullscreen))
onBeforeUnmount(() => document.removeEventListener("fullscreenchange", syncFullscreen))
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow"><RouterLink to="/regles">Règles</RouterLink> › Prise en main</p>
      <h2>Prise en main : apprenez à jouer</h2>
      <p class="lead">
        Une partie de duel (1c1) rejouée sous vos yeux sur la disposition du tapis officiel, avec de vraies cartes, une
        vraie main et une vraie pioche. Les termes officiels sont mis en évidence à chaque étape.
      </p>
    </div>
  </div>

  <section style="padding-top: 28px">
    <div
      ref="layoutEl"
      class="wrap guide-layout"
      :class="{ full: fullscreen }"
      @keydown="onKeydown"
      tabindex="0"
      aria-label="Guide interactif"
    >
      <div class="guide-board" v-reveal>
        <div class="guide-toolbar">
          <p class="mono guide-count">Étape {{ stepIndex + 1 }} / {{ STEPS.length }} — {{ step.title }}</p>
          <button
            class="btn btn-ghost btn-sm guide-fullscreen"
            type="button"
            :aria-pressed="fullscreen"
            @click="toggleFullscreen"
          >
            {{ fullscreen ? "✕ Quitter le plein écran" : "⛶ Plein écran" }}
          </button>
        </div>

        <div class="tb">
          <template v-if="!scene.bare">
            <!-- Bases (la vôtre en bas, la sienne en miroir) -->
            <div class="tb-strip foe"><span>Base adverse</span></div>
            <div class="tb-strip you"><span>Votre base</span></div>
            <div class="tb-slot" :style="{ left: SPOTS.discard.x + '%', top: SPOTS.discard.y + '%' }">
              <span>Défausse</span>
            </div>
            <div class="tb-slot" :style="{ left: SPOTS.foeDiscard.x + '%', top: SPOTS.foeDiscard.y + '%' }">
              <span>Sa défausse</span>
            </div>
            <div class="tb-runezone"><span>Runes</span></div>
            <div class="tb-handzone"><span>Votre main</span></div>

            <!-- Champs de bataille : 2 en duel, un présenté par chaque joueur -->
            <div
              v-for="bf in ['bfFoe', 'bfYou']"
              :key="bf"
              class="tb-bf"
              :class="{
                contested: contested(bf),
                controlled: controller(bf) === 'you',
                'controlled-foe': controller(bf) === 'foe'
              }"
              :style="{ left: SPOTS[bf].x + '%', top: SPOTS[bf].y + '%' }"
            >
              <img :src="CARDS[bf].img" :alt="CARDS[bf].name" loading="lazy" />
              <span class="tb-bf-name mono">{{ bf === "bfFoe" ? "Champ adverse" : "Votre champ" }}</span>
              <span v-if="contested(bf)" class="tb-bf-flag">Contesté</span>
              <span v-else-if="controller(bf) === 'you'" class="tb-bf-flag ok">À vous</span>
              <span v-else-if="controller(bf) === 'foe'" class="tb-bf-flag">À lui</span>
            </div>

            <!-- Main adverse : dos de cartes en haut -->
            <div v-if="scene.foeHand" class="tb-foehand" aria-label="Main adverse">
              <span v-for="i in scene.foeHand" :key="i" class="tb-back small"></span>
            </div>

            <!-- Score : pistes verticales de 8 gemmes -->
            <div class="tb-score you" aria-label="Vos points">
              <i class="mono">Vous</i>
              <span
                v-for="i in 8"
                :key="i"
                class="tb-gem"
                :class="{ filled: i <= scene.score.you, pulse: scene.scorePulse && i === scene.score.you }"
              ></span>
            </div>
            <div class="tb-score foe" aria-label="Points adverses">
              <i class="mono">Adversaire</i>
              <span v-for="i in 8" :key="i" class="tb-gem foe" :class="{ filled: i <= scene.score.foe }"></span>
            </div>
          </template>

          <!-- Flèche (pioche ou déplacement) -->
          <svg v-if="arrowPath" class="tb-arrows" viewBox="0 0 160 95" aria-hidden="true">
            <defs>
              <marker
                id="tb-head"
                viewBox="0 0 8 8"
                refX="6.4"
                refY="4"
                markerWidth="3.4"
                markerHeight="3.4"
                orient="auto"
              >
                <path d="M 0 0 L 8 4 L 0 8 z" fill="var(--hex)" />
              </marker>
            </defs>
            <path class="tb-move halo" :d="arrowPath" />
            <path class="tb-move" :d="arrowPath" marker-end="url(#tb-head)" />
          </svg>

          <!-- Combat en cours -->
          <span
            v-if="scene.clash"
            class="tb-clash"
            :style="{ left: SPOTS.bfFoe.x + '%', top: SPOTS.bfFoe.y - 24 + '%' }"
            aria-hidden="true"
            >⚔</span
          >

          <!-- Cartes -->
          <TransitionGroup name="tb">
            <div
              v-for="placed in scene.cards"
              :key="placed.key"
              class="tb-card"
              :class="{
                tapped: placed.tapped,
                dead: placed.dead,
                wide: placed.wide,
                glow: placed.glow,
                inhand: placed.hand
              }"
              :style="{
                left: placed.spot.x + '%',
                top: placed.spot.y + '%',
                '--r': (placed.spot.r ?? 0) + 'deg'
              }"
            >
              <span v-if="placed.facedown" class="tb-back" :title="placed.label"></span>
              <img v-else :src="placed.card.img" :alt="placed.card.name" loading="lazy" />
              <span v-if="placed.might && placed.card.might" class="tb-might">{{ placed.card.might }}</span>
              <span v-if="placed.dmg" class="tb-dmg">−{{ placed.dmg }}</span>
              <span v-if="placed.label" class="tb-slot-label mono">{{ placed.label }}</span>
            </div>
          </TransitionGroup>

          <!-- Réserve runique -->
          <div v-if="scene.chips" class="tb-pool" aria-label="Réserve runique">
            <span v-for="i in scene.chips.energy" :key="'e' + i" class="tb-chip energy">1</span>
            <span v-for="i in scene.chips.essence" :key="'c' + i" class="tb-chip essence">✦</span>
            <i class="mono">Réserve runique</i>
          </div>
        </div>
        <p class="tb-credit mono">Cartes et visuels officiels Riftbound — © Riot Games, servis par le CDN officiel.</p>
      </div>

      <div class="guide-panel" v-reveal="1">
        <div class="guide-copy">
          <h3 class="guide-title">{{ step.title }}</h3>
          <div class="guide-terms">
            <span v-for="term in step.terms" :key="term" class="guide-term mono">{{ term }}</span>
          </div>
          <Transition name="guide-text" mode="out-in">
            <ul class="guide-text" :key="step.key">
              <li v-for="(line, i) in step.text" :key="i" v-html="strong(line)"></li>
            </ul>
          </Transition>
          <p class="muted" style="font-size: 0.76rem">
            <RouterLink :to="`/regles/officielles?doc=core&section=${step.ref}`">Règle {{ step.ref }} ↗</RouterLink>
          </p>
        </div>
        <div class="guide-controls">
          <div class="guide-nav">
            <button class="btn btn-ghost" :disabled="stepIndex === 0" @click="goTo(stepIndex - 1)">← Précédent</button>
            <button v-if="stepIndex < STEPS.length - 1" class="btn btn-gold" @click="goTo(stepIndex + 1)">
              Suivant →
            </button>
            <RouterLink v-else class="btn btn-gold" to="/regles/avancee">Passer à l'aide avancée →</RouterLink>
          </div>
          <div class="guide-dots" role="tablist" aria-label="Étapes du guide">
            <button
              v-for="(s, i) in STEPS"
              :key="s.key"
              class="guide-dot"
              role="tab"
              :aria-selected="i === stepIndex"
              :aria-label="s.title"
              :class="{ active: i === stepIndex, done: i < stepIndex }"
              @click="goTo(i)"
            ></button>
          </div>
          <p class="muted" style="font-size: 0.72rem">Astuce : flèches ← → du clavier pour naviguer.</p>
        </div>
      </div>
    </div>
  </section>

  <section style="padding-top: 0">
    <div class="wrap cols-2">
      <div class="panel" v-reveal>
        <h3 style="margin-bottom: 10px">Une situation compliquée ?</h3>
        <p class="muted" style="font-size: 0.95rem; margin-bottom: 16px">
          L'aide avancée détaille chaque mécanique : timing, combat, mots-clés, cas particuliers.
        </p>
        <RouterLink class="btn" to="/regles/avancee">Ouvrir l'aide avancée</RouterLink>
      </div>
      <div class="panel" v-reveal="1">
        <h3 style="margin-bottom: 10px">Le texte qui fait foi</h3>
        <p class="muted" style="font-size: 0.95rem; margin-bottom: 16px">
          Les 2 137 règles officielles restent consultables et cherchables, en dernier recours.
        </p>
        <RouterLink class="btn" to="/regles/officielles">Ouvrir les règles officielles</RouterLink>
      </div>
    </div>
  </section>
</template>
