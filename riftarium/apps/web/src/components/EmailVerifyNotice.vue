<script setup>
import { onBeforeUnmount, ref } from "vue"
import { api, session } from "../api.js"

/* Bandeau discret affiché sous l'en-tête quand la session est active mais l'adresse e-mail non vérifiée. */

/* Délai laissé au lecteur pour voir « déjà vérifiée » avant que le bandeau s'efface. */
const ALREADY_VERIFIED_DELAY_MS = 2500

const sending = ref(false)
const info = ref("")
const error = ref("")
let hideTimer = null
onBeforeUnmount(() => clearTimeout(hideTimer))

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
      /* Adresse déjà vérifiée : le bandeau doit disparaître, mais pas en silence —
         sans un mot, le clic passe pour n'avoir rien fait. */
      info.value = "Votre adresse était déjà vérifiée."
      clearTimeout(hideTimer)
      hideTimer = setTimeout(() => {
        /* Une déconnexion entre-temps a déjà remis la session à zéro : ne rien écrire. */
        if (session.token) session.emailVerified = true
      }, ALREADY_VERIFIED_DELAY_MS)
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
