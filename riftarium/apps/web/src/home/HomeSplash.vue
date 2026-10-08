<script setup>
import { computed } from "vue"
import RiftButton from "../ui/RiftButton.vue"

/* Ouverture du site : une illustration officielle plein cadre, fondue dans le noir de
   la forge, le titre gravé dessus. */
const props = defineProps({
  art: { type: String, required: true },
  cardCount: { type: Number, default: null },
  setCount: { type: Number, default: null }
})

const showStats = computed(() => props.cardCount !== null && props.setCount !== null)
const format = (n) => n.toLocaleString("fr-FR")
</script>

<template>
  <section class="splash">
    <!-- vraie image (pas un fond CSS) : le navigateur la découvre dès le HTML, bon pour le LCP -->
    <img class="splash-art" :src="art" alt="" fetchpriority="high" decoding="async" />
    <div class="splash-copy">
      <p class="splash-kicker">Le compagnon Riftbound</p>
      <h1 class="splash-title">Forge ton <em>deck.</em><br />Domine le Rift.</h1>
      <p class="splash-lead">Cartes, collection, deck builder et règles officielles, en français.</p>
      <div class="splash-actions">
        <RiftButton to="/cartes">Voir les cartes</RiftButton>
        <RiftButton to="/regles" variant="secondary">Lire les règles</RiftButton>
      </div>
      <p v-if="showStats" class="splash-stats">
        <b>{{ format(cardCount) }}</b> cartes · <b>{{ format(setCount) }}</b> sets
      </p>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>
</template>

<style scoped>
.splash {
  position: relative;
  display: flex;
  align-items: flex-end;
  min-height: min(78dvh, 720px);
  padding: var(--space-7) var(--space-6);
  overflow: hidden;
  isolation: isolate;
}
.splash-art {
  position: absolute;
  inset: 0;
  z-index: -2; /* calques : image (-2), dégradés ::before (-1), puis texte */
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center 30%;
}
/* dégradés par-dessus l'image, sous le texte */
.splash::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -1;
  background:
    linear-gradient(90deg, var(--bg) 12%, rgba(13, 13, 15, 0.72) 48%, rgba(13, 13, 15, 0.1) 100%),
    linear-gradient(0deg, var(--bg) 0%, transparent 45%);
}
.splash-copy {
  max-width: 560px;
  animation: splash-in 700ms ease-out both;
}
.splash-kicker {
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.splash-title {
  margin: var(--space-2) 0 var(--space-4);
  font-family: var(--font-display);
  font-size: clamp(36px, 6vw, 64px);
  font-weight: 900;
  line-height: 1.02;
  text-transform: uppercase;
  /* neutralise la règle globale h1 de main.css (dégradé doré animé en background-clip: text) */
  background: none;
  -webkit-background-clip: border-box;
  background-clip: border-box;
  color: var(--ink);
  animation: none;
}
.splash-title em {
  font-style: normal;
  color: var(--blood-bright);
}
.splash-lead {
  max-width: 440px;
  margin-bottom: var(--space-5);
  font-size: 17px;
  color: var(--ink);
  opacity: 0.85;
}
.splash-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}
.splash-stats {
  margin-top: var(--space-5);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.splash-stats b {
  color: var(--bronze-light);
  font-family: var(--font-display);
  font-size: 18px;
}
.splash-credit {
  position: absolute;
  right: var(--space-4);
  bottom: var(--space-2);
  z-index: 1;
  font-family: var(--font-body);
  font-size: 11px;
  letter-spacing: 0.06em;
  white-space: nowrap;
  color: var(--ink-muted);
}
@keyframes splash-in {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
}
@media (max-width: 767px) {
  .splash {
    min-height: 70dvh;
    padding: var(--space-6) var(--space-4) var(--space-7);
  }
  .splash::before {
    background: linear-gradient(0deg, var(--bg) 18%, rgba(13, 13, 15, 0.55) 70%, rgba(13, 13, 15, 0.3) 100%);
  }
  .splash-art {
    object-position: center;
  }
}
</style>
