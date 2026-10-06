<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute } from "vue-router"
import { session } from "../api.js"
import UserAvatar from "../components/UserAvatar.vue"
import { ACCOUNT_LINKS } from "./navigation.js"
import { useLogout } from "./useLogout.js"

/* Menu du compte, en bas du rail : il s'ouvre vers le haut. */
defineProps({ compact: { type: Boolean, default: false } })

const route = useRoute()
const open = ref(false)
const root = ref(null)
const { loggingOut, logout } = useLogout()

watch(
  () => route.fullPath,
  () => {
    open.value = false
  }
)

/* pointerdown : précède la navigation du lien cliqué ailleurs dans la page. */
function onPointerDown(event) {
  if (open.value && root.value && !root.value.contains(event.target)) open.value = false
}
function onKeydown(event) {
  if (event.key === "Escape") open.value = false
}

onMounted(() => {
  window.addEventListener("pointerdown", onPointerDown)
  window.addEventListener("keydown", onKeydown)
})
onBeforeUnmount(() => {
  window.removeEventListener("pointerdown", onPointerDown)
  window.removeEventListener("keydown", onKeydown)
})
</script>

<template>
  <div ref="root" class="account">
    <button
      type="button"
      class="account-btn"
      :aria-expanded="open"
      aria-haspopup="menu"
      aria-controls="menu-compte"
      :title="`Compte de ${session.handle}`"
      @click="open = !open"
    >
      <UserAvatar :src="session.avatarUrl" :handle="session.handle" :size="28" />
      <span v-if="!compact" class="account-name">{{ session.handle }}</span>
      <Icon v-if="!compact" name="chevron" :size="14" class="account-chevron" />
    </button>
    <div v-if="open" id="menu-compte" class="account-menu" role="menu" aria-label="Mon compte">
      <RouterLink v-for="link in ACCOUNT_LINKS" :key="link.to" role="menuitem" :to="link.to">{{
        link.label
      }}</RouterLink>
      <RouterLink v-if="session.isAdmin" role="menuitem" to="/admin">Administration</RouterLink>
      <button role="menuitem" type="button" :disabled="loggingOut" @click="logout">Déconnexion</button>
    </div>
  </div>
</template>

<style scoped>
.account {
  position: relative;
}
.account-btn {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  min-height: 44px;
  padding: var(--space-1) var(--space-2);
  color: var(--ink);
  text-align: left;
}
.account-btn:hover {
  background: rgba(255, 255, 255, 0.04);
}
.account-name {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}
.account-chevron {
  transform: rotate(180deg);
  color: var(--ink-muted);
}
.account-menu {
  position: absolute;
  left: 0;
  bottom: calc(100% + var(--space-2));
  z-index: var(--z-overlay);
  display: grid;
  min-width: 200px;
  padding: var(--space-1);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow:
    inset 0 0 0 1px var(--line),
    var(--shadow-deep);
}
.account-menu a,
.account-menu button {
  display: block;
  padding: var(--space-2) var(--space-3);
  text-align: left;
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.account-menu a:hover,
.account-menu button:hover,
.account-menu a:focus-visible,
.account-menu button:focus-visible {
  background: rgba(179, 38, 43, 0.25);
  color: #fff;
}
</style>
