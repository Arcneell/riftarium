<script setup>
import { ref } from "vue"
import { api, session } from "../api.js"

/* Bandeau discret affiché sous l'en-tête quand la session est active mais l'adresse e-mail non vérifiée. */
const sending = ref(false)
const info = ref("")
const error = ref("")

async function resend() {
  if (sending.value) return // ignore les doubles clics pendant la requête
  sending.value = true
  info.value = ""
  error.value = ""
  try {
    await api("/api/auth/resend-verification", { method: "POST" })
    info.value = "E-mail de vérification renvoyé. Pensez à vérifier vos indésirables."
  } catch (e) {
    if (e.status === 429) error.value = "Trop de demandes. Réessayez dans quelques minutes."
    else if (e.status === 400) {
      /* Adresse déjà vérifiée : on met la session à jour, le bandeau disparaît. */
      session.emailVerified = true
    } else error.value = e.message
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <div v-if="session.token && session.emailVerified === false" class="verify-notice" role="status">
    <p>
      <strong>Adresse e-mail non vérifiée.</strong>
      <template v-if="info">{{ info }}</template>
      <span v-if="error" class="error">{{ error }}</span>
    </p>
    <button class="btn btn-ghost btn-sm" type="button" :disabled="sending" @click="resend">
      {{ sending ? "Envoi…" : "Renvoyer l'e-mail" }}
    </button>
  </div>
</template>
