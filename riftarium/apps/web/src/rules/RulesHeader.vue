<script setup>
import { RouterLink } from "vue-router"

/* En-tête commun des pages de règles : fil d'Ariane, sur-titre, titre, filet, slot. */
defineProps({
  title: { type: String, required: true },
  kicker: { type: String, default: "" },
  crumbs: { type: Array, default: () => [] }
})
</script>

<template>
  <header class="regles-head">
    <nav v-if="crumbs.length" class="regles-crumbs" aria-label="Fil d'Ariane">
      <ol>
        <li v-for="(crumb, i) in crumbs" :key="i">
          <span v-if="i === crumbs.length - 1" class="regles-crumb-current" aria-current="page">{{ crumb.label }}</span>
          <RouterLink v-else-if="crumb.to" :to="crumb.to">{{ crumb.label }}</RouterLink>
          <span v-else>{{ crumb.label }}</span>
        </li>
      </ol>
    </nav>
    <p v-if="kicker" class="regles-kicker">{{ kicker }}</p>
    <h1 class="regles-title">{{ title }}</h1>
    <div class="regles-rule" aria-hidden="true"></div>
    <div v-if="$slots.default" class="regles-head-slot"><slot /></div>
  </header>
</template>

<style scoped>
.regles-head {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  margin-bottom: var(--space-5);
}
.regles-crumbs ol {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1) var(--space-2);
  margin: 0;
  padding: 0;
  list-style: none;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.regles-crumbs li {
  display: flex;
  align-items: center;
}
.regles-crumbs li + li::before {
  content: "/";
  margin-right: var(--space-2);
  color: var(--ink-muted);
}
.regles-crumbs a {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--ink-muted);
  text-decoration: none;
  transition: color 0.15s;
}
.regles-crumbs a:hover {
  color: var(--bronze-light);
}
.regles-crumbs a:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.regles-crumb-current {
  color: var(--ink);
}
.regles-kicker {
  margin: 0;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.regles-title {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-family: var(--font-display);
  font-size: clamp(26px, 4vw, 40px);
  font-weight: 700;
  line-height: 1.15;
}
.regles-rule {
  width: 120px;
  height: 2px;
  background: linear-gradient(90deg, var(--bronze-light), transparent);
}
.regles-head-slot {
  margin-top: var(--space-2);
}
</style>
