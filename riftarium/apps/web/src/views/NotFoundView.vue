<script setup>
import RiftButton from "../ui/RiftButton.vue"

/* Page 404 : rendue telle quelle par la porte admin (AdminGateView), qui doit
   rester indiscernable d'une adresse inexistante. */
</script>

<template>
  <div class="perdu-page">
    <div class="perdu-inner">
      <p class="perdu-code" aria-hidden="true">404</p>
      <h1 class="perdu-titre">Page introuvable</h1>
      <p class="perdu-texte">Cette page n'existe pas ou a été déplacée.</p>
      <div class="perdu-actions">
        <RiftButton to="/" variant="primary">Retour à l'accueil</RiftButton>
        <RouterLink class="perdu-lien" to="/cartes">Chercher une carte</RouterLink>
      </div>
    </div>
  </div>
</template>

<style scoped>
.perdu-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: min(70dvh, 640px);
  padding: var(--space-7) var(--space-4);
  background: radial-gradient(ellipse at 50% 30%, rgba(179, 38, 43, 0.14), transparent 60%), var(--bg);
  text-align: center;
}
.perdu-inner {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-3);
  max-width: 560px;
}
.perdu-code {
  margin: 0;
  color: var(--blood-bright);
  font-family: var(--font-display);
  font-size: clamp(5rem, 22vw, 10rem);
  font-weight: 700;
  line-height: 1;
  letter-spacing: 0.04em;
}
.perdu-page .perdu-titre {
  margin: 0;
  color: var(--ink);
  font-family: var(--font-display);
  font-size: clamp(1.6rem, 4vw, 2.2rem);
  font-weight: 700;
}
.perdu-texte {
  margin: 0 0 var(--space-3);
  color: var(--ink-muted);
  font-family: var(--font-body);
  font-size: 17px;
  line-height: 1.55;
}
.perdu-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: var(--space-3) var(--space-5);
}
.perdu-lien {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 16px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  text-decoration: none;
}
.perdu-lien:hover {
  text-decoration: underline;
}
.perdu-lien:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
</style>
