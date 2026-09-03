<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { cardThumb } from "../api.js"
import { BANNERS } from "../banners.js"
import { escapeHtml } from "../htmlText.js"
import PageBanner from "../components/PageBanner.vue"
import { CARDS, SPOTS, STEPS } from "../rules/guide.js"

const route = useRoute()
const router = useRouter()

/* `?etape=` est la seule mémoire de la progression : elle doit suivre les boutons
   du guide, et le guide doit suivre les boutons Précédent / Suivant du navigateur. */
const stepFromQuery = (value) => {
  const parsed = Number.parseInt(value, 10)
  return parsed >= 1 && parsed <= STEPS.length ? parsed - 1 : 0
}

const stepIndex = ref(stepFromQuery(route.query.etape))
watch(stepIndex, (value) => {
  /* Garde anti-boucle : ne rien écrire si l'adresse dit déjà la même étape. */
  if (stepFromQuery(route.query.etape) === value) return
  router.replace({ query: value ? { etape: value + 1 } : {} })
})
watch(
  () => route.query.etape,
  (value) => {
    const next = stepFromQuery(value)
    if (next !== stepIndex.value) stepIndex.value = next
  }
)

const step = computed(() => STEPS[stepIndex.value])
const scene = computed(() => step.value.scene)

const strong = (text) => escapeHtml(text).replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")

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
  if (event.key === "Escape") {
    if (zoomCard.value) zoomCard.value = null
    else if (fullscreen.value) toggleFullscreen()
  }
}

/* Zoom : cliquer une carte pour la lire en grand. */
const zoomCard = ref(null)
const zoomUrl = (card) => cardThumb(card.img, 1024)

/* Le zoom se présente comme un dialogue : Échap doit le fermer où que soit le
   focus, et le panneau doit être atteignable au clavier dès son ouverture. */
const zoomEl = ref(null)

function onZoomKey(event) {
  if (event.key === "Escape") zoomCard.value = null
}

watch(zoomCard, async (card) => {
  if (card) {
    document.addEventListener("keydown", onZoomKey)
    await nextTick()
    zoomEl.value?.focus()
  } else {
    document.removeEventListener("keydown", onZoomKey)
  }
})

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
onBeforeUnmount(() => {
  document.removeEventListener("fullscreenchange", syncFullscreen)
  document.removeEventListener("keydown", onZoomKey)
  /* Quitter la page en plein écran laissait le navigateur bloqué sur un élément
     démonté : on rend la main explicitement. */
  if (document.fullscreenElement) document.exitFullscreen?.()
})
</script>

<template>
  <PageBanner :art="BANNERS.rules" title="Prise en main">
    <template #eyebrow> <RouterLink to="/regles">Règles</RouterLink> › Prise en main </template>
  </PageBanner>

  <section>
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
            {{ fullscreen ? "Quitter le plein écran" : "Plein écran" }}
          </button>
        </div>

        <!-- Sur téléphone (CSS ≤560), le plateau garde sa largeur et défile horizontalement -->
        <div class="tb-scroller">
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
              <!-- Une carte face visible s'agrandit au clic : c'est un bouton, pas un div
                   cliquable (clavier, lecteurs d'écran). Les cartes face cachée ne sont
                   pas interactives et restent des div. -->
              <component
                :is="placed.facedown ? 'div' : 'button'"
                v-for="placed in scene.cards"
                :key="placed.key"
                class="tb-card"
                :type="placed.facedown ? undefined : 'button'"
                :aria-label="placed.facedown ? undefined : `Agrandir ${placed.card.name}`"
                @click="!placed.facedown && (zoomCard = placed.card)"
                :class="{
                  tapped: placed.tapped,
                  dead: placed.dead,
                  wide: placed.wide,
                  glow: placed.glow,
                  ghost: placed.ghost,
                  inhand: placed.hand,
                  clickable: !placed.facedown
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
              </component>
            </TransitionGroup>

            <!-- Gros plan annoté : lire une carte -->
            <button
              v-if="scene.focus"
              type="button"
              class="tb-focus"
              :aria-label="`Agrandir ${scene.focus.card.name}`"
              @click="zoomCard = scene.focus.card"
            >
              <img :src="zoomUrl(scene.focus.card)" :alt="scene.focus.card.name" />
              <span
                v-for="note in scene.focus.notes"
                :key="note.n"
                class="tb-focus-note"
                :style="{ left: note.x + '%', top: note.y + '%' }"
              >
                {{ note.n }}
              </span>
            </button>

            <!-- Réserve runique -->
            <div v-if="scene.chips" class="tb-pool" aria-label="Réserve runique">
              <span v-for="i in scene.chips.energy" :key="'e' + i" class="tb-chip energy">1</span>
              <span v-for="i in scene.chips.essence" :key="'c' + i" class="tb-chip essence">✦</span>
              <i class="mono">Réserve runique</i>
            </div>
            <!-- Carte en grand au clic -->
            <div
              v-if="zoomCard"
              ref="zoomEl"
              class="tb-zoom"
              role="dialog"
              aria-modal="true"
              aria-label="Carte en grand"
              tabindex="-1"
              @click="zoomCard = null"
            >
              <img :src="zoomUrl(zoomCard)" :alt="zoomCard.name" />
              <p class="mono">{{ zoomCard.name }} — cliquez pour fermer</p>
            </div>
          </div>
        </div>
        <p class="tb-credit mono">Cartes et visuels officiels Riftbound — © Riot Games, servis par le CDN officiel.</p>
      </div>

      <div class="guide-panel" v-reveal="1">
        <div class="guide-controls">
          <div class="guide-nav">
            <button class="btn btn-ghost" :disabled="stepIndex === 0" @click="goTo(stepIndex - 1)">← Précédent</button>
            <button v-if="stepIndex < STEPS.length - 1" class="btn btn-gold" @click="goTo(stepIndex + 1)">
              Suivant →
            </button>
            <RouterLink v-else class="btn btn-gold" to="/regles/avancee">Passer à l'aide avancée →</RouterLink>
          </div>
          <!-- Ni tablist ni tab : aucun panneau d'onglets n'est associé, et le motif
               ARIA imposerait alors une navigation aux flèches qui n'existe pas ici. -->
          <div class="guide-dots" aria-label="Étapes du guide">
            <button
              v-for="(s, i) in STEPS"
              :key="s.key"
              type="button"
              class="guide-dot"
              :aria-current="i === stepIndex ? 'true' : undefined"
              :aria-label="s.title"
              :class="{ active: i === stepIndex, done: i < stepIndex }"
              @click="goTo(i)"
            ></button>
          </div>
          <p class="muted" style="font-size: 0.72rem">Flèches ← → du clavier pour naviguer.</p>
        </div>
        <div class="guide-copy">
          <h3 class="guide-title">{{ step.title }}</h3>
          <div class="guide-terms">
            <span v-for="term in step.terms" :key="term" class="guide-term mono">{{ term }}</span>
          </div>
          <Transition name="guide-text" mode="out-in">
            <ul class="guide-text" :key="step.key">
              <!-- eslint-disable-next-line vue/no-v-html -->
              <li v-for="(line, i) in step.text" :key="i" v-html="strong(line)"></li>
            </ul>
          </Transition>
          <p class="muted" style="font-size: 0.76rem">
            <RouterLink :to="`/regles/officielles?doc=core&section=${step.ref}`">Règle {{ step.ref }} ↗</RouterLink>
          </p>
        </div>
      </div>
    </div>
  </section>

  <section style="padding-top: 0">
    <div class="wrap cols-2">
      <div class="panel" v-reveal>
        <h3 style="margin-bottom: 10px">Aide avancée</h3>
        <p class="muted" style="font-size: 0.95rem; margin-bottom: 16px">
          Chaque mécanique en détail : timing, combat, mots-clés.
        </p>
        <RouterLink class="btn" to="/regles/avancee">Ouvrir l'aide avancée</RouterLink>
      </div>
      <div class="panel" v-reveal="1">
        <h3 style="margin-bottom: 10px">Règles officielles</h3>
        <p class="muted" style="font-size: 0.95rem; margin-bottom: 16px">
          Le texte officiel intégral, en dernier recours.
        </p>
        <RouterLink class="btn" to="/regles/officielles">Ouvrir les règles officielles</RouterLink>
      </div>
    </div>
  </section>
</template>
