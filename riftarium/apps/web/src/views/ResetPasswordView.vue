<script setup>
import { computed, ref } from "vue"
import { useRoute } from "vue-router"
import { api } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"

const route = useRoute()

/* Jeton transmis dans le lien reçu par e-mail (?token=…). */
const token = computed(() => (typeof route.query.token === "string" ? route.query.token : ""))

const password = ref("")
const confirm = ref("")
const done = ref(false)
const error = ref("")
const tokenRejected = ref(false)
const submitting = ref(false)

async function submit() {
  if (submitting.value) return // ignore les doubles soumissions pendant la requête
  if (password.value !== confirm.value) {
    error.value = "Les mots de passe ne correspondent pas"
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
  <PageBanner :art="BANNERS.auth" eyebrow="Compte" title="Nouveau mot de passe">
    Choisissez un nouveau mot de passe pour votre compte Riftarium.
  </PageBanner>

  <section style="padding-top: 36px">
    <div class="wrap" style="max-width: 480px">
      <div v-if="!token" class="panel">
        <p class="error" style="margin-top: 0">
          Ce lien de réinitialisation est incomplet : le jeton est manquant. Ouvrez le lien reçu par e-mail, ou
          demandez-en un nouveau.
        </p>
        <RouterLink class="btn btn-gold" to="/mot-de-passe-oublie">Demander un nouveau lien</RouterLink>
      </div>

      <div v-else-if="done" class="panel">
        <p class="success" style="margin-top: 0; margin-bottom: 20px">Mot de passe mis à jour, reconnectez-vous.</p>
        <RouterLink class="btn btn-gold" to="/connexion">Se connecter</RouterLink>
      </div>

      <form v-else class="panel" @submit.prevent="submit">
        <div class="field">
          <label for="reset-password">Nouveau mot de passe</label>
          <input
            id="reset-password"
            type="password"
            v-model="password"
            minlength="8"
            autocomplete="new-password"
            required
            placeholder="8 caractères minimum"
          />
        </div>
        <div class="field">
          <label for="reset-confirm">Confirmation</label>
          <input
            id="reset-confirm"
            type="password"
            v-model="confirm"
            minlength="8"
            autocomplete="new-password"
            required
          />
        </div>
        <button class="btn btn-gold" type="submit" style="width: 100%" :disabled="submitting">
          {{ submitting ? "Un instant…" : "Changer le mot de passe" }}
        </button>
        <p v-if="error" class="error">{{ error }}</p>
        <p v-if="tokenRejected" class="muted" style="margin-top: 12px">
          <RouterLink to="/mot-de-passe-oublie">Demander un nouveau lien</RouterLink>
        </p>
      </form>
    </div>
  </section>
</template>
