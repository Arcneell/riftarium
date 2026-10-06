<script setup>
import { computed } from "vue"
import { useRoute } from "vue-router"
import { activeSection, NAV, TABBAR_KEYS } from "./navigation.js"

/* Barre d'onglets du bas (téléphone), à la manière d'une app. */
const route = useRoute()
const tabs = NAV.filter((section) => TABBAR_KEYS.includes(section.key))
const current = computed(() => activeSection(route.path)?.key ?? null)
</script>

<template>
  <nav class="tabbar" aria-label="Navigation principale">
    <RouterLink
      v-for="tab in tabs"
      :key="tab.key"
      :to="tab.to"
      class="tab"
      :class="{ active: tab.key === current }"
      :aria-current="tab.key === current ? 'page' : undefined"
    >
      <Icon :name="tab.icon" :size="20" />
      <span>{{ tab.label }}</span>
    </RouterLink>
  </nav>
</template>

<style scoped>
.tabbar {
  position: fixed;
  inset: auto 0 0 0;
  z-index: var(--z-tabbar);
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  height: calc(var(--tabbar-h) + env(safe-area-inset-bottom));
  padding-bottom: env(safe-area-inset-bottom);
  background: var(--bg-sunken);
  border-top: 2px solid var(--blood);
}
.tab {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.tab.active {
  color: #fff;
  box-shadow: inset 0 2px 0 var(--blood-bright);
}
</style>
