<script setup>
import { computed } from "vue"
import { useRoute } from "vue-router"
import { session } from "../api.js"
import Logo from "../components/Logo.vue"
import UserAvatar from "../components/UserAvatar.vue"
import { breadcrumbOf } from "./navigation.js"
import { pageCrumb } from "./pageCrumb.js"

/* Barre haute du contenu. Bureau : fil d'Ariane + recherche. Téléphone : logo,
   loupe et compte (le rail est remplacé par les onglets du bas). */
defineProps({ mobile: { type: Boolean, default: false } })
const emit = defineEmits(["search", "account"])

const route = useRoute()
const crumbs = computed(() => breadcrumbOf(route.path, pageCrumb.value))
const isMac = typeof navigator !== "undefined" && /Mac|iPhone|iPad/.test(navigator.platform || "")
const shortcut = isMac ? "⌘ K" : "Ctrl K"
</script>

<template>
  <header class="topbar" :class="{ mobile }">
    <template v-if="mobile">
      <RouterLink to="/" class="topbar-brand" aria-label="Riftarium, accueil">
        <Logo />
        <span>Riftarium</span>
      </RouterLink>
      <button type="button" class="topbar-icon" aria-label="Rechercher" @click="emit('search')">
        <Icon name="search" :size="20" />
      </button>
      <button
        type="button"
        class="topbar-icon topbar-account"
        :aria-label="session.token ? `Compte de ${session.handle}` : 'Compte et Jouer'"
        @click="emit('account')"
      >
        <UserAvatar v-if="session.token" :src="session.avatarUrl" :handle="session.handle" :size="28" />
        <Icon v-else name="user" :size="20" />
      </button>
    </template>
    <template v-else>
      <nav class="crumbs" aria-label="Fil d'Ariane">
        <ol>
          <li v-for="(crumb, i) in crumbs" :key="`${i}-${crumb.label}`">
            <RouterLink v-if="crumb.to && i < crumbs.length - 1" :to="crumb.to">{{ crumb.label }}</RouterLink>
            <span v-else aria-current="page">{{ crumb.label }}</span>
          </li>
        </ol>
      </nav>
      <button type="button" class="search-trigger" @click="emit('search')">
        <Icon name="search" :size="16" />
        <span>Rechercher une carte, un deck, une règle…</span>
        <kbd>{{ shortcut }}</kbd>
      </button>
    </template>
  </header>
</template>

<style scoped>
.topbar {
  position: sticky;
  top: 0;
  z-index: var(--z-topbar);
  display: flex;
  align-items: center;
  gap: var(--space-4);
  height: var(--topbar-h);
  padding: 0 var(--space-5);
  background: rgba(13, 13, 15, 0.92);
  border-bottom: 1px solid var(--line);
  backdrop-filter: blur(8px);
}
.topbar.mobile {
  gap: var(--space-1);
  padding: 0 var(--space-2) 0 var(--space-4);
  border-bottom: 2px solid var(--blood);
}
.crumbs {
  flex: 1;
  min-width: 0;
}
.crumbs ol {
  display: flex;
  align-items: center;
  list-style: none;
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  white-space: nowrap;
  overflow: hidden;
}
.crumbs li + li::before {
  content: "›";
  margin: 0 var(--space-2);
  color: var(--bronze);
}
.crumbs a {
  color: var(--ink-muted);
}
.crumbs a:hover {
  color: var(--ink);
}
.crumbs [aria-current] {
  color: var(--ink);
}
.search-trigger {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: min(380px, 40vw);
  min-height: 36px;
  padding: 0 var(--space-3);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  color: var(--ink-muted);
  font-size: 14px;
  text-align: left;
}
.search-trigger:hover {
  border-color: var(--bronze);
}
.search-trigger span {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.search-trigger kbd {
  font-family: var(--font-label);
  font-size: 11px;
  padding: 1px 6px;
  border: 1px solid var(--line);
  color: var(--bronze-light);
}
.topbar-brand {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-right: auto;
  color: var(--ink);
  font-family: var(--font-display);
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.topbar-brand :deep(.logo) {
  width: 26px;
  height: 26px;
}
.topbar-icon {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  color: var(--ink);
}
</style>
