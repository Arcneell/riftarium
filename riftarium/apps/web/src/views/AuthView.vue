<script setup>
import { ref } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session, setSession } from "../api.js"
import { BANNERS } from "../banners.js"
import { CLOSED_BETA } from "../legal.js"
import PageBanner from "../components/PageBanner.vue"

const route = useRoute()
const router = useRouter()

const mode = ref("login")
const handle = ref("")
const email = ref("")
const password = ref("")
const acceptTerms = ref(false)
const confirmAge = ref(false)
const error = ref("")
const submitting = ref(false)
const registered = ref(false)

function proceed() {
  /* Seul un chemin interne est accepté (`/…` mais pas `//…`) : une valeur forgée
     dans ?suite= ne doit jamais servir de redirection ouverte. */
  const next = String(route.query.suite ?? "")
  router.push(/^\/(?!\/)/.test(next) ? next : "/")
}

/* Changer de mode repart d'une ardoise propre : ni erreur de l'autre formulaire,
   ni mot de passe saisi (le champ change d'autocomplete). */
function switchMode(next) {
  if (mode.value === next) return
  mode.value = next
  error.value = ""
  password.value = ""
}

async function submit() {
  if (submitting.value) return // ignore les doubles soumissions pendant la requête
  error.value = ""
  if (mode.value === "register") {
    if (!confirmAge.value) {
      error.value = "L'inscription est réservée aux personnes d'au moins 15 ans."
      return
    }
    if (!acceptTerms.value) {
      error.value = "Veuillez accepter les conditions d'utilisation et la politique de confidentialité."
      return
    }
  }
  submitting.value = true
  try {
    const result =
      mode.value === "login"
        ? await api("/api/auth/login", { method: "POST", body: { email: email.value, password: password.value } })
        : await api("/api/auth/register", {
            method: "POST",
            body: {
              handle: handle.value,
              email: email.value,
              password: password.value,
              accept_terms: true,
              confirm_age: true
            }
          })
    setSession("1", result.handle, result.avatar_url)
    /* null = inconnu si la réponse de connexion n'inclut pas le drapeau : /me tranchera. */
    session.isAdmin = result.is_admin ?? null
    if (mode.value === "register") {
      /* Compte tout juste créé : l'adresse n'est pas encore vérifiée, on le signale avant de continuer. */
      session.emailVerified = result.email_verified ?? false
      registered.value = true
    } else {
      proceed()
    }
  } catch (e) {
    error.value = e.message
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <PageBanner :art="BANNERS.auth" :title="mode === 'login' ? 'Connexion' : 'Créer un compte'" show-title />

  <section>
    <div class="wrap" style="max-width: 480px">
      <div v-if="registered" class="panel">
        <p class="success" style="margin-top: 0">Compte créé pour {{ handle }}.</p>
        <p class="muted" style="margin-bottom: 20px">
          Un e-mail de vérification a été envoyé à <strong>{{ email }}</strong
          >. Cliquez sur le lien qu'il contient pour confirmer votre adresse.
        </p>
        <button class="btn btn-gold" type="button" @click="proceed">Continuer</button>
      </div>

      <template v-else>
        <p v-if="CLOSED_BETA" class="muted" style="margin: 0 0 22px">
          Accès sur invitation. Pas d'annonce publique, pas d'indexation. Les retours de bugs vont sur
          <a href="https://github.com/Arcneell/riftarium/issues" target="_blank" rel="noopener">GitHub</a>.
        </p>
        <div class="filters" style="margin: 0 0 26px">
          <button class="filter" :aria-pressed="mode === 'login'" @click="switchMode('login')">Connexion</button>
          <button class="filter" :aria-pressed="mode === 'register'" @click="switchMode('register')">
            Inscription
          </button>
        </div>

        <form class="panel" @submit.prevent="submit">
          <div class="field" v-if="mode === 'register'">
            <label for="handle">Pseudo</label>
            <input
              id="handle"
              type="text"
              v-model="handle"
              autocomplete="username"
              autocapitalize="none"
              autocorrect="off"
              spellcheck="false"
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
          <template v-if="mode === 'register'">
            <label class="legal-check">
              <input type="checkbox" v-model="confirmAge" />
              <span>J'ai au moins 15 ans.</span>
            </label>
            <label class="legal-check">
              <input type="checkbox" v-model="acceptTerms" />
              <span>
                J'accepte les
                <RouterLink to="/cgu">conditions d'utilisation</RouterLink>
                et la
                <RouterLink to="/confidentialite">politique de confidentialité</RouterLink>.
              </span>
            </label>
          </template>
          <button class="btn btn-gold" type="submit" style="width: 100%" :disabled="submitting">
            {{ submitting ? "Un instant…" : mode === "login" ? "Se connecter" : "Créer mon compte" }}
          </button>
          <p v-if="error" class="error">{{ error }}</p>
          <p v-if="mode === 'login'" class="muted" style="margin-top: 16px">
            <RouterLink to="/mot-de-passe-oublie">Mot de passe oublié ?</RouterLink>
          </p>
        </form>
      </template>
    </div>
  </section>
</template>
