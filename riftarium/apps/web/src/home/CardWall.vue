<script setup>
import { ref, watch } from "vue"
import { api, cardThumb } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import { latestSet, wallCards } from "./homeData.js"

/* `sets` : liste des sets chargée par l'accueil, null tant qu'elle n'est pas arrivée. */
const props = defineProps({ sets: { type: Array, default: null } })

/* Mur de cartes : le dernier set en mosaïque inclinée qui défile lentement dans la
   pénombre. Décoratif (aria-hidden) ; le titre et le bouton portent le sens.
   Trimé à un multiple de 24 : la grille fixe (12, 8 ou 6 colonnes) doit remplir un nombre
   entier de lignes pour que la boucle (trois copies + translateY(-33,3 %)) s'enroule sans couture. */
const MIN_CARDS = 24

const set = ref(null)
const items = ref([])
const reduced =
  typeof window !== "undefined" && window.matchMedia
    ? window.matchMedia("(prefers-reduced-motion: reduce)").matches
    : false

async function load(sets) {
  if (!sets) return
  try {
    const latest = latestSet(sets)
    if (!latest) return
    /* size=100 : maximum de l'API, pour que le découpage garde 48 cartes même si quelques-unes sont écartées. */
    const page = await api(`/api/cards?set_id=${encodeURIComponent(latest.set_id)}&sort=random&size=100`)
    const picked = wallCards(page.items, 48)
    /* Trimé à un multiple de 24 pour que la boucle s'enroule sans couture. */
    const trimmed = picked.slice(0, Math.floor(picked.length / 24) * 24)
    if (trimmed.length < MIN_CARDS) return
    set.value = latest
    items.value = trimmed
  } catch {
    /* pas de mur plutôt qu'un trou : l'accueil reste lisible sans lui */
  }
}

watch(() => props.sets, load, { immediate: true })
</script>

<template>
  <section v-if="set" class="wall" :class="{ static: reduced }">
    <div class="wall-mosaic" aria-hidden="true">
      <div class="wall-track">
        <img
          v-for="(card, i) in [...items, ...items, ...items]"
          :key="`${card.id}-${i}`"
          :src="cardThumb(card.image_url, 200)"
          alt=""
          loading="lazy"
          decoding="async"
        />
      </div>
    </div>
    <div class="wall-veil"></div>
    <div class="wall-copy">
      <p class="wall-kicker">Dernier set · {{ set.name }}</p>
      <h2 class="wall-title">Tout le <em>Rift</em><br />sur une table.</h2>
      <RiftButton :to="`/cartes?set=${set.set_id}`">Explorer {{ set.name }}</RiftButton>
    </div>
    <span class="wall-credit">Visuels officiels Riftbound — © Riot Games</span>
  </section>
</template>

<style scoped>
.wall {
  position: relative;
  height: 460px;
  overflow: hidden;
  border-top: 1px solid var(--line);
  border-bottom: 1px solid var(--line);
}
.wall-mosaic {
  position: absolute;
  inset: -120px -80px;
  transform: rotate(-12deg);
  opacity: 0.5;
}
.wall-track {
  display: grid;
  grid-template-columns: repeat(var(--wall-cols), minmax(0, 1fr));
  --wall-cols: 12;
  gap: var(--space-3);
  animation: wall-scroll 120s linear infinite;
}
.wall-track img {
  width: 100%;
  aspect-ratio: 0.716;
  object-fit: cover;
  border-radius: 6px;
}
.wall.static .wall-track {
  animation: none;
}
.wall-veil {
  position: absolute;
  inset: 0;
  background: radial-gradient(
    520px 260px at 50% 55%,
    rgba(13, 13, 15, 0.94),
    rgba(13, 13, 15, 0.55) 70%,
    rgba(13, 13, 15, 0.25)
  );
}
.wall-copy {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: var(--space-4);
  text-align: center;
}
.wall-kicker {
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.wall-title {
  margin: var(--space-2) 0 var(--space-5);
  font-family: var(--font-display);
  font-size: clamp(30px, 5vw, 52px);
  font-weight: 900;
  line-height: 1.05;
  text-transform: uppercase;
}
.wall-title em {
  font-style: normal;
  color: var(--blood-bright);
}
.wall-credit {
  position: absolute;
  right: var(--space-4);
  bottom: var(--space-2);
  font-size: 11px;
  color: var(--ink-muted);
}
@keyframes wall-scroll {
  to {
    transform: translateY(-33.3333%);
  }
}
@media (max-width: 1023px) {
  .wall-track {
    --wall-cols: 8;
  }
}
@media (max-width: 767px) {
  .wall-track {
    --wall-cols: 6;
  }
}
</style>
