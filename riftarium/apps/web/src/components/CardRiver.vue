<script setup>
import { nextTick, onMounted, onUnmounted, reactive } from "vue"
import { api, cardThumb } from "../api.js"

/* Deux rangées qui défilent en sens opposés sur des cartes tirées au hasard.
   Chaque carte sortie par un bord est remplacée par une nouvelle : la rivière ne boucle jamais. */
const BATCH = 40 // cartes demandées à chaque tirage
const REFILL = 12 // en dessous, on retourne chercher des cartes
const MEMORY = 200 // cartes déjà passées gardées de côté, au cas où l'API ne répondrait plus
const RESUME_DELAY = 1200 // ms avant reprise après un appui, le temps de viser une carte

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)").matches
/* Seuls `cards` et `held` sont rendus : la position de la piste est écrite
   directement sur le DOM (voir advance), elle changeait à chaque frame et n'a
   rien à faire dans un objet réactif. */
const rows = reactive([
  { cards: [], held: false },
  { cards: [], held: false }
])
/* État non rendu, gardé hors de la réactivité pour ne pas proxifier les réserves ni le DOM. */
const state = [row(72), row(56)]
const root = { el: null }
let seq = 0
let frame = 0
let last = 0
let observer

function row(speed) {
  return {
    speed,
    pool: [],
    seen: [],
    track: null,
    width: 0,
    offset: 0,
    loading: false,
    hovered: false,
    resume: 0
  }
}

/* Fisher-Yates : `sort(() => Math.random() - 0.5)` ne produit pas un tirage
   uniforme (les premières cartes restaient statistiquement devant). */
function shuffle(list) {
  for (let i = list.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[list[i], list[j]] = [list[j], list[i]]
  }
  return list
}

async function refill(i) {
  if (state[i].loading) return
  state[i].loading = true
  try {
    const data = await api(`/api/cards?sort=random&size=${BATCH}`)
    /* Jamais de carte paysage (champs de bataille) : une carte couchée au
       milieu des portraits casse le rythme de la rivière. */
    state[i].pool.push(...data.items.filter((card) => card.image_url && card.orientation !== "landscape"))
  } catch {
    /* on rejouera les cartes déjà passées plutôt que de laisser un trou */
  }
  state[i].loading = false
}

function draw(i) {
  const own = state[i]
  if (own.pool.length <= REFILL) refill(i)
  if (!own.pool.length) own.pool = shuffle(own.seen.splice(0))
  const card = own.pool.shift()
  return card ? { key: ++seq, card } : null
}

function fill(i) {
  const target = Math.ceil(window.innerWidth / 150) + 2
  while (rows[i].cards.length < target) {
    const entry = draw(i)
    if (!entry) return
    rows[i].cards.push(entry)
  }
}

function advance(i, dt) {
  const own = state[i]
  if (rows[i].held || !rows[i].cards.length || !own.track) return

  if (!own.width) {
    const first = own.track.firstElementChild
    if (!first) return
    own.width = first.offsetWidth + parseFloat(getComputedStyle(own.track).columnGap || 0)
  }

  own.offset += own.speed * dt
  own.track.style.transform = `translateX(${-own.offset}px)`
  if (own.offset < own.width) return

  /* La carte de tête est sortie : on la remplace en fin de piste et on rattrape la position. */
  own.offset -= own.width
  own.track.style.transform = `translateX(${-own.offset}px)`
  own.width = 0
  const gone = rows[i].cards.shift()
  rows[i].cards.push(draw(i) || { key: ++seq, card: gone.card })
  own.seen.push(gone.card)
  if (own.seen.length > MEMORY) own.seen.shift()
}

function tick(now) {
  const dt = Math.min((now - last) / 1000, 0.05)
  last = now
  rows.forEach((_, i) => advance(i, dt))
  frame = requestAnimationFrame(tick)
}

function start() {
  if (frame) return
  last = performance.now()
  frame = requestAnimationFrame(tick)
}

function stop() {
  cancelAnimationFrame(frame)
  frame = 0
}

/* Mise en pause. Au doigt il n'y a pas de survol : sans pause, la carte visée
   glisse sous le pouce entre l'appui et le relâchement et c'est la voisine qui
   s'ouvre. On arrête donc la rangée touchée dès l'appui. */
function hold(i) {
  clearTimeout(state[i].resume)
  state[i].resume = 0
  rows[i].held = true
}

/* Reprise différée : au relâchement, le lecteur regarde encore la carte.
   `delay = 0` reprend tout de suite (sortie du survol, perte du focus). */
function release(i, delay = RESUME_DELAY) {
  clearTimeout(state[i].resume)
  state[i].resume = 0
  if (!delay) {
    rows[i].held = state[i].hovered
    return
  }
  state[i].resume = window.setTimeout(() => {
    state[i].resume = 0
    rows[i].held = state[i].hovered
  }, delay)
}

function onEnter(i) {
  state[i].hovered = finePointer
  if (finePointer) hold(i)
}

function onLeave(i) {
  state[i].hovered = false
  release(i, 0)
}

function onResize() {
  rows.forEach((_, i) => fill(i))
}

onMounted(async () => {
  await Promise.all(rows.map((_, i) => refill(i)))
  rows.forEach((_, i) => fill(i))
  /* Posé aussi en mode reduced motion : la rivière statique se re-remplit après un agrandissement. */
  window.addEventListener("resize", onResize)

  if (reducedMotion) return
  await nextTick()
  if (!root.el) return
  observer = new IntersectionObserver(([entry]) => (entry.isIntersecting ? start() : stop()), { threshold: 0.08 })
  observer.observe(root.el)
})

onUnmounted(() => {
  stop()
  state.forEach((own) => clearTimeout(own.resume))
  observer?.disconnect()
  window.removeEventListener("resize", onResize)
})
</script>

<template>
  <div class="river" :ref="(el) => (root.el = el)" v-if="rows[0].cards.length">
    <div
      class="river-row"
      v-for="(line, i) in rows"
      :key="i"
      :class="{ reverse: i === 1 }"
      @mouseenter="onEnter(i)"
      @mouseleave="onLeave(i)"
      @pointerdown="hold(i)"
      @pointerup="release(i)"
      @pointercancel="release(i)"
      @touchstart.passive="hold(i)"
      @touchend="release(i)"
      @focusin="hold(i)"
      @focusout="release(i, 0)"
    >
      <div class="river-track" :ref="(el) => (state[i].track = el)">
        <RouterLink
          v-for="entry in line.cards"
          :key="entry.key"
          class="river-card"
          :class="{ landscape: entry.card.orientation === 'landscape' }"
          :to="`/cartes/${entry.card.id}`"
          :aria-label="`Voir la carte ${entry.card.name}`"
        >
          <img
            :src="cardThumb(entry.card.image_url, 180)"
            :alt="`Carte Riftbound : ${entry.card.name}`"
            width="150"
            height="209"
            loading="lazy"
            decoding="async"
          />
        </RouterLink>
      </div>
    </div>
  </div>
</template>
