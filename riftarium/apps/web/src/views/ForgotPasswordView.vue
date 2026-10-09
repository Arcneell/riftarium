<script setup>
import { ref } from "vue"
import { api } from "../api.js"
import AccessLayout from "../account/AccessLayout.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftField from "../ui/RiftField.vue"

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
  <AccessLayout title="Mot de passe oublié">
    <template v-if="sent">
      <p class="acces-succes" role="status">{{ NEUTRAL_MESSAGE }}</p>
      <p class="acces-note">Pensez à vérifier vos indésirables.</p>
      <div class="acces-actions">
        <RiftButton to="/connexion">Retour à la connexion</RiftButton>
      </div>
    </template>

    <form v-else class="acces-form" @submit.prevent="submit">
      <RiftField v-model="email" label="E-mail" type="email" name="email" autocomplete="email" required />
      <RiftButton type="submit" block :disabled="submitting">
        {{ submitting ? "Un instant…" : "Envoyer le lien" }}
      </RiftButton>
      <p v-if="error" class="acces-erreur" role="alert">{{ error }}</p>
      <p class="acces-note">
        <RouterLink class="acces-lien" to="/connexion">Retour à la connexion</RouterLink>
      </p>
    </form>
  </AccessLayout>
</template>
