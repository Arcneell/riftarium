<script setup>
import { onMounted, ref } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api } from "../api.js"
import AccessLayout from "../account/AccessLayout.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftField from "../ui/RiftField.vue"

const route = useRoute()
const router = useRouter()

/* Jeton transmis dans le lien reçu par e-mail (?token=…) : lu une fois puis gardé
   en mémoire seulement. */
const token = ref(typeof route.query.token === "string" ? route.query.token : "")

/* On efface aussitôt le jeton de l'adresse et de l'historique : il ne doit pas rester
   dans la barre d'adresse, un partage de lien ou un journal de navigation. */
onMounted(() => {
  if (token.value) router.replace({ query: {} })
})

const password = ref("")
const confirm = ref("")
const done = ref(false)
const error = ref("")
const tokenRejected = ref(false)
const submitting = ref(false)

async function submit() {
  if (submitting.value) return // ignore les doubles soumissions pendant la requête
  if (password.value !== confirm.value) {
    error.value = "Les mots de passe ne correspondent pas."
    return
  }
  error.value = ""
  tokenRejected.value = false
  submitting.value = true
  try {
    await api("/api/auth/reset-password", {
      method: "POST",
      body: { token: token.value, new_password: password.value }
    })
    password.value = ""
    confirm.value = ""
    done.value = true
  } catch (e) {
    /* 400 : jeton invalide ou expiré — on propose d'en redemander un. */
    tokenRejected.value = e.status === 400
    error.value = e.status === 400 ? "Ce lien de réinitialisation est invalide ou a expiré." : e.message
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AccessLayout title="Nouveau mot de passe">
    <template v-if="!token">
      <p class="acces-erreur" role="alert">
        Ce lien est incomplet. Ouvrez le lien reçu par e-mail, ou demandez-en un nouveau.
      </p>
      <div class="acces-actions">
        <RiftButton to="/mot-de-passe-oublie">Demander un nouveau lien</RiftButton>
      </div>
    </template>

    <template v-else-if="done">
      <p class="acces-succes" role="status">Mot de passe mis à jour, reconnectez-vous.</p>
      <div class="acces-actions">
        <RiftButton to="/connexion">Se connecter</RiftButton>
      </div>
    </template>

    <form v-else class="acces-form" @submit.prevent="submit">
      <RiftField
        v-model="password"
        label="Nouveau mot de passe"
        type="password"
        name="password"
        minlength="8"
        autocomplete="new-password"
        placeholder="8 caractères minimum"
        required
      />
      <RiftField
        v-model="confirm"
        label="Confirmation"
        type="password"
        name="confirm"
        minlength="8"
        autocomplete="new-password"
        required
      />
      <RiftButton type="submit" block :disabled="submitting">
        {{ submitting ? "Un instant…" : "Changer le mot de passe" }}
      </RiftButton>
      <p v-if="error" class="acces-erreur" role="alert">{{ error }}</p>
      <p v-if="tokenRejected" class="acces-note">
        <RouterLink class="acces-lien" to="/mot-de-passe-oublie">Demander un nouveau lien</RouterLink>
      </p>
    </form>
  </AccessLayout>
</template>
