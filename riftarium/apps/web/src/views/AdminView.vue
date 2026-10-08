<script setup>
import { ref } from "vue"
import AdminDecks from "../admin/AdminDecks.vue"
import AdminStats from "../admin/AdminStats.vue"
import AdminUsers from "../admin/AdminUsers.vue"
import RiftSegments from "../ui/RiftSegments.vue"

/* Console d'administration : un composant par onglet. Seul l'onglet actif est monté,
   et chaque activation recharge ses données (la file de modération reste fraîche). */
const TABS = [
  { value: "stats", label: "Statistiques" },
  { value: "users", label: "Utilisateurs" },
  { value: "decks", label: "Decks" }
]
const PANELS = { stats: AdminStats, users: AdminUsers, decks: AdminDecks }
const ID_BASE = "console"
const tab = ref("stats")
</script>

<template>
  <div class="wrap console-page">
    <h1 class="console-title">Administration</h1>

    <RiftSegments v-model="tab" :items="TABS" label="Sections d'administration" :id-base="ID_BASE" />

    <div
      :id="`${ID_BASE}-panel-${tab}`"
      class="console-panel"
      role="tabpanel"
      :aria-labelledby="`${ID_BASE}-tab-${tab}`"
      tabindex="0"
    >
      <component :is="PANELS[tab]" />
    </div>
  </div>
</template>

<style scoped>
.console-page {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.console-title {
  margin: 0;
  background: none;
  -webkit-background-clip: border-box;
  background-clip: border-box;
  animation: none;
  color: var(--ink);
  font-family: var(--font-display);
  font-size: clamp(1.6rem, 3vw, 2.2rem);
  font-weight: 700;
}
.console-panel {
  min-width: 0;
}
.console-panel:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 4px;
}
</style>
