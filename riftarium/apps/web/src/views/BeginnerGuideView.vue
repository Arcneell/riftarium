<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { CARDS, STEPS } from "../rules/guide.js"

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

const arrowPath = computed(() => {
  const arrow = scene.value.arrow
  if (!arrow) return null
  const { from, to } = arrow
  return `M ${from.x} ${from.y - 6} C ${from.x} ${(from.y + to.y) / 2}, ${to.x} ${(from.y + to.y) / 2}, ${to.x} ${to.y + 10}`
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
      <p class="eyebrow"><RouterLink to="/regles">Règles</RouterLink> › Guide du débutant</p>
      <h2>Apprenez à jouer, cartes en main</h2>
      <p class="lead">
        Une vraie table de duel (1c1) qui se joue sous vos yeux, avec de vraies cartes du set Origins : mise en place,
        tour de jeu, combat, conquête. Les termes officiels sont mis en évidence à chaque étape.
      </p>
    </div>
  </div>

  <section style="padding-top: 36px">
    <div
      ref="layoutEl"
      class="wrap guide-layout"
      :class="{ full: fullscreen }"
      @keydown="onKeydown"
      tabindex="0"
      aria-label="Guide interactif"
    >
      <div class="guide-board" v-reveal>
        <button
          class="btn btn-ghost btn-sm guide-fullscreen"
          type="button"
          :aria-pressed="fullscreen"
          @click="toggleFullscreen"
        >
          {{ fullscreen ? "✕ Quitter le plein écran" : "⛶ Plein écran" }}
        </button>
        <div class="tb" :class="{ bare: scene.hideBattlefields }">
          <!-- Bandeaux de base -->
          <template v-if="!scene.hideBattlefields">
            <div class="tb-strip foe"><span>Base adverse</span></div>
            <div class="tb-strip you"><span>Votre base</span></div>
            <div class="tb-slot" style="left: 73.5%; top: 83%"><span>Défausse</span></div>
          </template>

          <!-- Champs de bataille (2 en duel : un présenté par chaque joueur) -->
          <template v-if="!scene.hideBattlefields">
            <div
              v-for="bf in ['bfFoe', 'bfYou']"
              :key="bf"
              class="tb-bf"
              :class="{ contested: contested(bf), controlled: controller(bf) === 'you' }"
              :style="{ left: (bf === 'bfFoe' ? 32 : 68) + '%', top: '42%' }"
            >
              <img :src="CARDS[bf].img" :alt="CARDS[bf].name" loading="lazy" />
              <span class="tb-bf-name mono">{{ CARDS[bf].name }}</span>
              <span v-if="contested(bf)" class="tb-bf-flag">Contesté</span>
              <span v-else-if="controller(bf) === 'you'" class="tb-bf-flag ok">Contrôlé</span>
            </div>
          </template>

          <!-- Flèche de déplacement -->
          <svg v-if="arrowPath" class="tb-arrows" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
            <path class="tb-move" :d="arrowPath" />
          </svg>

          <!-- Éclair de combat -->
          <span v-if="scene.clash" class="tb-clash" aria-hidden="true">⚔</span>

          <!-- Cartes -->
          <TransitionGroup name="tb">
            <div
              v-for="placed in scene.cards"
              :key="placed.key"
              class="tb-card"
              :class="{ tapped: placed.tapped, dead: placed.dead, wide: placed.wide, glow: placed.glow }"
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

          <!-- Main (dos de cartes) -->
          <div v-if="scene.hand" class="tb-hand" aria-label="Votre main">
            <span
              v-for="i in scene.hand"
              :key="i"
              class="tb-back small"
              :style="{ rotate: (i - (scene.hand + 1) / 2) * 6 + 'deg' }"
            ></span>
            <i class="mono">Main · {{ scene.hand }}</i>
          </div>

          <!-- Réserve runique -->
          <div v-if="scene.chips" class="tb-pool" aria-label="Réserve runique">
            <span v-for="i in scene.chips.energy" :key="'e' + i" class="tb-chip energy">1</span>
            <span v-for="i in scene.chips.essence" :key="'c' + i" class="tb-chip essence">✦</span>
            <i class="mono">Réserve runique</i>
          </div>

          <!-- Score -->
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
        </div>
        <p class="tb-credit mono">Cartes et visuels officiels Riftbound — © Riot Games, servis par le CDN officiel.</p>
      </div>

      <div class="guide-side" v-reveal="1">
        <p class="mono guide-count">Étape {{ stepIndex + 1 }} / {{ STEPS.length }}</p>
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
