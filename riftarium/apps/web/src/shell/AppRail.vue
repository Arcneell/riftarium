<script setup>
import { computed } from "vue"
import { useRoute } from "vue-router"
import { session } from "../api.js"
import Logo from "../components/Logo.vue"
import { CLOSED_BETA } from "../legal.js"
import RiftButton from "../ui/RiftButton.vue"
import AccountMenu from "./AccountMenu.vue"
import { activeChild, activeSection, NAV } from "./navigation.js"

/* Rail latéral de la Forge (bureau et tablette). Seules les sous-pages de la
   rubrique active sont dépliées, pour que le rail reste court. */
defineProps({ collapsed: { type: Boolean, default: false } })
const emit = defineEmits(["toggle"])

const route = useRoute()
const section = computed(() => activeSection(route.path))
const child = computed(() => activeChild(section.value, route.path))

/* Rubrique à sous-pages : « true » (on est dans la rubrique), la page exacte est la
   sous-page. Rubrique sans sous-pages : c'est la page elle-même. */
function sectionCurrent(item) {
  if (item !== section.value) return undefined
  return item.children ? "true" : "page"
}
</script>

<template>
  <aside class="rail" :class="{ collapsed }">
    <RouterLink to="/" class="rail-brand" aria-label="Riftarium, accueil">
      <Logo />
      <span v-if="!collapsed" class="rail-name">Riftarium</span>
    </RouterLink>
    <span v-if="!collapsed" class="rail-beta">{{ CLOSED_BETA ? "bêta fermée" : "bêta" }}</span>

    <nav class="rail-nav" aria-label="Navigation principale">
      <ul>
        <li v-for="item in NAV" :key="item.key">
          <RouterLink
            :to="item.to"
            class="rail-item"
            :class="{ active: item === section }"
            :aria-current="sectionCurrent(item)"
            :title="collapsed ? item.label : undefined"
          >
            <Icon :name="item.icon" :size="18" />
            <span v-if="!collapsed" class="rail-label">{{ item.label }}</span>
          </RouterLink>
          <ul v-if="!collapsed && item === section && item.children" class="rail-sub">
            <li v-for="sub in item.children" :key="sub.to">
              <RouterLink
                :to="sub.to"
                :class="{ active: sub === child }"
                :aria-current="sub === child ? 'page' : undefined"
                >{{ sub.label }}</RouterLink
              >
            </li>
          </ul>
        </li>
      </ul>
    </nav>

    <div class="rail-foot">
      <AccountMenu v-if="session.token" :compact="collapsed" />
      <RiftButton v-else-if="!collapsed" to="/connexion" size="sm" block>Connexion</RiftButton>
      <RouterLink v-else to="/connexion" class="rail-item" title="Connexion" aria-label="Connexion"
        ><Icon name="user" :size="18"
      /></RouterLink>
      <button
        type="button"
        class="rail-collapse"
        :aria-label="collapsed ? 'Déplier le menu' : 'Replier le menu'"
        :aria-expanded="!collapsed"
        @click="emit('toggle')"
      >
        <Icon name="collapse" :size="18" />
      </button>
    </div>
  </aside>
</template>

<style scoped>
.rail {
  position: fixed;
  inset: 0 auto 0 0;
  z-index: var(--z-rail);
  width: var(--rail-w);
  display: flex;
  flex-direction: column;
  padding: var(--space-4) 0 var(--space-3);
  background: var(--bg-sunken);
  border-right: 2px solid var(--blood);
}
.rail.collapsed {
  width: var(--rail-w-collapsed);
}
.rail-brand {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: 0 var(--space-4);
  color: var(--ink);
}
.rail.collapsed .rail-brand {
  justify-content: center;
  padding: 0;
}
.rail-brand :deep(.logo) {
  width: 30px;
  height: 30px;
  flex: none;
}
.rail-name {
  font-family: var(--font-display);
  font-size: 17px;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.rail-beta {
  margin: var(--space-1) var(--space-4) 0 calc(var(--space-4) + 38px);
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.rail-nav {
  flex: 1;
  margin-top: var(--space-5);
  overflow-y: auto;
}
.rail-nav ul {
  list-style: none;
}
.rail-item {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-height: 44px;
  padding: 0 var(--space-4);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.rail.collapsed .rail-item {
  justify-content: center;
  padding: 0;
}
.rail-item:hover {
  color: var(--ink);
}
.rail-item.active {
  color: #fff;
  background: linear-gradient(90deg, rgba(179, 38, 43, 0.35), transparent);
  box-shadow: inset 3px 0 0 var(--blood-bright);
}
.rail-sub a {
  display: block;
  padding: var(--space-2) var(--space-4) var(--space-2) calc(var(--space-4) + 30px);
  font-size: 14px;
  color: var(--ink-muted);
}
.rail-sub a:hover {
  color: var(--ink);
}
.rail-sub a.active {
  color: var(--bronze-light);
}
.rail-foot {
  display: grid;
  gap: var(--space-2);
  padding: var(--space-3) var(--space-3) 0;
  border-top: 1px solid var(--line);
}
.rail-collapse {
  display: grid;
  place-items: center;
  height: 36px;
  color: var(--ink-muted);
}
.rail-collapse:hover {
  color: var(--ink);
}
.rail.collapsed .rail-collapse {
  transform: rotate(180deg);
}
</style>
