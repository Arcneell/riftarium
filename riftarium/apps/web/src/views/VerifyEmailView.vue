<script setup>
import { onMounted, ref } from "vue"
import { useRoute } from "vue-router"
import { api, session } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"

const route = useRoute()

/* loading → vérification en cours ; ok → adresse confirmée ; fail → jeton absent, invalide ou expiré. */
const state = ref("loading")
const error = ref("")

const resending = ref(false)
const resendOk = ref("")
const resendError = ref("")

onMounted(async () => {
  const token = typeof route.query.token === "string" ? route.query.token : ""
  if (!token) {
    state.value = "fail"
    error.value = "Ce lien de vérification est incomplet : le jeton est manquant. Ouvrez le lien reçu par e-mail."
    return
  }
  try {
    await api("/api/auth/verify-email", { method: "POST", body: { token } })
    state.value = "ok"
    if (session.token) session.emailVerified = true
  } catch (e) {
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
  <PageBanner :art="BANNERS.auth" eyebrow="Compte" title="Vérification de l'adresse e-mail">
    Confirmation de l'adresse e-mail associée à votre compte Riftarium.
  </PageBanner>

  <section style="padding-top: 36px">
    <div class="wrap" style="max-width: 480px">
      <p v-if="state === 'loading'" class="muted">Vérification en cours…</p>

      <div v-else-if="state === 'ok'" class="panel">
        <p class="success" style="margin-top: 0; margin-bottom: 20px">
          Adresse vérifiée ! Votre compte est maintenant confirmé.
        </p>
        <RouterLink class="btn btn-gold" to="/" style="margin-right: 10px">Retour à l'accueil</RouterLink>
        <RouterLink v-if="!session.token" class="btn" to="/connexion">Se connecter</RouterLink>
      </div>

      <div v-else class="panel">
        <p class="error" style="margin-top: 0">{{ error }}</p>
        <template v-if="session.token">
          <p class="muted" style="margin-bottom: 16px">Vous pouvez demander un nouvel e-mail de vérification.</p>
          <button class="btn btn-gold" type="button" :disabled="resending" @click="resend">
            {{ resending ? "Envoi…" : "Renvoyer l'e-mail" }}
          </button>
          <p v-if="resendOk" class="success">{{ resendOk }}</p>
          <p v-if="resendError" class="error">{{ resendError }}</p>
        </template>
        <p v-else class="muted" style="margin-top: 12px">
          <RouterLink to="/connexion">Connectez-vous</RouterLink>
          pour demander un nouvel e-mail de vérification.
        </p>
      </div>
    </div>
  </section>
</template>
