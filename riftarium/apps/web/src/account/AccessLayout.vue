<script setup>
import { pickSplash } from "../home/homeData.js"
import RiftPanel from "../ui/RiftPanel.vue"

/* Gabarit des pages d'accès (connexion, mot de passe, vérification) : l'illustration
   du splash d'accueil en fond plein cadre voilé, un panneau centré par-dessus. */
defineProps({
  title: { type: String, required: true },
  kicker: { type: String, default: "" }
})

/* Tirée une fois au montage, comme sur l'accueil. */
const art = pickSplash()
</script>

<template>
  <div class="acces-page">
    <img class="acces-art" :src="art" alt="" fetchpriority="high" decoding="async" />
    <span class="acces-credit">Visuel officiel Riftbound — © Riot Games</span>
    <RiftPanel tag="div" class="acces-panel">
      <p v-if="kicker" class="acces-kicker">{{ kicker }}</p>
      <h1 class="acces-titre">{{ title }}</h1>
      <slot />
    </RiftPanel>
  </div>
</template>

<style scoped>
.acces-page {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: min(78dvh, 720px);
  padding: var(--space-7) var(--space-4);
  overflow: hidden;
  isolation: isolate;
}
.acces-art {
  position: absolute;
  inset: 0;
  z-index: -2;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center 30%;
}
/* voile : l'image reste lisible sans gêner le formulaire */
.acces-page::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -1;
  background: linear-gradient(0deg, var(--bg) 0%, transparent 55%), rgba(13, 13, 15, 0.72);
}
.acces-page :deep(.acces-panel) {
  width: 100%;
  max-width: 440px;
  display: grid;
  gap: var(--space-4);
}
.acces-kicker {
  margin: 0;
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: var(--blood-text);
}
/* neutralise la règle globale h1 de main.css (dégradé doré animé) */
.acces-titre {
  letter-spacing: normal;
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(26px, 5vw, 34px);
  font-weight: 900;
  line-height: 1.1;
  text-transform: uppercase;
  background: none;
  -webkit-background-clip: border-box;
  background-clip: border-box;
  color: var(--ink);
  animation: none;
}
/* Éléments communs du contenu des pages d'accès (posés par les vues dans le slot). */
.acces-page :deep(.acces-form) {
  display: grid;
  gap: var(--space-4);
}
.acces-page :deep(.acces-erreur),
.acces-page :deep(.acces-succes),
.acces-page :deep(.acces-note) {
  margin: 0;
  font-size: 14px;
  line-height: 1.5;
}
.acces-page :deep(.acces-erreur) {
  color: var(--blood-text);
}
.acces-page :deep(.acces-succes) {
  color: var(--bronze-light);
}
.acces-page :deep(.acces-note) {
  color: var(--ink-muted);
}
.acces-page :deep(.acces-lien) {
  color: var(--bronze-light);
  text-underline-offset: 3px;
}
.acces-page :deep(.acces-lien:focus-visible) {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.acces-page :deep(.acces-actions) {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}
.acces-page :deep(.acces-check) {
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
  min-height: 44px;
  font-size: 14px;
  line-height: 1.45;
  color: var(--ink);
  cursor: pointer;
}
.acces-page :deep(.acces-check input:focus-visible) {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
  box-shadow: none;
}
.acces-page :deep(.rift-segments) {
  position: static;
}
.acces-credit {
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
.acces-page :deep(.acces-check input) {
  flex: none;
  width: 24px;
  height: 24px;
  margin: 0;
  accent-color: var(--blood);
}
@media (max-width: 767px) {
  .acces-page {
    align-items: flex-start;
    padding: var(--space-5) var(--space-4);
  }
}
</style>
