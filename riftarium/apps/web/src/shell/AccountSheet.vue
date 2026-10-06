<script setup>
import { session } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import { ACCOUNT_LINKS, NAV } from "./navigation.js"
import { useLogout } from "./useLogout.js"

/* Feuille de l'avatar (téléphone) : Jouer n'a pas d'onglet en bas, il vit ici,
   avec les entrées du compte. */
const emit = defineEmits(["close"])
const play = NAV.find((section) => section.key === "play")
const accountLinks = [...ACCOUNT_LINKS, { label: "Wishlist", to: "/wishlist" }]
const { loggingOut, logout } = useLogout()

async function onLogout() {
  await logout()
  emit("close")
}
</script>

<template>
  <RiftSheet :title="session.token ? session.handle : 'Compte'" @close="emit('close')">
    <p class="sheet-label">Jouer</p>
    <ul class="sheet-links">
      <li v-for="link in play.children" :key="link.to">
        <RouterLink :to="link.to" @click="emit('close')">{{ link.label }}</RouterLink>
      </li>
    </ul>
    <template v-if="session.token">
      <p class="sheet-label">Mon compte</p>
      <ul class="sheet-links">
        <li v-for="link in accountLinks" :key="link.to">
          <RouterLink :to="link.to" @click="emit('close')">{{ link.label }}</RouterLink>
        </li>
        <li v-if="session.isAdmin">
          <RouterLink to="/admin" @click="emit('close')">Administration</RouterLink>
        </li>
      </ul>
      <RiftButton variant="secondary" block :disabled="loggingOut" @click="onLogout">Déconnexion</RiftButton>
    </template>
    <RiftButton v-else to="/connexion" block @click="emit('close')">Connexion</RiftButton>
  </RiftSheet>
</template>

<style scoped>
.sheet-label {
  margin: var(--space-2) 0 var(--space-1);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.sheet-links {
  list-style: none;
  margin-bottom: var(--space-4);
}
.sheet-links a {
  display: flex;
  align-items: center;
  min-height: 44px;
  color: var(--ink);
  border-bottom: 1px solid var(--line);
}
</style>
