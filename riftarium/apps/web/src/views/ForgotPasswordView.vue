<script setup>
import { ref } from "vue"
import { api } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"

/* Réponse volontairement identique que le compte existe ou non (anti-énumération d'adresses). */
const NEUTRAL_MESSAGE = "Si un compte existe avec cette adresse, un e-mail de réinitialisation a été envoyé."

const email = ref("")
const sent = ref(false)
const error = ref("")
const submitting = ref(false)

async function submit() {
  if (submitting.value) return // ignore les doubles soumissions pendant la requête
  error.value = ""
  submitting.value = true
  try {
    await api("/api/auth/forgot-password", { method: "POST", body: { email: email.value } })
    sent.value = true
  } catch (e) {
    if (e.status === 429) {
      error.value = "Trop de demandes. Réessayez dans quelques minutes."
    } else if (!e.status || e.status >= 500) {
      /* Réseau coupé ou panne serveur : la demande n'est pas partie, il faut le dire
         (annoncer « e-mail envoyé » ferait attendre en vain). */
      error.value = "La demande n'a pas pu être envoyée. Vérifiez votre connexion et réessayez."
    } else {
      /* Réponse 4xx de l'API : même message neutre, ne jamais révéler si l'adresse est connue. */
      sent.value = true
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <PageBanner :art="BANNERS.auth" title="Mot de passe oublié" show-title />

  <section>
    <div class="wrap" style="max-width: 480px">
      <div v-if="sent" class="panel">
        <p class="success" style="margin-top: 0">{{ NEUTRAL_MESSAGE }}</p>
        <p class="muted" style="margin-bottom: 20px">Pensez à vérifier vos indésirables.</p>
        <RouterLink class="btn btn-gold" to="/connexion">Retour à la connexion</RouterLink>
      </div>

      <form v-else class="panel" @submit.prevent="submit">
        <div class="field">
          <label for="forgot-email">Email</label>
          <input id="forgot-email" type="email" v-model="email" autocomplete="email" required />
        </div>
        <button class="btn btn-gold" type="submit" style="width: 100%" :disabled="submitting">
          {{ submitting ? "Un instant…" : "Envoyer le lien" }}
        </button>
        <p v-if="error" class="error">{{ error }}</p>
        <p class="muted" style="margin-top: 16px">
          <RouterLink to="/connexion">Retour à la connexion</RouterLink>
        </p>
      </form>
    </div>
  </section>
</template>
