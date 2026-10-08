<script setup>
import { computed, ref } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session, setSession } from "../api.js"
import { CLOSED_BETA } from "../legal.js"
import AccessLayout from "../account/AccessLayout.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftField from "../ui/RiftField.vue"
import RiftSegments from "../ui/RiftSegments.vue"

const route = useRoute()
const router = useRouter()

const MODES = [
  { value: "login", label: "Connexion" },
  { value: "register", label: "Créer un compte" }
]

const mode = ref("login")
const handle = ref("")
const email = ref("")
const password = ref("")
const acceptTerms = ref(false)
const confirmAge = ref(false)
const error = ref("")
const submitting = ref(false)
const registered = ref(false)

const title = computed(() =>
  registered.value ? "Compte créé" : mode.value === "login" ? "Connexion" : "Créer un compte"
)

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
  <AccessLayout :title="title">
    <template v-if="registered">
      <p class="acces-succes" role="status">Compte créé pour {{ handle }}.</p>
      <p class="acces-note">
        Un e-mail de vérification a été envoyé à <strong>{{ email }}</strong
        >. Cliquez sur le lien qu'il contient pour confirmer votre adresse.
      </p>
      <div class="acces-actions">
        <RiftButton @click="proceed">Continuer</RiftButton>
      </div>
    </template>

    <template v-else>
      <p v-if="CLOSED_BETA" class="acces-note">
        Accès sur invitation. Pas d'annonce publique, pas d'indexation. Les retours de bugs vont sur
        <a class="acces-lien" href="https://github.com/Arcneell/riftarium/issues" target="_blank" rel="noopener"
          >GitHub</a
        >.
      </p>
      <RiftSegments
        :model-value="mode"
        :items="MODES"
        label="Connexion ou inscription"
        id-base="acces"
        @update:model-value="switchMode"
      />

      <form
        :id="`acces-panel-${mode}`"
        class="acces-form"
        role="tabpanel"
        :aria-labelledby="`acces-tab-${mode}`"
        @submit.prevent="submit"
      >
        <RiftField
          v-if="mode === 'register'"
          v-model="handle"
          label="Pseudo"
          name="handle"
          autocomplete="username"
          autocapitalize="none"
          autocorrect="off"
          spellcheck="false"
          required
          minlength="3"
          maxlength="32"
          placeholder="3 à 32 caractères"
        />
        <RiftField v-model="email" label="Email" type="email" name="email" autocomplete="email" required />
        <RiftField
          v-model="password"
          label="Mot de passe"
          type="password"
          name="password"
          required
          minlength="8"
          :autocomplete="mode === 'login' ? 'current-password' : 'new-password'"
          placeholder="8 caractères minimum"
        />
        <template v-if="mode === 'register'">
          <label class="acces-check">
            <input type="checkbox" v-model="confirmAge" />
            <span>J'ai au moins 15 ans.</span>
          </label>
          <label class="acces-check">
            <input type="checkbox" v-model="acceptTerms" />
            <span>
              J'accepte les
              <RouterLink class="acces-lien" to="/cgu">conditions d'utilisation</RouterLink>
              et la
              <RouterLink class="acces-lien" to="/confidentialite">politique de confidentialité</RouterLink>.
            </span>
          </label>
        </template>
        <RiftButton type="submit" block :disabled="submitting">
          {{ submitting ? "Un instant…" : mode === "login" ? "Se connecter" : "Créer mon compte" }}
        </RiftButton>
        <p v-if="error" class="acces-erreur" role="alert">{{ error }}</p>
        <p v-if="mode === 'login'" class="acces-note">
          <RouterLink class="acces-lien" to="/mot-de-passe-oublie">Mot de passe oublié ?</RouterLink>
        </p>
      </form>
    </template>
  </AccessLayout>
</template>
