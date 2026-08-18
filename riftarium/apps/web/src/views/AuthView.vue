<script setup>
import { ref } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, setSession } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"

const route = useRoute()
const router = useRouter()

const mode = ref("login")
const handle = ref("")
const email = ref("")
const password = ref("")
const error = ref("")

async function submit() {
  error.value = ""
  try {
    const result =
      mode.value === "login"
        ? await api("/api/auth/login", { method: "POST", body: { email: email.value, password: password.value } })
        : await api("/api/auth/register", {
            method: "POST",
            body: { handle: handle.value, email: email.value, password: password.value }
          })
    setSession(result.token, result.handle, result.avatar_url)
    router.push(route.query.suite || "/")
  } catch (e) {
    error.value = e.message
  }
}
</script>

<template>
  <PageBanner
    :art="BANNERS.auth"
    eyebrow="Compte"
    :title="mode === 'login' ? 'Bon retour' : 'Bienvenue dans la Faille'"
  >
    {{
      mode === "login"
        ? "Connectez-vous pour retrouver vos decks et votre collection."
        : "Créez un compte pour construire des decks et suivre vos cartes."
    }}
  </PageBanner>

  <section style="padding-top: 36px">
    <div class="wrap" style="max-width: 480px">
      <div class="filters" style="margin: 0 0 26px">
        <button class="filter" :aria-pressed="mode === 'login'" @click="mode = 'login'">Connexion</button>
        <button class="filter" :aria-pressed="mode === 'register'" @click="mode = 'register'">Inscription</button>
      </div>

      <form class="panel" @submit.prevent="submit">
        <div class="field" v-if="mode === 'register'">
          <label for="handle">Pseudo</label>
          <input
            id="handle"
            type="text"
            v-model="handle"
            autocomplete="username"
            required
            minlength="3"
            maxlength="32"
            placeholder="3 à 32 caractères"
          />
        </div>
        <div class="field">
          <label for="email">Email</label>
          <input id="email" type="email" v-model="email" autocomplete="email" required />
        </div>
        <div class="field">
          <label for="password">Mot de passe</label>
          <input
            id="password"
            type="password"
            v-model="password"
            required
            minlength="8"
            :autocomplete="mode === 'login' ? 'current-password' : 'new-password'"
            placeholder="8 caractères minimum"
          />
        </div>
        <button class="btn btn-gold" type="submit" style="width: 100%">
          {{ mode === "login" ? "Se connecter" : "Créer mon compte" }}
        </button>
        <p v-if="error" class="error">{{ error }}</p>
      </form>
    </div>
  </section>
</template>
