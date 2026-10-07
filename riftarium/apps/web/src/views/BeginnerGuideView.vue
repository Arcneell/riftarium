<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import CardZoom from "../rules/CardZoom.vue"
import RulesHeader from "../rules/RulesHeader.vue"
import TableBoard from "../rules/TableBoard.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftText from "../ui/RiftText.vue"
import { CARDS, SPOTS, STEPS } from "../rules/guide.js"

const route = useRoute()
const router = useRouter()

const crumbs = [
  { label: "Règles", to: "/regles" },
  { label: "Apprendre à jouer", to: "/regles/debutant" },
  { label: "Sur le plateau" }
]

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
const isLast = computed(() => stepIndex.value === STEPS.length - 1)

function goTo(index) {
  stepIndex.value = Math.min(STEPS.length - 1, Math.max(0, index))
}

/* Zoom : cliquer une carte pour la lire en grand (CardZoom, vrai dialogue). */
const zoomCard = ref(null)

/* Un champ de saisie garde ses flèches (déplacement du curseur). */
const isField = (target) =>
  target instanceof HTMLElement &&
  (target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName))

function onKeydown(event) {
  if (event.key === "Escape") {
    /* Zoom ouvert : useDialog le ferme sur ce même Échap (écoute sur document,
       après ce gestionnaire). On ne quitte donc pas le plein écran en même temps. */
    if (zoomCard.value) return
    if (fullscreen.value) toggleFullscreen()
    return
  }
  if (isField(event.target)) return
  if (event.key === "ArrowRight") goTo(stepIndex.value + 1)
  if (event.key === "ArrowLeft") goTo(stepIndex.value - 1)
}

/* Plein écran : API Fullscreen quand elle existe, sinon simple superposition.
   L'API vise le document entier (la superposition fait le reste) : le zoom de carte,
   téléporté dans le body, resterait sinon invisible hors de l'élément plein écran. */
const fullscreen = ref(false)
const layoutEl = ref(null)

function toggleFullscreen() {
  fullscreen.value = !fullscreen.value
  if (fullscreen.value) {
    document.documentElement.requestFullscreen?.().catch(() => {})
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
  /* Quitter la page en plein écran laissait le navigateur bloqué : on rend la main explicitement. */
  if (document.fullscreenElement) document.exitFullscreen?.()
})
</script>

<template>
  <div class="wrap cards-wrap regles-plateau">
    <RulesHeader title="Sur le plateau" kicker="Une partie rejouée pas à pas" :crumbs="crumbs" />

    <div
      ref="layoutEl"
      class="plateau-layout"
      :class="{ 'plateau-layout--full': fullscreen }"
      tabindex="0"
      aria-label="Guide interactif"
      @keydown="onKeydown"
    >
      <div class="plateau-board">
        <TableBoard :scene="step.scene" :spots="SPOTS" :cards="CARDS" @zoom="zoomCard = $event" />
        <p class="plateau-credit">Cartes et visuels officiels Riftbound — © Riot Games, servis par le CDN officiel.</p>
      </div>

      <div class="plateau-panel">
        <div class="plateau-toolbar">
          <p class="plateau-count">Étape {{ stepIndex + 1 }} / {{ STEPS.length }} — {{ step.title }}</p>
          <RiftButton
            class="plateau-fullscreen"
            variant="ghost"
            size="sm"
            :aria-pressed="String(fullscreen)"
            @click="toggleFullscreen"
          >
            {{ fullscreen ? "Quitter le plein écran" : "Plein écran" }}
          </RiftButton>
        </div>

        <div class="plateau-nav">
          <RiftButton variant="ghost" :disabled="stepIndex === 0" @click="goTo(stepIndex - 1)">← Précédent</RiftButton>
          <RiftButton v-if="!isLast" variant="primary" @click="goTo(stepIndex + 1)">Suivant →</RiftButton>
          <RiftButton v-else variant="primary" to="/regles/avancee">Passer à l'aide avancée →</RiftButton>
        </div>

        <!-- Ni tablist ni tab : aucun panneau d'onglets n'est associé, et le motif
             ARIA imposerait alors une navigation aux flèches qui n'existe pas ici. -->
        <div class="plateau-dots" role="group" aria-label="Étapes du guide">
          <button
            v-for="(s, i) in STEPS"
            :key="s.key"
            type="button"
            class="plateau-dot"
            :class="{ 'plateau-dot--done': i < stepIndex }"
            :aria-current="i === stepIndex ? 'true' : undefined"
            :aria-label="s.title"
            @click="goTo(i)"
          ></button>
        </div>
        <p class="plateau-hint">Flèches ← → du clavier pour naviguer.</p>

        <div class="plateau-copy">
          <h2 class="plateau-title">{{ step.title }}</h2>
          <div v-if="step.terms?.length" class="plateau-terms">
            <RiftChip v-for="term in step.terms" :key="term" :label="term" static />
          </div>
          <Transition name="plateau-text" mode="out-in">
            <ul :key="step.key" class="plateau-text">
              <li v-for="(line, i) in step.text" :key="i"><RiftText :text="line" rules /></li>
            </ul>
          </Transition>
          <p class="plateau-ref">
            <RouterLink :to="`/regles/officielles?doc=core&section=${step.ref}`">Règle {{ step.ref }} ↗</RouterLink>
          </p>
        </div>
      </div>
    </div>

    <div class="plateau-links">
      <RiftPanel title="Guide en chapitres">
        <p class="plateau-links-text">Relire une notion : victoire, runes, combat, chaîne…</p>
        <RiftButton variant="secondary" to="/regles/debutant">Retour au guide</RiftButton>
      </RiftPanel>
      <RiftPanel title="Aide avancée">
        <p class="plateau-links-text">Chaque mécanique en détail : timing, combat, mots-clés.</p>
        <RiftButton variant="secondary" to="/regles/avancee">Ouvrir l'aide avancée</RiftButton>
      </RiftPanel>
    </div>

    <CardZoom v-if="zoomCard" :card="zoomCard" @close="zoomCard = null" />
  </div>
</template>

<style scoped>
.regles-plateau {
  padding-bottom: var(--space-7);
}
.plateau-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.9fr) minmax(300px, 1fr);
  gap: var(--space-6);
  align-items: start;
  outline: none;
}
.plateau-layout:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 4px;
}
.plateau-board {
  position: sticky;
  top: calc(var(--topbar-h) + var(--space-4));
  min-width: 0;
}
.plateau-credit {
  margin: var(--space-2) 0 0;
  color: var(--ink-muted);
  font-size: 12px;
  text-align: right;
}

/* Panneau d'explications */
.plateau-panel {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  min-width: 0;
  padding: var(--space-5);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow: inset 0 0 0 1px var(--line);
}
.plateau-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}
.plateau-count {
  margin: 0;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.plateau-fullscreen {
  flex: none;
}
.plateau-nav {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}
.plateau-dots {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
/* La pastille est dessinée par ::before : le bouton peut grandir (cible tactile)
   sans que le visuel change. */
.plateau-dot {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 12px;
  height: 12px;
  padding: 0;
}
.plateau-dot::before {
  content: "";
  width: 12px;
  height: 12px;
  border: 1.5px solid var(--line);
  rotate: 45deg;
  transition:
    background var(--t-base),
    border-color var(--t-base),
    scale var(--t-base);
}
.plateau-dot--done::before {
  background: var(--bronze);
  border-color: var(--bronze);
}
.plateau-dot[aria-current="true"]::before {
  background: var(--blood);
  border-color: var(--blood-text);
  scale: 1.3;
}
.plateau-dot:hover::before {
  border-color: var(--bronze-light);
}
.plateau-dot:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 3px;
}
.plateau-hint {
  margin: 0;
  color: var(--ink-muted);
  font-size: 13px;
}
.plateau-copy {
  min-height: 380px;
}
.plateau-title {
  margin: 0 0 var(--space-3);
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 700;
  line-height: 1.25;
  letter-spacing: 0.02em;
}
.plateau-terms {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-bottom: var(--space-4);
}
.plateau-text {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  margin: 0 0 var(--space-4);
  padding: 0;
  list-style: none;
}
.plateau-text li {
  position: relative;
  padding-left: 20px;
  color: var(--ink);
  font-size: 16px;
  line-height: 1.6;
}
.plateau-text li::before {
  content: "";
  position: absolute;
  left: 2px;
  top: 0.6em;
  width: 7px;
  height: 7px;
  background: var(--bronze);
  rotate: 45deg;
}
.plateau-text :deep(b) {
  color: var(--bronze-light);
  font-weight: 600;
}
.plateau-text-enter-active,
.plateau-text-leave-active {
  transition:
    opacity var(--t-base) ease,
    transform var(--t-base) ease;
}
.plateau-text-enter-from {
  opacity: 0;
  transform: translateY(8px);
}
.plateau-text-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
.plateau-ref {
  margin: 0;
  font-size: 14px;
}
.plateau-ref a {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--ink-muted);
}
.plateau-ref a:hover {
  color: var(--bronze-light);
}

/* Liens de bas de page */
.plateau-links {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--space-4);
  margin-top: var(--space-7);
}
.plateau-links-text {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
  font-size: 15px;
}

/* Plein écran : superposition fixe, sous les dialogues (le zoom de carte reste visible). */
.plateau-layout--full {
  position: fixed;
  inset: 0;
  z-index: calc(var(--z-overlay) - 1);
  margin: 0;
  padding: clamp(14px, 2vw, 36px);
  overflow: auto;
  background: var(--bg);
}
.plateau-layout--full :deep(.plateau) {
  width: 100%;
  max-width: calc((100dvh - 130px) * 16 / 12);
  max-height: calc(100dvh - 130px);
  margin: 0 auto;
}
.plateau-layout--full .plateau-board {
  position: static;
}

@media (max-width: 1023px) {
  .plateau-layout {
    grid-template-columns: minmax(0, 1fr);
    gap: var(--space-4);
  }
  .plateau-board {
    position: static;
  }
  .plateau-copy {
    min-height: 0;
  }
}
@media (max-width: 767px) {
  .plateau-links {
    grid-template-columns: minmax(0, 1fr);
  }
}
@media (max-width: 560px) {
  .plateau-panel {
    padding: var(--space-4);
  }
}
/* Tactile : pastille de 12 px dans une cible de 44 px. */
@media (hover: none) {
  .plateau-dots {
    gap: 0;
  }
  .plateau-dot {
    width: 44px;
    height: 44px;
  }
}
@media (prefers-reduced-motion: reduce) {
  .plateau-dot::before,
  .plateau-text-enter-active,
  .plateau-text-leave-active {
    transition: none;
  }
}
</style>
