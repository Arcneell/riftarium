<script setup>
import { reactive, ref, watch } from "vue"
import AdminDecks from "../admin/AdminDecks.vue"
import AdminStats from "../admin/AdminStats.vue"
import AdminUsers from "../admin/AdminUsers.vue"
import RiftSegments from "../ui/RiftSegments.vue"

/* Console d'administration : un composant par onglet. Un onglet n'est monté qu'à sa
   première visite, puis reste monté (masqué) : sa recherche, son filtre et sa page
   survivent aux changements d'onglet. Chaque activation recharge ses données (prop
   `active`), pour que la file de modération reste fraîche. */
const TABS = [
  { value: "stats", label: "Statistiques" },
  { value: "users", label: "Utilisateurs" },
  { value: "decks", label: "Decks" }
]
const PANELS = { stats: AdminStats, users: AdminUsers, decks: AdminDecks }
const ID_BASE = "console"
const tab = ref("stats")
const visited = reactive({ stats: true })
watch(tab, (value) => {
  visited[value] = true
})
</script>

<template>
  <div class="wrap console-page">
    <h1 class="console-title">Administration</h1>

    <RiftSegments v-model="tab" :items="TABS" label="Sections d'administration" :id-base="ID_BASE" />

    <div
      v-for="item in TABS"
      v-show="tab === item.value"
      :id="`${ID_BASE}-panel-${item.value}`"
      :key="item.value"
      class="console-panel"
      role="tabpanel"
      :aria-labelledby="`${ID_BASE}-tab-${item.value}`"
      tabindex="0"
    >
      <component :is="PANELS[item.value]" v-if="visited[item.value]" :active="tab === item.value" />
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
/* Titre de page : neutralise le style de base des h1. */
.console-title {
  margin: 0;
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
