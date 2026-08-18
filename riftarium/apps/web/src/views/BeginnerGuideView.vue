<script setup>
import { computed, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { STEPS, ZONES, slot } from "../rules/guide.js"

const route = useRoute()
const router = useRouter()

const initial = Number.parseInt(route.query.etape, 10)
const stepIndex = ref(initial >= 1 && initial <= STEPS.length ? initial - 1 : 0)
watch(stepIndex, (value) => router.replace({ query: value ? { etape: value + 1 } : {} }))
const step = computed(() => STEPS[stepIndex.value])
const scene = computed(() => step.value.scene)

const strong = (text) => text.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")

/* Positionne chaque jeton dans sa zone, avec un léger étalement. */
const tokens = computed(() => {
  const byZone = {}
  for (const token of scene.value.tokens) (byZone[token.zone] ??= []).push(token)
  return scene.value.tokens.map((token) => {
    const group = byZone[token.zone]
    const point = slot(token.zone, group.indexOf(token), group.length)
    return { ...token, ...point }
  })
})

const highlighted = (zone) => scene.value.highlight?.includes(zone)
const contested = (zone) => scene.value.contested?.includes(zone)
const controller = (zone) => scene.value.control?.[zone]

const arrowPath = computed(() => {
  const arrow = scene.value.arrow
  if (!arrow) return null
  const from = ZONES[arrow.from]
  const to = ZONES[arrow.to]
  const midY = (from.y + to.y) / 2
  return `M ${from.x} ${from.y - 34} C ${from.x} ${midY}, ${to.x} ${midY}, ${to.x} ${to.y + 46}`
})

function goTo(index) {
  stepIndex.value = Math.min(STEPS.length - 1, Math.max(0, index))
}
function onKeydown(event) {
  if (event.key === "ArrowRight") goTo(stepIndex.value + 1)
  if (event.key === "ArrowLeft") goTo(stepIndex.value - 1)
}
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Guide du débutant</p>
      <h2>Apprenez à jouer en dix étapes</h2>
      <p class="lead">
        Le plateau ci-dessous s'anime à chaque étape : placement des cartes, déplacements, combat, points. Comptez cinq
        minutes.
      </p>
    </div>
  </div>

  <section style="padding-top: 36px">
    <div class="wrap guide-layout" @keydown="onKeydown" tabindex="0" aria-label="Guide interactif">
      <div class="guide-board panel" v-reveal>
        <svg viewBox="0 0 900 560" class="board" aria-hidden="true">
          <defs>
            <linearGradient id="bd-gold" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stop-color="#d9bd82" />
              <stop offset="1" stop-color="#8a6a2f" />
            </linearGradient>
            <marker
              id="bd-arrow"
              viewBox="0 0 10 10"
              refX="8"
              refY="5"
              markerWidth="7"
              markerHeight="7"
              orient="auto-start-reverse"
            >
              <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--hex)" />
            </marker>
          </defs>

          <!-- Zones -->
          <g v-for="(zone, key) in ZONES" :key="key">
            <rect
              class="bd-zone"
              :class="{
                lit: highlighted(key),
                contested: contested(key),
                'ctrl-you': controller(key) === 'you',
                'ctrl-foe': controller(key) === 'foe',
                base: key.endsWith('Base')
              }"
              :x="zone.x - zone.w / 2"
              :y="zone.y - zone.h / 2"
              :width="zone.w"
              :height="zone.h"
              rx="16"
            />
            <text class="bd-zone-label" :x="zone.x" :y="zone.y + zone.h / 2 - 10">{{ zone.label }}</text>
            <text v-if="contested(key)" class="bd-flag" :x="zone.x" :y="zone.y - zone.h / 2 + 20">contesté</text>
            <text v-else-if="controller(key)" class="bd-flag ok" :x="zone.x" :y="zone.y - zone.h / 2 + 20">
              contrôlé
            </text>
          </g>

          <!-- Flèche de déplacement -->
          <path v-if="arrowPath" class="bd-move" :d="arrowPath" marker-end="url(#bd-arrow)" />

          <!-- Éclair de combat -->
          <text v-if="scene.clash" class="bd-clash" :x="ZONES[scene.clash].x" :y="ZONES[scene.clash].y - 78">⚔</text>

          <!-- Jetons unités -->
          <g
            v-for="token in tokens"
            :key="token.id"
            class="bd-token"
            :class="{ foe: token.side === 'foe', exhausted: token.exhausted, dead: token.dead, enter: token.enter }"
            :style="{ transform: `translate(${token.x}px, ${token.y}px)` }"
          >
            <circle r="24" class="bd-token-bg" />
            <text class="bd-token-power" dy="7">{{ token.power }}</text>
          </g>

          <!-- Main, runes, ressources -->
          <g v-if="scene.hand" class="bd-hand">
            <rect
              v-for="i in scene.hand"
              :key="i"
              class="bd-card"
              :x="30 + (i - 1) * 18"
              y="470"
              width="34"
              height="50"
              rx="5"
              :style="{ transitionDelay: i * 60 + 'ms' }"
            />
            <text class="bd-zone-label" x="66" y="548">Main</text>
          </g>
          <g v-if="scene.runes" class="bd-runes">
            <circle v-for="i in scene.runes" :key="i" class="bd-rune" :cx="846 - (i - 1) * 30" cy="492" r="13" />
            <text class="bd-zone-label" x="830" y="548">Runes</text>
          </g>
          <g v-if="scene.energy" class="bd-pool">
            <g v-for="i in scene.energy" :key="'en' + i" :style="{ transitionDelay: i * 80 + 'ms' }">
              <circle class="bd-energy" :cx="846 - (i - 1) * 30" cy="430" r="11" />
              <text class="bd-energy-num" :x="846 - (i - 1) * 30" y="435">1</text>
            </g>
            <circle v-if="scene.essence" class="bd-essence" cx="846" cy="368" r="11" />
          </g>

          <!-- Score : gemmes de victoire -->
          <g class="bd-score">
            <text class="bd-zone-label" x="54" y="36">Vous</text>
            <circle
              v-for="i in 8"
              :key="'sy' + i"
              class="bd-gem"
              :class="{ filled: i <= scene.score.you, pulse: scene.scorePulse && i === scene.score.you }"
              :cx="30 + (i - 1) * 26"
              cy="56"
              r="9"
            />
            <text class="bd-zone-label" x="838" y="36">Adversaire</text>
            <circle
              v-for="i in 8"
              :key="'sf' + i"
              class="bd-gem foe"
              :class="{ filled: i <= scene.score.foe }"
              :cx="870 - (i - 1) * 26"
              cy="56"
              r="9"
            />
          </g>
        </svg>
      </div>

      <div class="guide-side" v-reveal="1">
        <p class="mono guide-count">Étape {{ stepIndex + 1 }} / {{ STEPS.length }}</p>
        <h3 class="guide-title">{{ step.title }}</h3>
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
