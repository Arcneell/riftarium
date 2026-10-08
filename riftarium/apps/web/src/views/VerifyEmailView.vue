<script setup>
import { onBeforeUnmount, onMounted, ref } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session } from "../api.js"
import AccessLayout from "../account/AccessLayout.vue"
import RiftButton from "../ui/RiftButton.vue"

const route = useRoute()
const router = useRouter()

/* Composant démonté pendant l'appel : on n'écrit plus dans state/error après coup. */
let alive = true
onBeforeUnmount(() => {
  alive = false
})

/* loading → vérification en cours ; ok → adresse confirmée ; fail → jeton absent, invalide ou expiré. */
const state = ref("loading")
const error = ref("")

const resending = ref(false)
const resendOk = ref("")
const resendError = ref("")

/* Jeton lu une fois : il ne doit pas rester dans la barre d'adresse ni l'historique. */
const token = ref(typeof route.query.token === "string" ? route.query.token : "")

onMounted(async () => {
  if (token.value) router.replace({ query: {} })
  if (!token.value) {
    state.value = "fail"
    error.value = "Ce lien de vérification est incomplet : le jeton est manquant. Ouvrez le lien reçu par e-mail."
    return
  }
  try {
    await api("/api/auth/verify-email", { method: "POST", body: { token: token.value } })
    if (!alive) return
    state.value = "ok"
    if (session.token) session.emailVerified = true
  } catch (e) {
    if (!alive) return
    state.value = "fail"
    error.value = e.status === 400 ? "Ce lien de vérification est invalide ou a expiré." : e.message
  }
})

/* Renvoi possible uniquement pour un utilisateur connecté (l'API l'exige). */
async function resend() {
  if (resending.value) return // ignore les doubles clics pendant la requête
  resending.value = true
  resendOk.value = ""
  resendError.value = ""
  try {
    await api("/api/auth/resend-verification", { method: "POST" })
    resendOk.value = "Un nouvel e-mail de vérification vient d'être envoyé."
  } catch (e) {
    if (e.status === 429) resendError.value = "Trop de demandes. Réessayez dans quelques minutes."
    else if (e.status === 400) {
      /* Adresse déjà vérifiée entre-temps : tout va bien. */
      state.value = "ok"
      session.emailVerified = true
    } else resendError.value = e.message
  } finally {
    resending.value = false
  }
}
</script>

<template>
  <AccessLayout title="Vérification de l'adresse e-mail">
    <p v-if="state === 'loading'" class="acces-note" role="status">Vérification en cours…</p>

    <template v-else-if="state === 'ok'">
      <p class="acces-succes" role="status">Adresse vérifiée ! Votre compte est maintenant confirmé.</p>
      <div class="acces-actions">
        <RiftButton to="/">Retour à l'accueil</RiftButton>
        <RiftButton v-if="!session.token" to="/connexion" variant="secondary">Se connecter</RiftButton>
      </div>
    </template>

    <template v-else>
      <p class="acces-erreur" role="alert">{{ error }}</p>
      <template v-if="session.token">
        <p class="acces-note">Vous pouvez demander un nouvel e-mail de vérification.</p>
        <div class="acces-actions">
          <RiftButton :disabled="resending" @click="resend">{{
            resending ? "Envoi…" : "Renvoyer l'e-mail"
          }}</RiftButton>
        </div>
        <p v-if="resendOk" class="acces-succes" role="status">{{ resendOk }}</p>
        <p v-if="resendError" class="acces-erreur" role="alert">{{ resendError }}</p>
      </template>
      <p v-else class="acces-note">
        <RouterLink class="acces-lien" to="/connexion">Connectez-vous</RouterLink>
        pour demander un nouvel e-mail de vérification.
      </p>
    </template>
  </AccessLayout>
</template>
