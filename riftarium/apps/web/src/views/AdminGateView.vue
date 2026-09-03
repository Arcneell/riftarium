<script setup>
import { computed, defineAsyncComponent, watchEffect } from "vue"
import { session } from "../api.js"
import NotFoundView from "./NotFoundView.vue"

/* La console n'est téléchargée (import dynamique) qu'une fois le statut admin confirmé
   par /api/auth/me : pour tout autre visiteur, connecté ou non, cette adresse est
   indiscernable d'une page inexistante — on rend la 404 du site, sans redirection. */
const AdminConsole = defineAsyncComponent(() => import("./AdminView.vue"))

/* Une session existe mais /api/auth/me n'a pas encore répondu : ni console, ni 404. */
const pending = computed(() => Boolean(session.token) && session.isAdmin === null)

/* Le titre de la route est celui de la 404 (zéro indice) : on ne le corrige que pour l'admin. */
watchEffect(() => {
  if (session.isAdmin && typeof document !== "undefined") {
    document.title = "Administration · Riftarium"
  }
})
</script>

<template>
  <!-- `pending` = statut encore inconnu (/api/auth/me en vol pour un visiteur porteur
       d'une session) : on ne rend rien, plutôt qu'un clignotement de 404. -->
  <AdminConsole v-if="session.isAdmin" />
  <NotFoundView v-else-if="!pending" />
</template>
