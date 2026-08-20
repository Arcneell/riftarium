<script setup>
import { defineAsyncComponent, watchEffect } from "vue"
import { session } from "../api.js"
import NotFoundView from "./NotFoundView.vue"

/* La console n'est téléchargée (import dynamique) qu'une fois le statut admin confirmé
   par /api/auth/me : pour tout autre visiteur, connecté ou non, cette adresse est
   indiscernable d'une page inexistante — on rend la 404 du site, sans redirection. */
const AdminConsole = defineAsyncComponent(() => import("./AdminView.vue"))

/* Le titre de la route est celui de la 404 (zéro indice) : on ne le corrige que pour l'admin. */
watchEffect(() => {
  if (session.isAdmin && typeof document !== "undefined") {
    document.title = "Administration · Riftarium"
  }
})
</script>

<template>
  <AdminConsole v-if="session.isAdmin" />
  <NotFoundView v-else />
</template>
